import XCTest

@testable import PersonalAPI

@MainActor final class LockViewModelTests: XCTestCase {
  func testRejectedAuthenticationKeepsDataLocked() async {
    let graph = TestAppModelFactory()
    graph.preferences.lockEnabled = true
    graph.app.authenticationFeature.loadPreference()
    graph.authentication.success = false
    let vm = LockViewModel(authenticationFeature: graph.app.authenticationFeature)
    await vm.unlock()
    XCTAssertFalse(graph.app.authenticationFeature.unlocked)
    XCTAssertNotNil(vm.error)
  }
}
