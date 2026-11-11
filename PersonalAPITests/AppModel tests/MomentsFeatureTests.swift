import XCTest

@testable import PersonalAPI

@MainActor final class MomentsFeatureTests: XCTestCase {
  func testEnrichmentFailurePreservesCommittedSource() async throws {
    let graph = TestAppModelFactory(processor: FailingProcessor())
    try await graph.app.momentsFeature.recordMoment(text: "Dad called yesterday", happenedAt: nil)
    await graph.app.momentsFeature.enrichPendingMoments()
    let stored = try await graph.repository.loadMoments()
    XCTAssertEqual(stored.first?.text, "Dad called yesterday")
    XCTAssertEqual(stored.first?.processingState, "pending")
    XCTAssertNotNil(graph.app.momentsFeature.enrichmentFailure)
  }
  func testConcurrentSavesAndRefreshKeepBothSources() async throws {
    let graph = TestAppModelFactory()
    async let first: Void = graph.app.momentsFeature.recordMoment(text: "first", happenedAt: nil)
    async let second: Void = graph.app.momentsFeature.recordMoment(text: "second", happenedAt: nil)
    async let refresh: Void = graph.app.momentsFeature.refresh()
    _ = try await (first, second, refresh)
    await graph.app.momentsFeature.enrichPendingMoments()
    XCTAssertEqual(Set(graph.app.momentsFeature.moments.map(\.text)), ["first", "second"])
    XCTAssertEqual(
      Set(graph.app.momentsFeature.moments.map(\.createdAt)), [Date(timeIntervalSince1970: 1_000)])
  }
  func testFailedLoadCanRetryWithoutResettingStore() async {
    let graph = TestAppModelFactory()
    await graph.repository.setFailure(true)
    await graph.app.momentsFeature.loadIfRequired()
    XCTAssertNotNil(graph.app.momentsFeature.loadFailure)
    await graph.repository.setFailure(false)
    await graph.app.momentsFeature.loadIfRequired()
    XCTAssertNil(graph.app.momentsFeature.loadFailure)
  }
  func testCancelledSaveDoesNotPersist() async {
    let graph = TestAppModelFactory()
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      do {
        try await graph.app.momentsFeature.recordMoment(text: "cancelled", happenedAt: nil)
        XCTFail("Expected cancellation")
      } catch { XCTAssertTrue(error is CancellationError) }
    }
    await task.value
    XCTAssertTrue(graph.app.momentsFeature.moments.isEmpty)
  }
}

private actor RetryFactExtractor: JournalFactExtracting {
  var fails = true
  func allowExtraction() { fails = false }
  func extract(from moment: MomentSnapshot) async throws -> [PersonalFactSnapshot] {
    if fails { throw TestFailure.unavailable }
    return try await LocalJournalFactExtractor(now: { Date(timeIntervalSince1970: 100) }).extract(
      from: moment)
  }
}

extension MomentsFeatureTests {
  func testAutomaticFactsPreserveQualificationsAndBackfillCompletedEntries() async throws {
    let repository = MemoryRepository()
    let text =
      "I worked as a teacher in 2012, but no longer do.\nI love making apps, although deadlines can be stressful."
    let source = MomentSnapshot(
      id: UUID(), text: text, createdAt: Date(), happenedAt: nil,
      source: "manual", analysisData: nil, processingState: "complete")
    try await repository.saveMoment(source)
    let manager = MomentsFeature(
      repository: repository, processor: FailingProcessor(), now: { Date() })
    await manager.refresh()
    await manager.enrichPendingMoments()
    let facts = try await repository.loadFacts()
    XCTAssertEqual(Set(facts.map(\.value)), Set(text.components(separatedBy: "\n")))
    XCTAssertTrue(facts.allSatisfy { $0.isSupported(by: source) })
    XCTAssertNil(manager.enrichmentFailure)
    await manager.enrichPendingMoments()
    let again = try await repository.loadFacts()
    XCTAssertEqual(again, facts)
  }

  func testExtractionFailureDoesNotLoseJournalAndCanRetry() async throws {
    let repository = MemoryRepository()
    let extractor = RetryFactExtractor()
    let manager = MomentsFeature(
      repository: repository, processor: LocalMomentProcessor(now: { Date() }),
      now: { Date() }, factExtractor: extractor)
    try await manager.recordMoment(text: "My job is an iOS developer.", happenedAt: nil)
    await manager.enrichPendingMoments()
    let saved = try await repository.loadMoments()
    XCTAssertEqual(saved.count, 1)
    XCTAssertEqual(saved.first?.text, "My job is an iOS developer.")
    XCTAssertNotNil(manager.enrichmentFailure)
    await extractor.allowExtraction()
    await manager.enrichPendingMoments()
    let facts = try await repository.loadFacts()
    XCTAssertEqual(facts.count, 1)
    XCTAssertNil(manager.enrichmentFailure)
  }

  func testExtractionDoesNotInferFromUnrelatedTextOrTruncateLongQualifications() async throws {
    let text =
      "Alice is an engineer.\n" + String(repeating: "I like music but ", count: 60)
      + "this is fiction."
    let source = MomentSnapshot(
      id: UUID(), text: text, createdAt: Date(), happenedAt: nil,
      source: "manual", analysisData: nil, processingState: "pending")
    let facts = try await LocalJournalFactExtractor(now: { Date() }).extract(from: source)
    XCTAssertTrue(facts.isEmpty)
  }
}

extension MomentsFeatureTests {
  func testEditingReindexesAndFailedDeleteKeepsPublishedEntry() async throws {
    let graph = TestAppModelFactory()
    let feature = graph.app.momentsFeature
    try await feature.recordMoment(text: "I love teaching.", happenedAt: nil)
    await feature.enrichPendingMoments()
    let original = try XCTUnwrap(feature.moments.first)
    do {
      try await feature.updateMoment(original, text: " \n ")
      XCTFail("Expected empty error")
    } catch {}
    try await feature.updateMoment(original, text: "I love making apps.")
    await feature.enrichPendingMoments()
    let edited = try XCTUnwrap(feature.moments.first)
    XCTAssertEqual(edited.analysis?.title, "I love making apps.")
    let facts = try await graph.repository.loadFacts()
    XCTAssertEqual(facts.map(\.value), [edited.text])
    await graph.repository.setFailure(true)
    do {
      try await feature.deleteMoment(edited)
      XCTFail("Expected failure")
    } catch {}
    XCTAssertEqual(feature.moments, [edited])
    await graph.repository.setFailure(false)
    try await feature.deleteMoment(edited)
    XCTAssertTrue(feature.moments.isEmpty)
  }
}

private actor SuspendedEditProcessor: MomentProcessor {
  private var continuation: CheckedContinuation<Void, Never>?
  private var ready = false
  func started() -> Bool { ready }
  func resume() {
    continuation?.resume()
    continuation = nil
  }
  func analyse(_ input: MomentInput) async -> MomentAnalysis {
    if input.text == "Before" {
      await withCheckedContinuation {
        continuation = $0
        ready = true
      }
    }
    return .init(title: input.text, processor: "test", processedAt: Date())
  }
}

extension MomentsFeatureTests {
  func testOldProcessingCannotOverwriteAnEdit() async throws {
    let repository = MemoryRepository()
    let processor = SuspendedEditProcessor()
    let manager = MomentsFeature(repository: repository, processor: processor, now: { Date() })
    try await manager.recordMoment(text: "Before", happenedAt: nil)
    while !(await processor.started()) { await Task.yield() }
    let original = try XCTUnwrap(manager.moments.first)
    try await manager.updateMoment(original, text: "After")
    await processor.resume()
    await manager.enrichPendingMoments()
    XCTAssertEqual(manager.moments.first?.text, "After")
    XCTAssertEqual(manager.moments.first?.analysis?.title, "After")
  }
}

extension MomentsFeatureTests {
  func testSourceResolutionAndValidationStates() async throws {
    let graph = TestAppModelFactory()
    let feature = graph.app.momentsFeature
    let absent = raceMoment("Absent")
    if case .unavailable = feature.sourceState(for: absent) {
    } else {
      XCTFail("Expected unavailable")
    }
    await feature.loadIfRequired()
    XCTAssertFalse(feature.canRecord(" \n"))
    do {
      try await feature.recordMoment(text: "", happenedAt: nil)
      XCTFail("Expected invalid entry")
    } catch {}
    try await feature.recordMoment(text: "Before", happenedAt: nil)
    let original = try XCTUnwrap(feature.moments.first)
    if case .current = feature.sourceState(for: original) {} else { XCTFail("Expected current") }
    try await feature.updateMoment(original, text: "After")
    if case .edited = feature.sourceState(for: original) {} else { XCTFail("Expected edited") }
    XCTAssertEqual(feature.currentMoment(original).text, original.text)
    try await feature.deleteMoment(try XCTUnwrap(feature.moments.first))
    if case .deleted = feature.sourceState(for: original) {} else { XCTFail("Expected deleted") }
    await feature.enrichPendingMoments()
  }
  func testStaleEditFailsWithoutOverwritingNewerText() async throws {
    let graph = TestAppModelFactory()
    let feature = graph.app.momentsFeature
    try await feature.recordMoment(text: "Before", happenedAt: nil)
    let original = try XCTUnwrap(feature.moments.first)
    try await feature.updateMoment(original, text: "After")
    do {
      try await feature.updateMoment(original, text: "Stale")
      XCTFail("Expected conflict")
    } catch {}
    XCTAssertEqual(feature.moments.first?.text, "After")
    await feature.enrichPendingMoments()
  }
}
