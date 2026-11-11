import XCTest

@testable import PersonalAPI

@MainActor private final class PausedQuery: QuerySearching {
  let barrier: RaceBarrier
  init(_ barrier: RaceBarrier) { self.barrier = barrier }
  func canSearch(_ question: String) -> Bool { true }
  func search(_ question: String, previousQuestions: [String]) async throws -> QueryResult {
    await barrier.pause()
    return QueryResult(evidence: [], searchedCount: 0)
  }
}
@MainActor final class ConversationsRaceTests: XCTestCase {
  func testOverlappingSendAndDeleteAreRejectedWhileAnswerIsPending() async throws {
    let entered = expectation(description: "Answer entered")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let manager = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: PausedQuery(barrier)), now: { Date() })
    let id = UUID()
    let first = Task { try await manager.send("First?", in: id) }
    await fulfillment(of: [entered], timeout: 2)
    do {
      try await manager.send("Second?", in: id)
      XCTFail("Expected busy")
    } catch {}
    do {
      try await manager.delete(id)
      XCTFail("Expected busy")
    } catch {}
    await barrier.release()
    try await first.value
    XCTAssertEqual(manager.conversations.first?.turns.map(\.question), ["First?"])
    XCTAssertFalse(manager.isBusy)
  }
}
