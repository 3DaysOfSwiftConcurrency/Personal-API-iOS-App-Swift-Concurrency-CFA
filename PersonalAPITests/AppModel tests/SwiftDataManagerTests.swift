import XCTest

@testable import PersonalAPI

final class SwiftDataManagerTests: XCTestCase {
  func testCreatesMissingStoreDirectoryAndCoalescesFirstRequests() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SwiftDataManager(storeURL: root.appendingPathComponent("Database/data.store"))

    async let moments = store.loadMoments()
    async let facts = store.loadFacts()
    let values = try await (moments, facts)

    XCTAssertTrue(values.0.isEmpty)
    XCTAssertTrue(values.1.isEmpty)
    XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Database").path))
  }

  func testFailedDirectoryPreparationCanRetryWithoutChangingStoreLocation() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let blocker = root.appendingPathComponent("Database")
    try Data("blocker".utf8).write(to: blocker)
    let store = SwiftDataManager(storeURL: blocker.appendingPathComponent("data.store"))

    do {
      _ = try await store.loadMoments()
      XCTFail("Expected directory preparation to fail")
    } catch {}

    try FileManager.default.removeItem(at: blocker)
    let moments = try await store.loadMoments()
    XCTAssertTrue(moments.isEmpty)
  }

  func testReopenAndExportPreserveSourceAndTimestamp() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("test.store")
    let source = MomentSnapshot(
      id: UUID(), text: "  café 🌱\n", createdAt: Date(timeIntervalSince1970: 123.456),
      happenedAt: nil, source: "manual", analysisData: nil, processingState: "pending")
    let store = SwiftDataManager(storeURL: url)
    try await store.saveMoment(source)
    let reopened = SwiftDataManager(storeURL: url)
    let records = try await reopened.loadMoments()
    XCTAssertEqual(records.first, source)
    let data = try await reopened.exportArchive()
    let archive = try JSONDecoder().decode(PersonalArchive.self, from: data)
    XCTAssertEqual(archive.moments.first?.text, source.text)
    XCTAssertEqual(archive.moments.first?.id, source.id)
    XCTAssertEqual(archive.moments.first?.createdAt, source.createdAt)
  }
  func testProcessorDoesNotInventSensitiveMetadata() async throws {
    let processor = LocalMomentProcessor(now: { Date(timeIntervalSince1970: 100) })
    let result = try await processor.analyse(
      MomentInput(text: "Dad called yesterday", createdAt: Date()))
    XCTAssertTrue(result.emotions.isEmpty)
    XCTAssertNil(result.extractedEventDate)
    XCTAssertNil(result.lifeEvent)
  }
}

extension SwiftDataManagerTests {
  func testDerivedFactsReopenExportAndReplaceWithoutDuplicatesOrLosingLegacyFacts() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("facts.store")
    let store = SwiftDataManager(storeURL: url)
    let source = MomentSnapshot(
      id: UUID(), text: "I enjoyed teaching in 2012, but no longer do.",
      createdAt: Date(), happenedAt: nil, source: "manual", analysisData: nil,
      processingState: "pending")
    try await store.saveMoment(source)
    let legacy = PersonalFactSnapshot(
      id: UUID(), label: "Old fact", value: "Keep me", createdAt: Date())
    try await store.saveFact(legacy)
    let extractor = LocalJournalFactExtractor(now: { Date() })
    let facts = try await extractor.extract(from: source)
    try await store.replaceDerivedFacts(facts, source: source)
    try await store.replaceDerivedFacts(extractor.extract(from: source), source: source)
    let reopened = SwiftDataManager(storeURL: url)
    let loaded = try await reopened.loadFacts()
    XCTAssertEqual(loaded.count, 2)
    XCTAssertTrue(loaded.contains(legacy))
    XCTAssertEqual(loaded.first(where: { $0.derivation != nil }), facts.first)
    let archive = try JSONDecoder().decode(
      PersonalArchive.self, from: await reopened.exportArchive())
    XCTAssertTrue(archive.facts.contains(facts[0]))
    try await reopened.replaceDerivedFacts([], source: source)
    let remaining = try await reopened.loadFacts()
    XCTAssertEqual(remaining, [legacy])
    let sources = try await reopened.loadMoments()
    XCTAssertEqual(sources.first?.text, source.text)
  }
}

extension SwiftDataManagerTests {
  func testLegacyFactJSONDecodesWithoutDerivation() throws {
    let id = UUID()
    let data = try JSONSerialization.data(withJSONObject: [
      "id": id.uuidString,
      "label": "Occupation", "value": "Teacher", "createdAt": 0,
    ])
    let legacy = try JSONDecoder().decode(PersonalFactSnapshot.self, from: data)
    XCTAssertEqual(legacy.id, id)
    XCTAssertEqual(legacy.value, "Teacher")
    XCTAssertNil(legacy.derivation)
  }

  func testInvalidReplacementLeavesExistingDerivedFactsIntact() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = SwiftDataManager(storeURL: folder.appendingPathComponent("facts.store"))
    let source = MomentSnapshot(
      id: UUID(), text: "My job is teaching.", createdAt: Date(),
      happenedAt: nil, source: "manual", analysisData: nil, processingState: "pending")
    try await store.saveMoment(source)
    let facts = try await LocalJournalFactExtractor(now: { Date() }).extract(from: source)
    try await store.replaceDerivedFacts(facts, source: source)
    let invented = PersonalFactSnapshot(
      id: UUID(), label: "Occupation", value: "I work as a pilot.",
      createdAt: Date(), derivation: facts.first?.derivation)
    do {
      try await store.replaceDerivedFacts([invented], source: source)
      XCTFail("Unsupported replacement should fail")
    } catch {}
    let loaded = try await store.loadFacts()
    XCTAssertEqual(loaded, facts)
  }
}

extension SwiftDataManagerTests {
  func testEditAndDeletePersistAndInvalidateOnlyTheirDerivedFacts() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("journal.store")
    let store = SwiftDataManager(storeURL: url)
    let source = MomentSnapshot(
      id: UUID(), text: "I love teaching.", createdAt: Date(timeIntervalSince1970: 123),
      happenedAt: nil, source: "manual", analysisData: nil, processingState: "pending")
    try await store.saveMoment(source)
    let legacy = PersonalFactSnapshot(
      id: UUID(), label: "Keep", value: "Independent fact", createdAt: Date())
    try await store.saveFact(legacy)
    let extractor = LocalJournalFactExtractor(now: { Date() })
    try await store.replaceDerivedFacts(extractor.extract(from: source), source: source)
    _ = try await store.saveAnalysis(
      .init(title: "Old title", processor: "test", processedAt: Date()), momentID: source.id)
    let updated = try await store.updateMoment(source, text: "I love making apps.")
    XCTAssertEqual(updated.id, source.id)
    XCTAssertEqual(updated.createdAt, source.createdAt)
    XCTAssertNil(updated.analysisData)
    XCTAssertEqual(updated.processingState, "pending")
    let reopened = SwiftDataManager(storeURL: url)
    let records = try await reopened.loadMoments()
    XCTAssertEqual(records, [updated])
    let remainingFacts = try await reopened.loadFacts()
    XCTAssertEqual(remainingFacts, [legacy])
    do {
      _ = try await reopened.updateMoment(source, text: "Stale edit")
      XCTFail("Expected conflict")
    } catch { XCTAssertEqual(error as? MomentError, .changedMoment) }
    do {
      try await reopened.deleteMoment(source)
      XCTFail("Expected conflict")
    } catch { XCTAssertEqual(error as? MomentError, .changedMoment) }
    try await reopened.replaceDerivedFacts(extractor.extract(from: updated), source: updated)
    try await reopened.deleteMoment(updated)
    let archive = try JSONDecoder().decode(
      PersonalArchive.self, from: await reopened.exportArchive())
    XCTAssertTrue(archive.moments.isEmpty)
    XCTAssertEqual(archive.facts, [legacy])
  }
}
