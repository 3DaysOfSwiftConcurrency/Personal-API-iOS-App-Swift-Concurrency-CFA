import XCTest

@testable import PersonalAPI

@MainActor final class SettingsFeatureTests: XCTestCase {
  func testPreferencesPersistAcrossReconstruction() {
    let graph = TestAppModelFactory()
    graph.app.settingsFeature.completeOnboarding()
    let manager = SettingsFeature(
      preferences: graph.preferences, repository: graph.repository,
      momentsFeature: graph.app.momentsFeature, profileFeature: graph.app.profileFeature)
    manager.loadPreference()
    XCTAssertTrue(manager.onboarded)
  }
  func testCountsReflectSharedFeaturesAndExportFailurePropagates() async throws {
    let graph = TestAppModelFactory()
    try await graph.app.momentsFeature.recordMoment(text: "Entry", happenedAt: nil)
    try await graph.app.profileFeature.addFact(label: "Job", value: "Teacher")
    await graph.app.momentsFeature.enrichPendingMoments()
    XCTAssertEqual(graph.app.settingsFeature.momentCount, 1)
    XCTAssertEqual(graph.app.settingsFeature.factCount, 1)
    await graph.repository.setFailure(true)
    do {
      _ = try await graph.app.settingsFeature.exportDataset()
      XCTFail("Expected failure")
    } catch {}
  }
  func testRegenerationCompletesAndFailurePropagates() async throws {
    let graph = TestAppModelFactory()
    try await graph.app.momentsFeature.recordMoment(text: "Entry", happenedAt: nil)
    await graph.app.momentsFeature.enrichPendingMoments()
    try await graph.app.settingsFeature.regenerateMetadata()
    XCTAssertNil(graph.app.settingsFeature.enrichmentError)
    XCTAssertEqual(graph.app.momentsFeature.moments.first?.processingState, "complete")
    await graph.repository.setFailure(true)
    do {
      try await graph.app.settingsFeature.regenerateMetadata()
      XCTFail("Expected failure")
    } catch {}
  }
}
