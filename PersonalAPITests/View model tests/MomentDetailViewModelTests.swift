import XCTest

@testable import PersonalAPI

@MainActor final class MomentDetailViewModelTests: XCTestCase {
  func testDetailReflectsLaterEnrichment() async throws {
    let graph = TestAppModelFactory()
    try await graph.app.momentsFeature.recordMoment(text: "Remember this", happenedAt: nil)
    let source = try XCTUnwrap(graph.app.momentsFeature.moments.first)
    let vm = MomentDetailViewModel(momentsFeature: graph.app.momentsFeature)
    await graph.app.momentsFeature.enrichPendingMoments()
    XCTAssertEqual(vm.current(source).processingState, "complete")
    XCTAssertEqual(vm.current(source).text, source.text)
  }
}

extension MomentDetailViewModelTests {
  func testHistoricalSourceKeepsItsWordsAfterEditOrDeletion() async throws {
    let graph = TestAppModelFactory()
    let feature = graph.app.momentsFeature
    try await feature.recordMoment(text: "Original words", happenedAt: nil)
    await feature.refresh()
    let source = try XCTUnwrap(feature.moments.first)
    let vm = MomentDetailViewModel(momentsFeature: feature)
    try await feature.updateMoment(source, text: "Revised words")
    XCTAssertEqual(vm.current(source).text, "Original words")
    XCTAssertNotNil(vm.sourceNotice(for: source))
    try await feature.deleteMoment(try XCTUnwrap(feature.moments.first))
    XCTAssertEqual(vm.current(source).text, "Original words")
    XCTAssertNotNil(vm.sourceNotice(for: source))
    await feature.enrichPendingMoments()
  }
}
