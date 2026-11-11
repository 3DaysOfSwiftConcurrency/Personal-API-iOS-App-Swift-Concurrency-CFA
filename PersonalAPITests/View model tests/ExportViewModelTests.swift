import XCTest

@testable import PersonalAPI

@MainActor final class ExportViewModelTests: XCTestCase {
  func testPreparedFileContainsDatasetAndCount() async throws {
    let graph = TestAppModelFactory()
    try await graph.app.momentsFeature.recordMoment(text: "Entry", happenedAt: nil)
    let vm = ExportViewModel(exportFeature: graph.app.exportFeature)
    let prepared = await vm.prepareExport()
    XCTAssertTrue(prepared)
    XCTAssertNotNil(vm.document)
    XCTAssertEqual(vm.momentCount, 1)
    XCTAssertFalse(vm.isExporting)
    XCTAssertNil(vm.message)
    await graph.app.momentsFeature.enrichPendingMoments()
  }
  func testFailedPreparationClearsPreviousDocumentAndCanRetry() async {
    let graph = TestAppModelFactory()
    let vm = ExportViewModel(exportFeature: graph.app.exportFeature)
    _ = await vm.prepareExport()
    await graph.repository.setFailure(true)
    let failed = await vm.prepareExport()
    XCTAssertFalse(failed)
    XCTAssertNil(vm.document)
    XCTAssertNotNil(vm.message)
    XCTAssertFalse(vm.isExporting)
    await graph.repository.setFailure(false)
    let retried = await vm.prepareExport()
    XCTAssertTrue(retried)
    XCTAssertNil(vm.message)
  }
  func testExportCompletionReleasesDocumentForSuccessAndFailure() async {
    let graph = TestAppModelFactory()
    let vm = ExportViewModel(exportFeature: graph.app.exportFeature)
    _ = await vm.prepareExport()
    vm.exportFinished(.success(URL(fileURLWithPath: "/tmp/test.json")))
    XCTAssertNil(vm.document)
    let success = vm.message
    _ = await vm.prepareExport()
    vm.exportFinished(.failure(TestFailure.unavailable))
    XCTAssertNil(vm.document)
    XCTAssertNotNil(vm.message)
    XCTAssertNotEqual(vm.message, success)
  }
}

extension ExportViewModelTests {
  func testOverlappingPreparationIsRejectedWithoutClearingFirstResult() async throws {
    let entered = expectation(description: "Export suspended")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let store = PausedRepository(.export, barrier: barrier)
    let graph = TestAppModelFactory()
    let exportFeature = ExportFeature(repository: store, momentsFeature: graph.app.momentsFeature)
    let vm = ExportViewModel(exportFeature: exportFeature)
    let first = Task { await vm.prepareExport() }
    await fulfillment(of: [entered], timeout: 2)
    XCTAssertTrue(vm.isExporting)
    let second = await vm.prepareExport()
    XCTAssertFalse(second)
    await barrier.release()
    let prepared = await first.value
    XCTAssertTrue(prepared)
    XCTAssertNotNil(vm.document)
    XCTAssertFalse(vm.isExporting)
  }
}
