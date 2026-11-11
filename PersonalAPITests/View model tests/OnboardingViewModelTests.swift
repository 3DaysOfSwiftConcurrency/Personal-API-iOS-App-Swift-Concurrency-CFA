import XCTest

@testable import PersonalAPI

@MainActor final class OnboardingViewModelTests: XCTestCase {
  func testCompletingOnboardingPersistsAcrossManagerReconstruction() {
    let graph = TestAppModelFactory()
    let vm = OnboardingViewModel(settingsFeature: graph.app.settingsFeature)
    vm.startDataset()
    let reloaded = SettingsFeature(
      preferences: graph.preferences, repository: graph.repository,
      momentsFeature: graph.app.momentsFeature, profileFeature: graph.app.profileFeature)
    reloaded.loadPreference()
    XCTAssertTrue(reloaded.onboarded)
  }
}
