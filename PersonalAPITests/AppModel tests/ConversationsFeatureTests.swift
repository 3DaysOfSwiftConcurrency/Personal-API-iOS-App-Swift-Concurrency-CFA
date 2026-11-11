import XCTest

@testable import PersonalAPI

@MainActor final class ConversationQueryStub: QuerySearching {
  var contexts: [[String]] = []
  var answer = "Your recorded answer."
  var deferred = false
  var pending: CheckedContinuation<QueryResult, Error>?
  func canSearch(_ question: String) -> Bool {
    !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  func search(_ question: String) async throws -> QueryResult {
    try await search(question, previousQuestions: [])
  }
  func search(_ question: String, previousQuestions: [String]) async throws -> QueryResult {
    contexts.append(previousQuestions)
    if deferred { return try await withCheckedThrowingContinuation { pending = $0 } }
    return QueryResult(
      evidence: [], searchedCount: 0, generatedAnswer: GroundedAnswer(text: answer, citations: []),
      method: .onDeviceAI)
  }
}
@MainActor final class ConversationsFeatureTests: XCTestCase {
  func testFollowUpUsesQuestionsNeverGeneratedAnswersAndNewChatIsIsolated() async throws {
    let query = ConversationQueryStub()
    let manager = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: query), now: { Date() })
    let id = UUID()
    try await manager.send("Who was Alex?", in: id)
    try await manager.send("Where did I meet him?", in: id)
    XCTAssertEqual(query.contexts, [[], ["Who was Alex?"]])
    XCTAssertEqual(manager.conversations.first?.turns.count, 2)
    try await manager.send("Where?", in: UUID())
    XCTAssertEqual(query.contexts.last, [])
  }
  func testRetryReplacesLatestAnswerAndRetrievesAgainWithoutDuplicatingQuestion() async throws {
    let query = ConversationQueryStub()
    let manager = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: query), now: { Date() })
    let id = UUID()
    try await manager.send("Did I enjoy school?", in: id)
    query.answer = "You remember enjoying it."
    try await manager.answerAgain(in: id)
    XCTAssertEqual(query.contexts.count, 2)
    XCTAssertEqual(manager.conversations.first?.turns.count, 1)
    XCTAssertEqual(
      manager.conversations.first?.turns.first?.result?.generatedAnswer?.text, query.answer)
  }
  func testCancellationKeepsSavedQuestionAndDiscardsLateAnswer() async throws {
    let query = ConversationQueryStub()
    query.deferred = true
    let store = MemoryConversationRepository()
    let manager = ConversationsFeature(repository: store, queryFeature: QueryFeature(searcher: query), now: { Date() })
    let operation = Task { try await manager.send("Who?", in: UUID()) }
    while query.pending == nil { await Task.yield() }
    operation.cancel()
    query.pending?.resume(returning: QueryResult(evidence: [], searchedCount: 0))
    do {
      try await operation.value
      XCTFail("Expected cancellation")
    } catch is CancellationError {}
    XCTAssertNil(manager.conversations.first?.turns.first?.result)
    XCTAssertEqual(manager.conversations.first?.turns.first?.question, "Who?")
    XCTAssertFalse(manager.isConversationOperationInProgress)
  }
  func testSaveFailureDoesNotPublishOrCallAI() async throws {
    let store = MemoryConversationRepository()
    let query = ConversationQueryStub()
    let manager = ConversationsFeature(repository: store, queryFeature: QueryFeature(searcher: query), now: { Date() })
    try await manager.load()
    await store.setFailure(true)
    do {
      try await manager.send("Who?", in: UUID())
      XCTFail("Expected failure")
    } catch {}
    XCTAssertTrue(manager.conversations.isEmpty)
    XCTAssertTrue(query.contexts.isEmpty)
  }
  func testFeedbackSurvivesReloadAndDeletionDoesNotTouchJournal() async throws {
    let store = MemoryConversationRepository()
    let query = ConversationQueryStub()
    let manager = ConversationsFeature(repository: store, queryFeature: QueryFeature(searcher: query), now: { Date() })
    let id = UUID()
    try await manager.send("Who?", in: id)
    let turn = try XCTUnwrap(manager.conversations.first?.turns.first)
    try await manager.recordFeedback(
      .inventedDetail, explanation: "Never recorded that.", turnID: turn.id, conversationID: id)
    let reloaded = ConversationsFeature(repository: store, queryFeature: QueryFeature(searcher: query), now: { Date() })
    try await reloaded.load()
    XCTAssertEqual(
      reloaded.conversations.first?.turns.first?.feedback?.explanation, "Never recorded that.")
    try await reloaded.delete(id)
    XCTAssertTrue(reloaded.conversations.isEmpty)
    XCTAssertEqual(query.contexts.count, 1)
  }
  func testDatabaseConversationRoundTripAndExport() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("chats.store")
    let store = SwiftDataManager(storeURL: url)
    let manager = ConversationsFeature(
      repository: store, queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let id = UUID()
    try await manager.send("My question", in: id)
    let loaded = try await SwiftDataManager(storeURL: url).load()
    XCTAssertEqual(loaded.first?.id, id)
    XCTAssertEqual(
      loaded.first?.turns.first?.result?.generatedAnswer?.text, "Your recorded answer.")
    let exported = try await manager.export()
    XCTAssertTrue(String(decoding: exported, as: UTF8.self).contains("My question"))

  }
}

extension ConversationsFeatureTests {
  func testFailedLoadRetriesAndExportPreservesTurns() async throws {
    let store = MemoryConversationRepository()
    let manager = ConversationsFeature(
      repository: store, queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    await store.setFailure(true)
    do {
      try await manager.load()
      XCTFail("Expected failure")
    } catch {}
    XCTAssertFalse(manager.isConversationOperationInProgress)
    await store.setFailure(false)
    try await manager.load()
    try await manager.send("Question", in: UUID())
    let data = try await manager.export()
    let archive = try JSONDecoder().decode([Conversation].self, from: data)
    XCTAssertEqual(archive.first?.turns.first?.question, "Question")
  }
  func testMissingRetryAndFeedbackAreRejectedAndOperationStateClears() async throws {
    let manager = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    do {
      try await manager.answerAgain(in: UUID())
      XCTFail("Expected missing")
    } catch {}
    do {
      try await manager.recordFeedback(
        .useful, explanation: "", turnID: UUID(), conversationID: UUID())
      XCTFail("Expected missing")
    } catch {}
    XCTAssertFalse(manager.isConversationOperationInProgress)
    XCTAssertNil(manager.activeTurnID)
    XCTAssertTrue(manager.conversations.isEmpty)
  }
  func testFeedbackIsBoundedAndFailedDeleteKeepsConversation() async throws {
    let store = MemoryConversationRepository()
    let manager = ConversationsFeature(
      repository: store, queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let id = UUID()
    try await manager.send("Question", in: id)
    let turn = try XCTUnwrap(manager.conversations.first?.turns.first)
    try await manager.recordFeedback(
      .useful, explanation: String(repeating: "a", count: 2100), turnID: turn.id, conversationID: id
    )
    XCTAssertEqual(manager.conversations.first?.turns.first?.feedback?.explanation.count, 2000)
    await store.setFailure(true)
    do {
      try await manager.delete(id)
      XCTFail("Expected failure")
    } catch {}
    XCTAssertEqual(manager.conversations.count, 1)
    XCTAssertFalse(manager.isConversationOperationInProgress)
  }
}

@MainActor private final class FailingConversationQuery: QuerySearching {
  func canSearch(_ question: String) -> Bool { !question.isEmpty }
  func search(_ question: String, previousQuestions: [String]) async throws -> QueryResult {
    throw TestFailure.unavailable
  }
}
extension ConversationsFeatureTests {
  func testGenerationFailureIsSavedWithQuestionAndExported() async throws {
    let manager = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: FailingConversationQuery()), now: { Date() }
    )
    XCTAssertFalse(manager.canSend(""))
    XCTAssertFalse(manager.canSend(String(repeating: "x", count: 501)))
    try await manager.send("Question", in: UUID())
    XCTAssertNotNil(manager.conversations.first?.turns.first?.failure)
    XCTAssertNil(manager.conversations.first?.turns.first?.result)
    XCTAssertNil(manager.activeTurnID)
    XCTAssertFalse(manager.isConversationOperationInProgress)
    let archive = try JSONDecoder().decode([Conversation].self, from: try await manager.export())
    XCTAssertNotNil(archive.first?.turns.first?.failure)
  }

  func testEquivalentExportsShareOneInFlightRepositoryRead() async throws {
    let entered = expectation(description: "Conversation export suspended")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let repository = PausedConversationExportRepository(barrier: barrier)
    let manager = ConversationsFeature(
      repository: repository, queryFeature: QueryFeature(searcher: ConversationQueryStub()),
      now: { Date() })

    let first = Task { try await manager.export() }
    await fulfillment(of: [entered], timeout: 2)
    let second = Task { try await manager.export() }
    await Task.yield()
    let exportCalls = await repository.exportCallCount()
    XCTAssertEqual(exportCalls, 1)
    await barrier.release()
    let firstData = try await first.value
    let secondData = try await second.value
    XCTAssertEqual(firstData, secondData)
  }
}

private actor PausedConversationExportRepository: ConversationRepository {
  let barrier: RaceBarrier
  private(set) var exportCalls = 0
  init(barrier: RaceBarrier) { self.barrier = barrier }
  func load() -> [Conversation] { [] }
  func save(_ conversations: [Conversation]) {}
  func exportCallCount() -> Int { exportCalls }
  func export(_ conversations: [Conversation]) async -> Data {
    exportCalls += 1
    await barrier.pause()
    return Data("conversation-export".utf8)
  }
}
