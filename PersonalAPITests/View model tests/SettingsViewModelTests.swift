import XCTest

@testable import PersonalAPI

@MainActor final class SettingsViewModelTests: XCTestCase {
  func testExportFailureCannotPresentOldDocument() async throws {
    let graph = TestAppModelFactory()
    let vm = SettingsViewModel(
      settingsFeature: graph.app.settingsFeature, authenticationFeature: graph.app.authenticationFeature)
    let first = await vm.prepareExport()
    XCTAssertTrue(first)
    XCTAssertNotNil(vm.document)
    await graph.repository.setFailure(true)
    let second = await vm.prepareExport()
    XCTAssertFalse(second)
    XCTAssertNil(vm.document)
    XCTAssertNotNil(vm.message)
  }
  func testExportIncludesRawSourceAndFacts() async throws {
    let graph = TestAppModelFactory()
    try await graph.app.momentsFeature.recordMoment(text: "  café\n", happenedAt: nil)
    try await graph.app.profileFeature.addFact(label: "Name", value: "Matthew")
    let vm = SettingsViewModel(
      settingsFeature: graph.app.settingsFeature, authenticationFeature: graph.app.authenticationFeature)
    let ready = await vm.prepareExport()
    XCTAssertTrue(ready)
    let document = try XCTUnwrap(vm.document)
    let decoded = try JSONDecoder().decode(PersonalArchive.self, from: document.data)
    XCTAssertEqual(decoded.moments.first?.text, "  café\n")
    XCTAssertEqual(decoded.facts.first?.value, "Matthew")
    XCTAssertEqual(vm.momentCount, 1)
    await graph.app.momentsFeature.enrichPendingMoments()
  }
}

extension SettingsViewModelTests {
  func testLockPreferenceAndRegenerationResultsArePresented() async throws {
    let graph = TestAppModelFactory()
    let vm = SettingsViewModel(
      settingsFeature: graph.app.settingsFeature, authenticationFeature: graph.app.authenticationFeature)
    await vm.setLockEnabled(true)
    XCTAssertTrue(vm.lockEnabled)
    XCTAssertNil(vm.authenticationError)
    await vm.regenerate()
    XCTAssertNotNil(vm.message)
    XCTAssertFalse(vm.isWorking)
    await graph.repository.setFailure(true)
    let prior = vm.message
    await vm.regenerate()
    XCTAssertNotEqual(vm.message, prior)
    XCTAssertFalse(vm.isWorking)
  }
  func testExportCompletionClearsDocumentAndReportsFailure() async {
    let graph = TestAppModelFactory()
    let vm = SettingsViewModel(
      settingsFeature: graph.app.settingsFeature, authenticationFeature: graph.app.authenticationFeature)
    _ = await vm.prepareExport()
    vm.exportFinished(.failure(TestFailure.unavailable))
    XCTAssertNil(vm.document)
    XCTAssertNotNil(vm.message)
    let failure = vm.message
    vm.exportFinished(.success(URL(fileURLWithPath: "/tmp/export.json")))
    XCTAssertNotEqual(vm.message, failure)
  }
}
