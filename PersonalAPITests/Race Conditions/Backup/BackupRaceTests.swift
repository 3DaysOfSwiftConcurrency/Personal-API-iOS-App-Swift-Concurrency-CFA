import XCTest

@testable import PersonalAPI

@MainActor final class BackupRaceTests: XCTestCase {
  func testRestoreWaitsForBackupSuspensionToFinish() async {
    let repository = RecoveryRepositoryStub()
    let files = RecoveryFilesStub()
    let manager = BackupFeature(
      repository: repository, files: files, account: CloudAccountStub(), preferences: MemoryPreferences(),
      now: { Date() }, canRestore: { true }, reload: {})
    await manager.inspect(URL(fileURLWithPath: "/preview"))
    await files.setHold()
    let backup = Task { await manager.backup(force: true) }
    await files.waitForPreparation()
    let restore = Task { await manager.restorePreview() }
    await Task.yield()
    let before = await repository.restores
    XCTAssertEqual(before, 0)
    await files.resume()
    await backup.value
    await restore.value
    let after = await repository.restores
    XCTAssertEqual(after, 1)
  }

  func testCancelledQueuedRestoreDoesNotMutateData() async {
    let repository = RecoveryRepositoryStub()
    let files = RecoveryFilesStub()
    let manager = BackupFeature(
      repository: repository, files: files, account: CloudAccountStub(), preferences: MemoryPreferences(),
      now: { Date() }, canRestore: { true }, reload: {})
    await manager.inspect(URL(fileURLWithPath: "/preview"))
    await files.setHold()
    let backup = Task { await manager.backup(force: false) }
    await files.waitForPreparation()
    let restore = Task { await manager.restorePreview() }
    restore.cancel()
    await files.resume()
    await backup.value
    await restore.value
    let restores = await repository.restores
    XCTAssertEqual(restores, 0)
    XCTAssertNotNil(manager.preview)
  }
}
