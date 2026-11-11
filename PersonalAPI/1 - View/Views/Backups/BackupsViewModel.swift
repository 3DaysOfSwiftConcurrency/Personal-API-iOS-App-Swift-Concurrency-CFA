import Foundation
import Observation

@MainActor @Observable final class BackupsViewModel {
  private let backupFeature: BackupFeature
  private var accountCheckTask: Task<Void, Never>?
  private var recoveryCommandTask: Task<Void, Never>?
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
  var accountStatus: String? {
    switch backupFeature.accountStatus {
    case .available:
      return "Your iCloud account is available. Sync retries automatically; this check does not confirm that data has uploaded."
    case .signedOut: return "Sign in to iCloud to enable sync."
    case .restricted: return "iCloud access is restricted on this device."
    case .unavailable: return "iCloud is temporarily unavailable. Check your connection and try again."
    case .checkFailed: return "Could not check your iCloud account."
    case nil: return nil
    }
  }
  var isCheckingAccount: Bool { backupFeature.isCheckingAccount }
  func checkSync() async { await backupFeature.checkSyncAvailability() }
  func checkAccountWithFeedback() async {
    await checkSync()
    accountCheckResult = accountStatus ?? "The account check could not confirm availability."
    if backupFeature.syncIssue != nil {
      accountCheckResult += "\n\nA sync issue is still reported. Expand Error details to see the underlying failure."
    }
    showingAccountCheckResult = true
  }
  @discardableResult
  func requestSyncCheck() -> Task<Void, Never> {
    if let accountCheckTask { return accountCheckTask }
    let task = Task { [self] in
      defer { accountCheckTask = nil }
      await checkAccountWithFeedback()
    }
    accountCheckTask = task
    return task
  }
  @discardableResult
  func requestInspect(_ url: URL) -> Task<Void, Never>? { importFinished(.success(url)) }
  var isWorking: Bool { backupFeature.isWorking }
  var status: String {
    switch backupFeature.status {
    case .noBackup: return "No recovery backup yet."
    case .savedLocally: return "Recovery backup saved on this device."
    case .uploaded: return "Recovery backup uploaded to iCloud Drive."
    case .uploadPending: return "Saved locally. iCloud Drive upload is pending."
    case .cloudUnavailable:
      return "Saved locally. iCloud Drive is unavailable; retry when signed in."
    case .restored: return "Restored. A copy of the previous data is saved on this device."
    }
  }
  var syncStatus: String {
    switch backupFeature.syncStatus {
    case .waiting: return "Waiting for iCloud sync."
    case .completed: return "Last iCloud operation completed."
    case .needsAttention: return "iCloud sync needs attention."
    }
  }
  var error: String? { importError ?? backupFeature.failure?.localizedDescription }
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
    case .restoreBlockedByConversationOperation: return "Restore is waiting for the current operation"
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
    case .restoreBlockedByConversationOperation:
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
  @discardableResult
  func requestBackup() -> Task<Void, Never> {
    if let recoveryCommandTask { return recoveryCommandTask }
    let task = Task { [self] in
      defer { recoveryCommandTask = nil }
      await backupNow()
    }
    recoveryCommandTask = task
    return task
  }
  func inspect(_ url: URL) async { await backupFeature.inspect(url) }
  @discardableResult
  func importFinished(_ result: Result<URL, Error>) -> Task<Void, Never>? {
    if let recoveryCommandTask { return recoveryCommandTask }
    switch result {
    case .success(let url):
      importError = nil
      let task = Task { [self] in
        defer { recoveryCommandTask = nil }
        await inspect(url)
      }
      recoveryCommandTask = task
      return task
    case .failure(let error):
      importError = error.localizedDescription
      return nil
    }
  }
  func restore() async { await backupFeature.restorePreview() }
  @discardableResult
  func requestRestore() -> Task<Void, Never> {
    if let recoveryCommandTask { return recoveryCommandTask }
    let task = Task { [self] in
      defer { recoveryCommandTask = nil }
      await restore()
    }
    recoveryCommandTask = task
    return task
  }
  func discardPreview() { backupFeature.discardPreview() }
}

extension CloudSyncIssue {
  var guidance: String {
    switch kind {
    case .account:
      return
        "Open Settings, tap your name and sign in to your Apple Account. Under iCloud, check that Personal API is allowed to use iCloud. Then return here and check again."
    case .restricted:
      return
        "iCloud access is restricted. Check Screen Time or ask the person managing this device to allow iCloud access, then check again."
    case .network:
      return
        "Check your Wi-Fi or mobile data connection, then check again. Sync will retry automatically when the connection is available."
    case .storage:
      return
        "Your iCloud storage is full. Open Settings → your name → iCloud to free space or change your storage plan, then check again."
    case .configuration:
      return
        "This version of the app is not configured correctly for iCloud. This needs an app update from the developer; changing your iCloud settings will not fix it. Your local data is not deleted."
    case .unknown:
      return
        "Check your connection and iCloud account below. If the problem continues, share the error details with the app developer. Your local data is not deleted."
    }
  }

  var offersSettings: Bool { kind != .configuration }
}
