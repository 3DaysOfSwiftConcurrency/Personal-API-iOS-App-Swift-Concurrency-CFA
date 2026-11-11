import Foundation
import Observation

@MainActor @Observable final class BackupsViewModel {
  private let backupFeature: BackupFeature
  private var accountCheck: Task<Void, Never>?
  private var command: Task<Void, Never>?
  var showingAccountCheckResult = false
  private(set) var accountCheckResult = ""
  var importing = false
  var confirmingRestore = false
  private(set) var importError: String?
  init(backupFeature: BackupFeature = AppModel.shared.backupFeature) { self.backupFeature = backupFeature }
  var localCopies: [RecoveryCopy] { backupFeature.localCopies }
  func load() async {
    await backupFeature.loadLocalCopies()
    await checkSync()
  }
  var syncIssue: CloudSyncIssue? { backupFeature.syncIssue }
  var accountStatus: String? { backupFeature.accountStatus }
  var isCheckingAccount: Bool { backupFeature.isCheckingAccount }
  func checkSync() async { await backupFeature.checkSyncAvailability() }
  func checkAccountWithFeedback() async {
    await checkSync()
    accountCheckResult = backupFeature.accountStatus ?? "The account check could not confirm availability."
    if backupFeature.syncIssue != nil {
      accountCheckResult += "\n\nA sync issue is still reported. Expand Error details to see the underlying failure."
    }
    showingAccountCheckResult = true
  }
  func requestSyncCheck() {
    guard accountCheck == nil else { return }
    let task = Task { [self] in
      defer { accountCheck = nil }
      await checkAccountWithFeedback()
    }
    accountCheck = task
  }
  func requestInspect(_ url: URL) { importFinished(.success(url)) }
  var isWorking: Bool { backupFeature.isWorking }
  var status: String { backupFeature.status }
  var syncStatus: String { backupFeature.syncStatus }
  var error: String? { importError ?? backupFeature.error }
  private var errorContext: RecoveryFailureContext {
    importError != nil ? .readFile : backupFeature.errorContext ?? .createBackup
  }
  var errorTitle: String {
    switch errorContext {
    case .createBackup: return "Recovery backup could not be created"
    case .uploadBackup: return "Backup saved locally, but cloud copying failed"
    case .listBackups: return "Local recovery copies could not be listed"
    case .readFile: return "Recovery file could not be opened"
    case .restore: return "Recovery file could not be restored"
    case .restoreBusy: return "Restore is waiting for the current operation"
    case .refreshAfterRestore: return "Data restored, but the screen could not refresh"
    case .refreshAfterSync: return "iCloud changes arrived, but the screen could not refresh"
    }
  }
  var errorGuidance: String {
    switch errorContext {
    case .createBackup:
      return
        "No new recovery backup was completed. Your journal data has not been deleted. Check available device storage, then tap Back up now to try again."
    case .uploadBackup:
      return
        "The recovery copy is still saved on this device. Check your connection and iCloud Drive settings, then tap Back up now to retry."
    case .listBackups:
      return
        "The app could not read the list of local recovery files. Reopen this screen to try again. This has not deleted your journal data."
    case .readFile:
      return
        "Nothing has been restored. Make sure the file has downloaded and is a Personal API recovery file, then choose it again."
    case .restore:
      return
        "Your current data has not been replaced. Check the file and available device storage, then try restoring again."
    case .restoreBusy:
      return "Wait for the current chat operation to finish, then tap Restore this snapshot again."
    case .refreshAfterRestore:
      return
        "The restore completed and a safety copy of your previous data was saved. Reopen the app to refresh the screen; you do not need to restore again."
    case .refreshAfterSync:
      return
        "Reopen the app to reload the latest data. This message concerns refreshing the screen, not uploading a recovery backup."
    }
  }
  var preview: RecoverySnapshot? { backupFeature.preview }
  var lastBackup: Date? { backupFeature.lastBackup }

  func backupNow() async { await backupFeature.backup(force: true) }
  func requestBackup() {
    guard command == nil else { return }
    let task = Task { [self] in
      defer { command = nil }
      await backupNow()
    }
    command = task
  }
  func inspect(_ url: URL) async { await backupFeature.inspect(url) }
  func importFinished(_ result: Result<URL, Error>) {
    guard command == nil else { return }
    switch result {
    case .success(let url):
      importError = nil
      let task = Task { [self] in
        defer { command = nil }
        await inspect(url)
      }
      command = task
    case .failure(let error): importError = error.localizedDescription
    }
  }
  func restore() async { await backupFeature.restorePreview() }
  func requestRestore() {
    guard command == nil else { return }
    let task = Task { [self] in
      defer { command = nil }
      await restore()
    }
    command = task
  }
  func discardPreview() { backupFeature.discardPreview() }
}
