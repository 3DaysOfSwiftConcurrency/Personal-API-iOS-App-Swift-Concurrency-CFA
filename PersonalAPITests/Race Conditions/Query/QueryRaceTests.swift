import XCTest

@testable import PersonalAPI

private actor PausedSearch: SemanticMomentSearching {
  let barrier: RaceBarrier
  init(_ barrier: RaceBarrier) { self.barrier = barrier }
  func match(question: String, moments: [MomentSnapshot]) async throws -> [UUID] {
    if question == "first" { await barrier.pause() }
    return moments.map(\.id)
  }
}
@MainActor final class QueryRaceTests: XCTestCase {
  func testSecondSearchFinishesWhileFirstIsSuspendedAndCancellationIsIsolated() async throws {
    let entered = expectation(description: "First search entered")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let repository = MemoryRepository()
    try await repository.saveMoment(raceMoment("first second"))
    let manager = QueryFeature(
      repository: repository, retriever: MomentRetriever(), index: LocalQueryIndex(),
      semanticSearch: PausedSearch(barrier))
    let first = Task { try await manager.search("first") }
    await fulfillment(of: [entered], timeout: 2)
    let second = try await manager.search("second")
    XCTAssertEqual(second.evidence.count, 1)
    first.cancel()
    await barrier.release()
    do {
      _ = try await first.value
      XCTFail("Expected cancellation")
    } catch is CancellationError {}
    XCTAssertTrue(manager.canSearch("third"))
  }
}
