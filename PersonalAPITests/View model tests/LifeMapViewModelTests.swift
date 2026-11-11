import XCTest

@testable import PersonalAPI

private actor ViewMapExtractor: LifeMapExtracting {
  func extract(_ text: String) throws -> [LifeMapCandidate] {
    if text == "Failure" { throw TestFailure.unavailable }
    return [.init(title: "Experience", passage: text)]
  }
}
@MainActor final class LifeMapViewModelTests: XCTestCase {
  func testRefreshPublishesPointsAndProgress() async throws {
    let store = MemoryRepository()
    try await store.saveMoment(raceMoment("I moved."))
    let vm = LifeMapViewModel(
      lifeMapFeature: LifeMapFeature(repository: store, extractor: ViewMapExtractor()))
    await vm.refresh()
    XCTAssertEqual(vm.points.first?.passage, "I moved.")
    XCTAssertEqual(vm.entryCount, 1)
    XCTAssertEqual(vm.processedCount, 1)
    XCTAssertEqual(vm.attemptedCount, 1)
    XCTAssertEqual(vm.failedCount, 0)
    XCTAssertFalse(vm.isReading)
    XCTAssertNil(vm.issue)
  }
  func testFailedExtractionIsExposedAndRefreshCanRecover() async throws {
    let store = MemoryRepository()
    let original = raceMoment("Failure")
    try await store.saveMoment(original)
    let vm = LifeMapViewModel(
      lifeMapFeature: LifeMapFeature(repository: store, extractor: ViewMapExtractor()))
    await vm.refresh()
    XCTAssertEqual(vm.failedCount, 1)
    XCTAssertNotNil(vm.issue)
    _ = try await store.updateMoment(original, text: "Recovered")
    await vm.refresh()
    XCTAssertNil(vm.issue)
    XCTAssertEqual(vm.failedCount, 0)
    XCTAssertEqual(vm.points.count, 1)
  }
}
