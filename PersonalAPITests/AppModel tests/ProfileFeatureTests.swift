import XCTest

@testable import PersonalAPI

@MainActor final class ProfileFeatureTests: XCTestCase {
  func testValidationRejectsEmptyLabelAndValue() async {
    let manager = ProfileFeature(repository: MemoryRepository(), now: { Date() })
    XCTAssertFalse(manager.canSave(label: " ", value: "Value"))
    XCTAssertFalse(manager.canSave(label: "Label", value: "\n"))
    do {
      try await manager.addFact(label: "", value: "Value")
      XCTFail("Expected rejection")
    } catch {}
    XCTAssertTrue(manager.facts.isEmpty)
  }
  func testSavePreservesTextAndTimestamp() async throws {
    let store = MemoryRepository()
    let date = Date(timeIntervalSince1970: 10)
    let manager = ProfileFeature(repository: store, now: { date })
    try await manager.addFact(label: " Job ", value: " Teacher ")
    let stored = try await store.loadFacts()
    XCTAssertEqual(stored, manager.facts)
    XCTAssertEqual(stored.first?.value, " Teacher ")
    XCTAssertEqual(stored.first?.createdAt, date)
  }
  func testFailedWriteDoesNotPublish() async {
    let store = MemoryRepository()
    let manager = ProfileFeature(repository: store, now: { Date() })
    await store.setFailure(true)
    do {
      try await manager.addFact(label: "Job", value: "Teacher")
      XCTFail("Expected failure")
    } catch {}
    XCTAssertTrue(manager.facts.isEmpty)
  }
  func testLoadFailureRetriesAndSuccessfulLoadIsCached() async {
    let store = MemoryRepository()
    let manager = ProfileFeature(repository: store, now: { Date() })
    await store.setFailure(true)
    await manager.loadIfRequired()
    XCTAssertNotNil(manager.loadError)
    XCTAssertFalse(manager.isLoading)
    await store.setFailure(false)
    await manager.loadIfRequired()
    XCTAssertNil(manager.loadError)
    await store.setFailure(true)
    await manager.loadIfRequired()
    XCTAssertNil(manager.loadError)
    await manager.refresh()
    XCTAssertNotNil(manager.loadError)
  }
}
