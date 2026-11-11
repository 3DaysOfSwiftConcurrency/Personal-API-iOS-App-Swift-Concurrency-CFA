import XCTest

@testable import PersonalAPI

@MainActor final class AuthenticationFeatureTests: XCTestCase {
  func testLateSuccessAfterBackgroundCannotUnlock() async {
    let graph = TestAppModelFactory()
    graph.preferences.lockEnabled = true
    graph.app.authenticationFeature.loadPreference()
    graph.authentication.suspended = true
    let request = Task { await graph.app.authenticationFeature.unlock() }
    while graph.authentication.pending == nil { await Task.yield() }
    graph.app.authenticationFeature.lockForBackground()
    graph.authentication.complete()
    await request.value
    XCTAssertFalse(graph.app.authenticationFeature.unlocked)
    XCTAssertTrue(graph.app.authenticationFeature.enabled)
  }
  func testDisablingRequiresAuthentication() async {
    let graph = TestAppModelFactory()
    graph.preferences.lockEnabled = true
    graph.app.authenticationFeature.loadPreference()
    graph.authentication.success = false
    await graph.app.authenticationFeature.setEnabled(false)
    XCTAssertTrue(graph.app.authenticationFeature.enabled)
    XCTAssertTrue(graph.preferences.lockEnabled)
  }
}

extension AuthenticationFeatureTests {
  func testSuccessfulEnableAndDisablePersistAndClearFailure() async {
    let graph = TestAppModelFactory()
    graph.authentication.success = false
    await graph.app.authenticationFeature.unlock()
    XCTAssertNotNil(graph.app.authenticationFeature.failure)
    graph.authentication.success = true
    await graph.app.authenticationFeature.setEnabled(true)
    XCTAssertTrue(graph.preferences.lockEnabled)
    XCTAssertTrue(graph.app.authenticationFeature.unlocked)
    XCTAssertNil(graph.app.authenticationFeature.failure)
    await graph.app.authenticationFeature.setEnabled(false)
    XCTAssertFalse(graph.preferences.lockEnabled)
    XCTAssertFalse(graph.app.authenticationFeature.enabled)
  }
}

@MainActor private final class ThrowingAuthentication: DeviceAuthentication {
  func authenticate() async throws -> Bool { throw TestFailure.unavailable }
  func cancel() {}
}
extension AuthenticationFeatureTests {
  func testProviderErrorLeavesPreferencesAndLockStateUnchanged() async {
    let preferences = MemoryPreferences()
    preferences.lockEnabled = true
    let manager = AuthenticationFeature(client: ThrowingAuthentication(), preferences: preferences)
    manager.loadPreference()
    await manager.setEnabled(false)
    XCTAssertTrue(manager.enabled)
    XCTAssertTrue(preferences.lockEnabled)
    XCTAssertFalse(manager.unlocked)
    XCTAssertFalse(manager.authenticating)
    XCTAssertNotNil(manager.failure)
  }
}
