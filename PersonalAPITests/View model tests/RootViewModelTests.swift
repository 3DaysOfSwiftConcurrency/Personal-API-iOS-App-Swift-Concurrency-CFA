import XCTest

@testable import PersonalAPI

@MainActor final class RootViewModelTests: XCTestCase {
  func testBackgroundRequiresUnlockAgain() async {
    let graph = TestAppModelFactory()
    let vm = RootViewModel(
      settingsFeature: graph.app.settingsFeature, authenticationFeature: graph.app.authenticationFeature,
      backupFeature: makeBackupFeature())
    await graph.app.authenticationFeature.setEnabled(true)
    XCTAssertFalse(vm.requiresUnlock)
    graph.app.applicationDidEnterBackground()
    XCTAssertTrue(vm.requiresUnlock)
  }
}

extension RootViewModelTests {
  func testOnboardingVisibilityTracksCompletion() {
    let graph = TestAppModelFactory()
    let vm = RootViewModel(
      settingsFeature: graph.app.settingsFeature, authenticationFeature: graph.app.authenticationFeature,
      backupFeature: makeBackupFeature())
    XCTAssertTrue(vm.needsOnboarding)
    XCTAssertFalse(vm.requiresUnlock)
    graph.app.settingsFeature.completeOnboarding()
    XCTAssertFalse(vm.needsOnboarding)
  }
}
