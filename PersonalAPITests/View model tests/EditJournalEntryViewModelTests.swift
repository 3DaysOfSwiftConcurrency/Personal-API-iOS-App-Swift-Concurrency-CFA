import XCTest

@testable import PersonalAPI

@MainActor final class EditJournalEntryViewModelTests: XCTestCase {
  func testFailedSaveKeepsDraftAndCanRetry() async throws {
    let graph = TestAppModelFactory()
    try await graph.app.momentsFeature.recordMoment(text: "Original", happenedAt: nil)
    await graph.app.momentsFeature.enrichPendingMoments()
    let original = try XCTUnwrap(graph.app.momentsFeature.moments.first)
    let model = EditJournalEntryViewModel(momentsFeature: graph.app.momentsFeature)
    model.prepare(original)
    model.text = "Revised"
    model.prepare(original)
    await graph.repository.setFailure(true)
    let failed = await model.save()
    XCTAssertFalse(failed)
    XCTAssertEqual(model.text, "Revised")
    XCTAssertNotNil(model.error)
    XCTAssertFalse(model.isWorking)
    await graph.repository.setFailure(false)
    let saved = await model.save()
    XCTAssertTrue(saved)
    XCTAssertEqual(graph.app.momentsFeature.moments.first?.text, "Revised")
  }
}

extension EditJournalEntryViewModelTests {
  func testCancelWithChangesRequiresDiscardAndPrepareDoesNotReplaceDraft() {
    let vm = EditJournalEntryViewModel(momentsFeature: TestAppModelFactory().app.momentsFeature)
    vm.prepare(raceMoment("Original"))
    vm.text = "Draft"
    vm.prepare(raceMoment("Another"))
    XCTAssertEqual(vm.text, "Draft")
    vm.cancel()
    XCTAssertTrue(vm.confirmingDiscard)
    XCTAssertFalse(vm.finished)
    vm.discard()
    XCTAssertTrue(vm.finished)
  }
  func testCancelWithoutChangesClosesAndUnchangedSaveIsDisabled() async {
    let vm = EditJournalEntryViewModel(momentsFeature: TestAppModelFactory().app.momentsFeature)
    vm.prepare(raceMoment("Original"))
    XCTAssertFalse(vm.canSave)
    let saved = await vm.save()
    XCTAssertFalse(saved)
    vm.cancel()
    XCTAssertTrue(vm.finished)
    XCTAssertFalse(vm.confirmingDiscard)
  }
  func testDeleteFailureKeepsEntryAndRetryRemovesIt() async throws {
    let graph = TestAppModelFactory()
    try await graph.app.momentsFeature.recordMoment(text: "Original", happenedAt: nil)
    await graph.app.momentsFeature.enrichPendingMoments()
    let vm = EditJournalEntryViewModel(momentsFeature: graph.app.momentsFeature)
    vm.prepare(try XCTUnwrap(graph.app.momentsFeature.moments.first))
    await graph.repository.setFailure(true)
    let failed = await vm.delete()
    XCTAssertFalse(failed)
    XCTAssertNotNil(vm.error)
    XCTAssertFalse(vm.isWorking)
    await graph.repository.setFailure(false)
    let removed = await vm.delete()
    XCTAssertTrue(removed)
    XCTAssertTrue(graph.app.momentsFeature.moments.isEmpty)
    XCTAssertNil(vm.error)
  }
}
