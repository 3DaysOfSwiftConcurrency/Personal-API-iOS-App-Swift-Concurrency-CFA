import XCTest

@testable import PersonalAPI

@MainActor final class SettingsRaceTests: XCTestCase {
  func testConcurrentExportsDoNotShareMutableResultOrResetPreferences() async throws {
    let graph = TestAppModelFactory()
    try await graph.repository.saveMoment(raceMoment("Source"))
    async let first = graph.app.settingsFeature.exportDataset()
    graph.app.settingsFeature.completeOnboarding()
    async let second = graph.app.settingsFeature.exportDataset()
    let (a, b) = try await (first, second)
    let decoder = JSONDecoder()
    let firstArchive = try decoder.decode(PersonalArchive.self, from: a)
    let secondArchive = try decoder.decode(PersonalArchive.self, from: b)
    XCTAssertEqual(firstArchive.moments.count, 1)
    XCTAssertEqual(secondArchive.moments.count, 1)
    XCTAssertTrue(graph.app.settingsFeature.onboarded)
  }
}

extension SettingsRaceTests {
  func testEquivalentExportsShareOneInFlightSnapshotThenRefreshAfterCompletion() async throws {
    let entered = expectation(description: "First export suspended")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let repository = PausedRepository(.export, barrier: barrier)
    let graph = TestAppModelFactory()
    let manager = SettingsFeature(
      preferences: graph.preferences, repository: repository,
      momentsFeature: graph.app.momentsFeature, profileFeature: graph.app.profileFeature)
    let first = Task { try await manager.exportDataset() }
    await fulfillment(of: [entered], timeout: 2)
    try await repository.saveMoment(raceMoment("New entry"))
    let second = Task { try await manager.exportDataset() }
    await barrier.release()
    let firstData = try await first.value
    let secondData = try await second.value
    let refreshedData = try await manager.exportDataset()
    let decoder = JSONDecoder()
    XCTAssertEqual(try decoder.decode(PersonalArchive.self, from: firstData).moments.count, 0)
    XCTAssertEqual(try decoder.decode(PersonalArchive.self, from: secondData).moments.count, 0)
    XCTAssertEqual(try decoder.decode(PersonalArchive.self, from: refreshedData).moments.count, 1)
  }
}
