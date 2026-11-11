import XCTest

@testable import PersonalAPI

@MainActor final class JournalEntriesViewModelTests: XCTestCase {
  func testListReflectsDeletionThroughSharedFeature() async throws {
    let graph = TestAppModelFactory()
    try await graph.app.momentsFeature.recordMoment(text: "An entry", happenedAt: nil)
    await graph.app.momentsFeature.enrichPendingMoments()
    let model = JournalEntriesViewModel(momentsFeature: graph.app.momentsFeature)
    await model.refresh()
    XCTAssertEqual(model.entries.count, 1)
    try await graph.app.momentsFeature.deleteMoment(XCTUnwrap(model.entries.first))
    XCTAssertTrue(model.entries.isEmpty)
  }
}

extension JournalEntriesViewModelTests {
  func testRefreshFailureAndRecoveryAreVisible() async {
    let graph = TestAppModelFactory()
    let vm = JournalEntriesViewModel(momentsFeature: graph.app.momentsFeature)
    await graph.repository.setFailure(true)
    await vm.refresh()
    XCTAssertNotNil(vm.error)
    XCTAssertFalse(vm.isLoading)
    await graph.repository.setFailure(false)
    await vm.refresh()
    XCTAssertNil(vm.error)
  }
}
