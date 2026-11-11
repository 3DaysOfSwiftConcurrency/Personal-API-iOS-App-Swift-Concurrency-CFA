import XCTest

@testable import PersonalAPI

actor RecoveryRepositoryStub: RecoveryRepository {
  var restores = 0
  var snapshots = 0
  var failRestore = false
  func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
  func recoverySnapshot(at date: Date, themeID: String?) -> RecoverySnapshot {
    snapshots += 1
    return RecoverySnapshot(
      createdAt: date, moments: [], facts: [], conversations: [], colourThemeID: themeID)
  }
  func restore(
    _ snapshot: RecoverySnapshot, safetyFolder: URL, at date: Date, previousThemeID: String?
  ) throws {
    if failRestore { throw TestFailure.unavailable }
    restores += 1
  }
  func setRestoreFailure() { failRestore = true }
}

actor RecoveryFilesStub: RecoveryFiles {
  nonisolated let safetyFolder = URL(fileURLWithPath: "/unused")
  var holdsPreparation = false
  var preparationStarted = false
  var prepared: CheckedContinuation<Void, Never>?
  var release: CheckedContinuation<Void, Never>?
  var failUpload = false
  var uploaded: Bool? = nil
  let sample = RecoverySnapshot(
    createdAt: Date(timeIntervalSince1970: 1), moments: [],
    facts: [], conversations: [], colourThemeID: "Twilight")
  func setHold() { holdsPreparation = true }
  func setUploadFailure() { failUpload = true }
  func setUploaded(_ value: Bool?) { uploaded = value }
  func prepare(_ snapshot: RecoverySnapshot, force: Bool) async -> RecoverySnapshot? {
    preparationStarted = true
    prepared?.resume()
    prepared = nil
    if holdsPreparation { await withCheckedContinuation { release = $0 } }
    return snapshot
  }
  func waitForPreparation() async {
    if !preparationStarted { await withCheckedContinuation { prepared = $0 } }
  }
  func resume() {
    release?.resume()
    release = nil
    holdsPreparation = false
  }
  func upload() throws -> Bool? {
    if failUpload { throw TestFailure.unavailable }
    return uploaded
  }
  func localCopies() -> [RecoveryCopy] { [] }
  func preview(_ url: URL) -> RecoverySnapshot { sample }
}

@MainActor final class BackupFeatureTests: XCTestCase {
  func testCloudFailureRetainsLocalSuccess() async {
    let repository = RecoveryRepositoryStub()
    let files = RecoveryFilesStub()
    await files.setUploadFailure()
    let manager = BackupFeature(
      repository: repository, files: files, account: CloudAccountStub(), preferences: MemoryPreferences(),
      now: { Date(timeIntervalSince1970: 99) }, canRestore: { true }, reload: {})
    await manager.backup(force: true)
    XCTAssertEqual(manager.lastBackup, Date(timeIntervalSince1970: 99))
    XCTAssertNotNil(manager.error)
    XCTAssertFalse(manager.isWorking)
    XCTAssertTrue(manager.status.contains("this device"))
    XCTAssertEqual(manager.errorContext, .uploadBackup)
  }

  func testRestoreFailurePreservesPreviewAndPreferences() async {
    let repository = RecoveryRepositoryStub()
    await repository.setRestoreFailure()
    let preferences = MemoryPreferences()
    preferences.colourThemeID = "Ocean"
    let manager = BackupFeature(
      repository: repository, files: RecoveryFilesStub(), account: CloudAccountStub(), preferences: preferences,
      now: { Date() }, canRestore: { true }, reload: {})
    await manager.inspect(URL(fileURLWithPath: "/preview"))
    await manager.restorePreview()
    XCTAssertEqual(preferences.colourThemeID, "Ocean")
    XCTAssertEqual(manager.errorContext, .restore)
    XCTAssertNotNil(manager.preview)
    XCTAssertNotNil(manager.error)
    XCTAssertFalse(manager.isRestoring)
  }

  func testRestoreAppliesPreferencesReloadsAndClearsPreview() async {
    let preferences = MemoryPreferences()
    preferences.lockEnabled = true
    var reloaded = false
    let manager = BackupFeature(
      repository: RecoveryRepositoryStub(), files: RecoveryFilesStub(), account: CloudAccountStub(), preferences: preferences,
      now: { Date() }, canRestore: { true }, reload: { reloaded = true })
    await manager.inspect(URL(fileURLWithPath: "/preview"))
    await manager.restorePreview()
    XCTAssertNil(manager.preview)
    XCTAssertEqual(preferences.colourThemeID, "Twilight")
    XCTAssertTrue(preferences.lockEnabled)
    XCTAssertTrue(reloaded)
  }

  func testBusyChatPreventsRestore() async {
    let repository = RecoveryRepositoryStub()
    let manager = BackupFeature(
      repository: repository, files: RecoveryFilesStub(), account: CloudAccountStub(), preferences: MemoryPreferences(),
      now: { Date() }, canRestore: { false }, reload: {})
    await manager.inspect(URL(fileURLWithPath: "/preview"))
    await manager.restorePreview()
    let restores = await repository.restores
    XCTAssertEqual(restores, 0)
    XCTAssertNotNil(manager.error)
    XCTAssertNotNil(manager.preview)
  }

  func testUploadStatusDistinguishesPendingFromConfirmed() async {
    let files = RecoveryFilesStub()
    let manager = BackupFeature(
      repository: RecoveryRepositoryStub(), files: files, account: CloudAccountStub(), preferences: MemoryPreferences(),
      now: { Date() }, canRestore: { true }, reload: {})
    await files.setUploaded(false)
    await manager.backup(force: true)
    XCTAssertTrue(manager.status.contains("pending"))
    await files.setUploaded(true)
    await manager.backup(force: true)
    XCTAssertTrue(manager.status.contains("uploaded"))
  }
}
