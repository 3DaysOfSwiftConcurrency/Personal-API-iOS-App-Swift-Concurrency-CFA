import XCTest

@testable import PersonalAPI

final class BackupTests: XCTestCase {
  private func folder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
  private func snapshot(_ text: String, at seconds: Double = 1000) -> RecoverySnapshot {
    RecoverySnapshot(
      createdAt: Date(timeIntervalSince1970: seconds),
      moments: [
        MomentSnapshot(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: text,
          createdAt: Date(timeIntervalSince1970: 1), happenedAt: nil, source: "manual",
          analysisData: nil, processingState: "pending")
      ], facts: [], conversations: [], colourThemeID: "Twilight")
  }
  func testDailyThrottleManualOverrideAndPreviousPreservesDeletedData() async throws {
    let folder = try folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let files = RecoveryBackupFiles(folder: folder, cloudFolder: { nil })
    let first = snapshot("original")
    _ = try await files.prepare(first, force: false)
    let skipped = try await files.prepare(snapshot("edited", at: 2000), force: false)
    XCTAssertEqual(skipped?.moments.first?.text, "original")
    _ = try await files.prepare(snapshot("edited", at: 2000), force: true)
    let old = try RecoverySnapshot.decode(
      Data(contentsOf: folder.appendingPathComponent("Previous.json")))
    XCTAssertEqual(old.moments.first?.text, "original")
    let empty = RecoverySnapshot(
      createdAt: Date(timeIntervalSince1970: 100000), moments: [],
      facts: [], conversations: [], colourThemeID: nil)
    _ = try await files.prepare(empty, force: false)
    let latest = try RecoverySnapshot.decode(
      Data(contentsOf: folder.appendingPathComponent("Latest.json")))
    XCTAssertTrue(latest.isEmpty)
    let retained = try RecoverySnapshot.decode(
      Data(contentsOf: folder.appendingPathComponent("Previous.json")))
    XCTAssertEqual(retained.moments.first?.text, "edited")
    let uploaded = try await files.upload()
    XCTAssertNil(uploaded)
  }
  func testUnchangedWeeklySnapshotAndNewInstallationIsolation() async throws {
    let folder = try folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let cloud = folder.appendingPathComponent("cloud")
    let first = RecoveryBackupFiles(
      folder: folder.appendingPathComponent("one"), access: LocalBackupFileAccess(),
      cloudFolder: { cloud })
    _ = try await first.prepare(snapshot("same"), force: false)
    _ = try await first.prepare(snapshot("same", at: 1000 + 8 * 86400), force: false)
    let weeks = try FileManager.default.contentsOfDirectory(
      atPath: folder.appendingPathComponent("one/Weekly").path)
    XCTAssertEqual(weeks.count, 2)
    _ = try await first.upload()
    let second = RecoveryBackupFiles(
      folder: folder.appendingPathComponent("two"), access: LocalBackupFileAccess(),
      cloudFolder: { cloud })
    _ = try await second.prepare(snapshot("other"), force: false)
    _ = try await second.upload()
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(
        atPath: cloud.appendingPathComponent("Backups").path
      ).count, 2)
  }
  func testEmptyInstallationDoesNotProduceBackupAndCorruptionIsNotOverwritten() async throws {
    let folder = try folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let files = RecoveryBackupFiles(folder: folder, cloudFolder: { nil })
    let empty = RecoverySnapshot(
      createdAt: Date(), moments: [], facts: [], conversations: [], colourThemeID: nil)
    let result = try await files.prepare(empty, force: false)
    XCTAssertNil(result)
    let latest = folder.appendingPathComponent("Latest.json")
    try Data("broken".utf8).write(to: latest)
    do {
      _ = try await files.prepare(snapshot("new"), force: true)
      XCTFail("Must preserve corrupt file")
    } catch {}
    XCTAssertEqual(try Data(contentsOf: latest), Data("broken".utf8))
  }
  func testStaleChatSaveRejectedAndUnseenChatPreserved() async throws {
    let folder = try folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = SwiftDataManager(storeURL: folder.appendingPathComponent("test.store"))
    let chat = Conversation(id: UUID(), createdAt: Date(), updatedAt: Date(), turns: [])
    try await store.save([chat], replacing: [])
    let other = Conversation(id: UUID(), createdAt: Date(), updatedAt: Date(), turns: [])
    try await store.save([chat, other], replacing: [chat])
    try await store.save([], replacing: [chat])
    let remaining = try await store.load()
    XCTAssertEqual(remaining.map(\.id), [other.id])
    var changed = chat
    changed.updatedAt = Date(timeIntervalSince1970: 42)
    do {
      try await store.save([changed], replacing: [chat])
      XCTFail("Deleted chat must not reappear")
    } catch {}
  }
  func testRestoreSafetyCopyAndInvalidRestoreLeavesStoreUntouched() async throws {
    let folder = try folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = SwiftDataManager(storeURL: folder.appendingPathComponent("test.store"))
    let original = snapshot("original")
    try await store.saveMoment(original.moments[0])
    let safety = folder.appendingPathComponent("Before-restore")
    try await store.restore(snapshot("restored"), safetyFolder: safety, at: Date())
    let loaded = try await store.loadMoments()
    XCTAssertEqual(loaded.first?.text, "restored")
    let copies = try FileManager.default.contentsOfDirectory(
      at: safety, includingPropertiesForKeys: nil)
    XCTAssertEqual(copies.count, 1)
    XCTAssertEqual(
      try RecoverySnapshot.decode(Data(contentsOf: copies[0])).moments.first?.text, "original")
    var invalid = snapshot("invalid")
    invalid.version = 999
    do {
      try await store.restore(invalid, safetyFolder: safety, at: Date())
      XCTFail("Invalid archive")
    } catch {}
    let unchanged = try await store.loadMoments()
    XCTAssertEqual(unchanged.first?.text, "restored")
  }
  func testSafetyWriteFailurePreventsRestore() async throws {
    let folder = try folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = SwiftDataManager(storeURL: folder.appendingPathComponent("test.store"))
    try await store.saveMoment(snapshot("original").moments[0])
    let blocked = folder.appendingPathComponent("file")
    try Data().write(to: blocked)
    do {
      try await store.restore(snapshot("replacement"), safetyFolder: blocked, at: Date())
      XCTFail("Must fail")
    } catch {}
    let unchanged = try await store.loadMoments()
    XCTAssertEqual(unchanged.first?.text, "original")
  }
  func testAccountSwitchRejectsUpload() throws {
    let folder = try folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try BackupCloudAccount.verify("one" as NSString, in: folder)
    XCTAssertThrowsError(try BackupCloudAccount.verify("two" as NSString, in: folder))
    XCTAssertNoThrow(try BackupCloudAccount.verify("one" as NSString, in: folder))
  }
}

// Cloud file coordination requires the OS ubiquity service. Exercise copy policy
// with real local files, leaving NSFileCoordinator to the signed-device checklist.
struct LocalBackupFileAccess: BackupFileAccess {
  func writeNewSnapshot(_ data: Data, to target: URL) throws {
    if FileManager.default.fileExists(atPath: target.path) {
      guard try Data(contentsOf: target) == data else { throw BackupError.invalidFile }
    } else {
      try data.write(to: target, options: .atomic)
    }
  }
  func replaceSnapshot(_ data: Data, at target: URL) throws {
    try data.write(to: target, options: .atomic)
  }
  func read(_ url: URL) throws -> Data { try Data(contentsOf: url) }
}

extension BackupTests {
  func testLateAnalysisCannotOverwriteEditedSourceThroughProtocol() async throws {
    let folder = try folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store: any PersonalDataRepository = SwiftDataManager(
      storeURL: folder.appendingPathComponent("test.store"))
    let source = snapshot("old text").moments[0]
    try await store.saveMoment(source)
    _ = try await store.updateMoment(source, text: "edited text")
    let analysis = try await LocalMomentProcessor(now: { Date() }).analyse(
      MomentInput(text: source.text, createdAt: source.createdAt))
    do {
      _ = try await store.saveAnalysis(analysis, source: source)
      XCTFail("Stale analysis")
    } catch {}
    let current = try await store.loadMoments()
    XCTAssertNil(current.first?.analysisData)
  }
}
