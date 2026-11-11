import XCTest

@testable import PersonalAPI

@MainActor final class AppModelTests: XCTestCase {
  func testRepeatedLaunchSharesInitialLoad() async {
    let graph = TestAppModelFactory()
    await graph.app.applicationDidFinishLaunching()
    await graph.app.applicationDidFinishLaunching()
    let calls = await graph.repository.momentLoads
    XCTAssertEqual(calls, 1)
  }
}
