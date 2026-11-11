import XCTest

@testable import PersonalAPI

@MainActor final class ExportFeatureTests: XCTestCase {
  func testExportsRepositoryDataAndReadsSharedMomentCount() async throws {
    let graph = TestAppModelFactory()
    try await graph.app.momentsFeature.recordMoment(text: "Entry", happenedAt: nil)

    let data = try await graph.app.exportFeature.exportDataset()

    XCTAssertFalse(data.isEmpty)
    XCTAssertEqual(graph.app.exportFeature.momentCount, 1)
  }

  func testEquivalentExportsShareOneInFlightRepositoryRead() async throws {
    let entered = expectation(description: "Export suspended")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let repository = PausedRepository(.export, barrier: barrier)
    let momentsFeature = MomentsFeature(
      repository: repository, processor: LocalMomentProcessor(now: { Date() }), now: { Date() })
    let feature = ExportFeature(repository: repository, momentsFeature: momentsFeature)

    let first = Task { try await feature.exportDataset() }
    await fulfillment(of: [entered], timeout: 2)
    let second = Task { try await feature.exportDataset() }
    await barrier.release()

    let firstData = try await first.value
    let secondData = try await second.value
    XCTAssertEqual(firstData, secondData)
  }
}
