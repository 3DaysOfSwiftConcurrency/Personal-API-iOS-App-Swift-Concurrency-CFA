import XCTest

@testable import PersonalAPI

private actor PausedAnalysis: MomentProcessor {
  let barrier: RaceBarrier
  init(_ barrier: RaceBarrier) { self.barrier = barrier }
  func analyse(_ input: MomentInput) async throws -> MomentAnalysis {
    await barrier.pause()
    return .init(title: input.text, processor: "test", processedAt: Date())
  }
}
@MainActor final class MomentsRaceTests: XCTestCase {
  func testDeletionWhileAnalysisIsSuspendedCannotRestoreEntry() async throws {
    let entered = expectation(description: "Analysis entered")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let repository = MemoryRepository()
    let manager = MomentsFeature(
      repository: repository, processor: PausedAnalysis(barrier), now: { Date() })
    try await manager.recordMoment(text: "Original", happenedAt: nil)
    await fulfillment(of: [entered], timeout: 2)
    let source = try XCTUnwrap(manager.moments.first)
    try await manager.deleteMoment(source)
    await barrier.release()
    await manager.enrichPendingMoments()
    let stored = try await repository.loadMoments()
    XCTAssertTrue(stored.isEmpty)
    XCTAssertTrue(manager.moments.isEmpty)
  }
}
