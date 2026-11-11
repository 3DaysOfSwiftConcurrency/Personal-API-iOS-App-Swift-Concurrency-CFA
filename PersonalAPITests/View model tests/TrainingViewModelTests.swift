import XCTest

@testable import PersonalAPI

@MainActor final class TrainingViewModelTests: XCTestCase {
  func testSavePreservesSourceAndClearsDraft() async throws {
    let graph = TestAppModelFactory()
    let vm = TrainingViewModel(momentsFeature: graph.app.momentsFeature)
    let original = "  Dad called.\nCafé 🌱\n"
    vm.text = original
    await vm.save()
    XCTAssertEqual(vm.text, "")
    XCTAssertTrue(vm.didSave)
    XCTAssertEqual(vm.moments.first?.text, original)
    await graph.app.momentsFeature.enrichPendingMoments()
    XCTAssertEqual(vm.moments.first?.text, original)
    XCTAssertEqual(vm.moments.first?.analysis?.title, "  Dad called.")
  }
  func testSaveFailureKeepsDraftAndDoesNotPublish() async {
    let graph = TestAppModelFactory()
    await graph.repository.setFailure(true)
    let vm = TrainingViewModel(momentsFeature: graph.app.momentsFeature)
    vm.text = "Keep this thought"
    await vm.save()
    XCTAssertEqual(vm.text, "Keep this thought")
    XCTAssertTrue(vm.moments.isEmpty)
    XCTAssertNotNil(vm.error)
    XCTAssertFalse(vm.didSave)
  }
  func testWhitespaceIsRejected() async {
    let graph = TestAppModelFactory()
    let vm = TrainingViewModel(momentsFeature: graph.app.momentsFeature)
    vm.text = " \n "
    XCTAssertFalse(vm.canSave)
    await vm.save()
    XCTAssertTrue(vm.moments.isEmpty)
    XCTAssertNotNil(vm.error)
    XCTAssertFalse(vm.didSave)
  }
}

extension TrainingViewModelTests {
  func testDoneDismissesKeyboardBeforeClosingEditor() {
    let vm = TrainingViewModel(momentsFeature: TestAppModelFactory().app.momentsFeature)
    vm.isMomentFocused = true
    vm.done()
    XCTAssertFalse(vm.isMomentFocused)
    XCTAssertFalse(vm.dismissRequested)
    vm.done()
    XCTAssertTrue(vm.dismissRequested)
  }
  func testLoadFailureIsVisibleAndRetryClearsIt() async {
    let graph = TestAppModelFactory()
    let vm = TrainingViewModel(momentsFeature: graph.app.momentsFeature)
    await graph.repository.setFailure(true)
    await vm.load()
    XCTAssertNotNil(vm.loadError)
    await graph.repository.setFailure(false)
    await vm.retry()
    XCTAssertNil(vm.loadError)
    XCTAssertFalse(vm.isLoading)
  }
}
