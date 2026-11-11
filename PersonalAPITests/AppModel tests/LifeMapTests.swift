import XCTest

@testable import PersonalAPI

private actor MapExtractorStub: LifeMapExtracting {
  let invented: Bool
  init(invented: Bool = false) { self.invented = invented }
  func extract(_ text: String) async throws -> [LifeMapCandidate] {
    if text == "Refused entry" { throw LifeMapError.refused }
    if invented { return [.init(title: "Invented", passage: "I flew to Mars.")] }
    return text.split(separator: "|").map { .init(title: String($0), passage: String($0)) }
  }
}
@MainActor final class LifeMapTests: XCTestCase {
  private func entry(_ text: String) -> MomentSnapshot {
    .init(
      id: UUID(), text: text, createdAt: Date(), happenedAt: nil, source: "journal",
      analysisData: nil, processingState: "pending")
  }
  func testThreeEntriesCanProduceFiveSourceBackedMoments() async throws {
    let repository = MemoryRepository()
    for text in [
      "I graduated.|I moved to London.", "I started work.|I met Sam.", "I adopted a dog.",
    ] {
      try await repository.saveMoment(entry(text))
    }
    let map = LifeMapFeature(repository: repository, extractor: MapExtractorStub())
    await map.refresh()
    XCTAssertEqual(map.entryCount, 3)
    XCTAssertEqual(map.processedCount, 3)
    XCTAssertEqual(map.points.count, 5)
    XCTAssertTrue(map.points.allSatisfy { $0.source.text.contains($0.passage) })
    let ids = map.points.map(\.id)
    await map.refresh()
    XCTAssertEqual(ids, map.points.map(\.id))
  }
  func testFailureDoesNotStopOtherEntriesAndProgressCompletes() async throws {
    let repository = MemoryRepository()
    for text in ["I graduated.", "Refused entry", "I moved."] {
      try await repository.saveMoment(entry(text))
    }
    let map = LifeMapFeature(repository: repository, extractor: MapExtractorStub())
    await map.refresh()
    XCTAssertEqual(map.attemptedCount, 3)
    XCTAssertEqual(map.processedCount, 2)
    XCTAssertEqual(map.failedCount, 1)
    XCTAssertEqual(map.points.count, 2)
    XCTAssertFalse(map.isReading)
    XCTAssertEqual(map.issue, LifeMapError.refused.localizedDescription)
    let originals = try await repository.loadMoments()
    XCTAssertEqual(originals.count, 3)
    await map.refresh()
    XCTAssertEqual(map.attemptedCount, 3)
    XCTAssertEqual(map.failedCount, 1)
    XCTAssertEqual(map.points.count, 2)
  }
  func testUnsupportedEvidenceIsNotPublished() async throws {
    let repository = MemoryRepository()
    try await repository.saveMoment(entry("I started work."))
    let map = LifeMapFeature(repository: repository, extractor: MapExtractorStub(invented: true))
    await map.refresh()
    XCTAssertTrue(map.points.isEmpty)
    XCTAssertEqual(map.processedCount, 0)
    XCTAssertNotNil(map.issue)
  }
}

extension LifeMapTests {
  func testEmptyDatasetFinishesWithoutIssue() async {
    let manager = LifeMapFeature(repository: MemoryRepository(), extractor: MapExtractorStub())
    await manager.refresh()
    XCTAssertEqual(manager.entryCount, 0)
    XCTAssertEqual(manager.attemptedCount, 0)
    XCTAssertFalse(manager.isReading)
    XCTAssertNil(manager.issue)
  }
  func testRepositoryFailureCanRetry() async {
    let store = MemoryRepository()
    let manager = LifeMapFeature(repository: store, extractor: MapExtractorStub())
    await store.setFailure(true)
    await manager.refresh()
    XCTAssertNotNil(manager.issue)
    XCTAssertFalse(manager.isReading)
    await store.setFailure(false)
    await manager.refresh()
    XCTAssertNil(manager.issue)
  }
}
