import Observation
import XCTest

@testable import PersonalAPI

@MainActor final class QueryViewModelTests: XCTestCase {
  func testMessagesRemainAndComposerClearsAfterSend() async throws {
    let manager = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let vm = QueryViewModel(conversationsFeature: manager)
    await vm.load()
    vm.question = "Who was Alex?"
    await vm.sendDraft()
    vm.question = "Where did we meet?"
    await vm.sendDraft()
    XCTAssertEqual(vm.turns.count, 2)
    XCTAssertEqual(vm.question, "")
    XCTAssertEqual(vm.answer(for: vm.turns[0]), "Your recorded answer.")
  }
  func testFreshLaunchStartsNewChatAndKeepsHistoryAvailable() async throws {
    let store = MemoryConversationRepository()
    let previous = ConversationsFeature(
      repository: store, queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let savedID = UUID()
    try await previous.send("Previous conversation", in: savedID)
    let relaunched = ConversationsFeature(
      repository: store, queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let vm = QueryViewModel(conversationsFeature: relaunched)
    await vm.load()
    XCTAssertNotEqual(vm.conversationID, savedID)
    XCTAssertTrue(vm.turns.isEmpty)
    XCTAssertTrue(vm.question.isEmpty)
    XCTAssertEqual(vm.conversations.count, 1)
    vm.open(savedID)
    await vm.load()
    XCTAssertEqual(vm.conversationID, savedID)
    XCTAssertEqual(vm.turns.first?.question, "Previous conversation")
  }
  func testFailedSaveKeepsDraft() async {
    let store = MemoryConversationRepository()
    let vm = QueryViewModel(
      conversationsFeature: ConversationsFeature(
        repository: store, queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() }))
    await vm.load()
    await store.setFailure(true)
    vm.question = "Keep this question"
    await vm.sendDraft()
    XCTAssertEqual(vm.question, "Keep this question")
    XCTAssertNotNil(vm.error)
    XCTAssertTrue(vm.turns.isEmpty)
  }
  func testNewChatAndReopenPreserveHistory() async {
    let vm = QueryViewModel(
      conversationsFeature: ConversationsFeature(
        repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    )
    vm.question = "First chat"
    await vm.sendDraft()
    let original = vm.conversationID
    vm.newChat()
    XCTAssertTrue(vm.turns.isEmpty)
    vm.open(original)
    XCTAssertEqual(vm.turns.first?.question, "First chat")
  }
  func testFailureAndMissingEvidenceDisplayDistinctly() {
    let vm = QueryViewModel(
      conversationsFeature: ConversationsFeature(
        repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    )
    let failed = ChatTurn(
      id: UUID(), question: "Who?", createdAt: Date(), failure: "Model unavailable")
    let missing = ChatTurn(
      id: UUID(), question: "Who?", createdAt: Date(),
      result: QueryResult(
        evidence: [], searchedCount: 1, needsMoreMemories: true, method: .onDeviceAI))
    XCTAssertEqual(vm.answer(for: failed), "Model unavailable")
    XCTAssertTrue(vm.answer(for: missing).contains("enough information"))
  }
}

extension QueryViewModelTests {
  func testSubmitIntentHandsOffDraftAndRetryKeepsSingleTurn() async throws {
    let chats = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let vm = QueryViewModel(conversationsFeature: chats)
    await vm.load()
    vm.question = "Question"
    vm.isQuestionFocused = true
    XCTAssertTrue(vm.canSearch)
    XCTAssertEqual(vm.rowCount, 1)
    vm.submitQuestion()
    XCTAssertFalse(vm.isQuestionFocused)
    XCTAssertTrue(vm.isSubmitting)
    let sent = expectation(description: "Submission completed")
    withObservationTracking {
      _ = vm.isSubmitting
    } onChange: {
      sent.fulfill()
    }
    await fulfillment(of: [sent], timeout: 2)
    XCTAssertEqual(vm.turns.count, 1)
    XCTAssertEqual(vm.rowCount, 2)
    XCTAssertEqual(vm.question, "")
    XCTAssertNil(vm.activeTurnID)
    vm.answerAgain()
    let retried = expectation(description: "Retry completed")
    withObservationTracking {
      _ = vm.isSubmitting
    } onChange: {
      retried.fulfill()
    }
    await fulfillment(of: [retried], timeout: 2)
    XCTAssertEqual(vm.turns.count, 1)
    XCTAssertNil(vm.error)
  }
  func testHistorySelectionFeedbackAndExportIntents() async throws {
    let chats = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let id = UUID()
    try await chats.send("Question", in: id)
    let vm = QueryViewModel(conversationsFeature: chats)
    vm.historySelection = id
    vm.openSelectedHistory()
    XCTAssertEqual(vm.conversationID, id)
    XCTAssertNil(vm.historySelection)
    let turn = try XCTUnwrap(vm.turns.first)
    vm.showFeedback(turn)
    XCTAssertEqual(vm.feedbackTurn?.id, turn.id)
    let feedback = expectation(description: "Feedback committed")
    withObservationTracking {
      _ = chats.conversations
    } onChange: {
      feedback.fulfill()
    }
    vm.markUseful(turn.id)
    await fulfillment(of: [feedback], timeout: 2)
    XCTAssertEqual(vm.turns.first?.feedback?.rating, .useful)
    let exported = expectation(description: "Export presentation")
    withObservationTracking {
      _ = vm.showsExport
    } onChange: {
      exported.fulfill()
    }
    vm.requestExport()
    await fulfillment(of: [exported], timeout: 2)
    XCTAssertTrue(vm.showsExport)
    vm.exportFinished(.failure(TestFailure.unavailable))
    XCTAssertNotNil(vm.error)
    vm.isQuestionFocused = true
    vm.showMomentEntry()
    XCTAssertTrue(vm.showsMemoryEntry)
    XCTAssertFalse(vm.isQuestionFocused)
    vm.disappeared()
  }
  func testCancelledSubmitKeepsQuestionAndRejectsLateAnswer() async throws {
    let query = ConversationQueryStub()
    query.deferred = true
    let chats = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: query), now: { Date() })
    let vm = QueryViewModel(conversationsFeature: chats)
    await vm.load()
    vm.question = "Question"
    vm.submitQuestion()
    // activeTurnID is set after the question commit, immediately before calling the query.
    let entered = expectation(description: "Answer requested")
    withObservationTracking {
      _ = chats.activeTurnID
    } onChange: {
      entered.fulfill()
    }
    await fulfillment(of: [entered], timeout: 2)
    let pending = try XCTUnwrap(query.pending)
    vm.cancelSearch()
    let finished = expectation(description: "Cancellation settled")
    withObservationTracking {
      _ = vm.isSubmitting
    } onChange: {
      finished.fulfill()
    }
    pending.resume(returning: QueryResult(evidence: [], searchedCount: 0))
    query.pending = nil
    await fulfillment(of: [finished], timeout: 2)
    XCTAssertEqual(vm.turns.first?.question, "Question")
    XCTAssertNil(vm.turns.first?.result)
    XCTAssertFalse(vm.isConversationOperationInProgress)
  }
}
