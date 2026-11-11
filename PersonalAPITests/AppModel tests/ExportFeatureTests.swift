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
}
