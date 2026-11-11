import XCTest

@testable import PersonalAPI

private actor PausedMapExtractor: LifeMapExtracting {
  let barrier: RaceBarrier
  init(_ barrier: RaceBarrier) { self.barrier = barrier }
  func extract(_ text: String) async throws -> [LifeMapCandidate] {
    await barrier.pause()
    return [.init(title: "Original", passage: text)]
  }
}
@MainActor final class LifeMapRaceTests: XCTestCase {
  func testDeletionDuringExtractionCannotPublishOrphanAndRefreshCoalesces() async throws {
    let entered = expectation(description: "Extraction entered")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let repository = MemoryRepository()
    let source = raceMoment("I moved home.")
    try await repository.saveMoment(source)
    let manager = LifeMapFeature(repository: repository, extractor: PausedMapExtractor(barrier))
    let first = Task { await manager.refresh() }
    await fulfillment(of: [entered], timeout: 2)
    let second = Task { await manager.refresh() }
    try await repository.deleteMoment(source)
    await barrier.release()
    await first.value
    await second.value
    XCTAssertTrue(manager.points.isEmpty)
    XCTAssertEqual(manager.entryCount, 0)
    XCTAssertFalse(manager.isReading)
  }
}

extension LifeMapRaceTests {
  func testCancellingOneWaiterDoesNotCancelSharedRefresh() async throws {
    let entered = expectation(description: "Extraction suspended")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let repository = MemoryRepository()
    try await repository.saveMoment(raceMoment("Source"))
    let manager = LifeMapFeature(repository: repository, extractor: PausedMapExtractor(barrier))
    let operation = Task { await manager.refresh() }
    await fulfillment(of: [entered], timeout: 2)
    operation.cancel()
    await barrier.release()
    await operation.value
    XCTAssertEqual(manager.points.map(\.passage), ["Source"])
    XCTAssertFalse(manager.isReading)
    XCTAssertTrue(manager.failures.isEmpty)
    XCTAssertEqual(manager.failedCount, 0)
  }
}
