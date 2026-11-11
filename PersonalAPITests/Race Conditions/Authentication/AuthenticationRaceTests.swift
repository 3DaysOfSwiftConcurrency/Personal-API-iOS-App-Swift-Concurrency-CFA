import XCTest

@testable import PersonalAPI

@MainActor private final class PausedAuthentication: DeviceAuthentication {
  let barrier: RaceBarrier
  init(_ barrier: RaceBarrier) { self.barrier = barrier }
  func authenticate() async throws -> Bool {
    await barrier.pause()
    return true
  }
  func cancel() {}
}
@MainActor final class AuthenticationRaceTests: XCTestCase {
  func testCancelledLateSuccessCannotEnableLockOrUnlock() async {
    let entered = expectation(description: "Authentication entered")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let preferences = MemoryPreferences()
    let manager = AuthenticationFeature(
      client: PausedAuthentication(barrier), preferences: preferences)
    let first = Task { await manager.setEnabled(true) }
    await fulfillment(of: [entered], timeout: 2)
    first.cancel()
    await barrier.release()
    await first.value
    XCTAssertFalse(manager.unlocked)
    XCTAssertFalse(manager.enabled)
    XCTAssertFalse(preferences.lockEnabled)
    XCTAssertFalse(manager.authenticating)
  }
}
