import CoreData
import Foundation
import Observation

@MainActor @Observable final class BackupFeature {
  private(set) var localCopies: [RecoveryCopy] = []
  private(set) var isRestoring = false
  private(set) var isWorking = false
  private(set) var lastBackup: Date?
  private(set) var status = RecoveryStatus.noBackup
  private(set) var syncIssue: CloudSyncIssue?
  private(set) var accountStatus: CloudAccountStatus?
  private(set) var isCheckingAccount = false
  private var syncRevision = 0
  private var reportedSyncIssue: CloudSyncIssue?
  private let account: any CloudAccountChecking
  private(set) var syncStatus = CloudSyncStatus.waiting
  private(set) var errorContext: RecoveryFailureContext?
  private(set) var failure: Error?
  private(set) var preview: RecoverySnapshot?
  private let repository: any RecoveryRepository
  private let files: any RecoveryFiles
  private let preferences: any PreferencesRepository
  private let now: @Sendable () -> Date
  private let reload: @MainActor () async throws -> Void
  private let canRestore: @MainActor () -> Bool
  private let operations = FIFOOperationGate()
  @ObservationIgnored private var observation: Task<Void, Never>?
  @ObservationIgnored private var cloudObservation: Task<Void, Never>?
  @ObservationIgnored private var accountCheckTask: Task<Void, Never>?
  @ObservationIgnored private var localCopiesTask: Task<Void, Never>?

  init(
    repository: any RecoveryRepository, files: any RecoveryFiles,
    account: any CloudAccountChecking,
    preferences: any PreferencesRepository, now: @escaping @Sendable () -> Date,
    canRestore: @escaping @MainActor () -> Bool,
    reload: @escaping @MainActor () async throws -> Void
  ) {
    self.account = account
    self.repository = repository
    self.files = files
    self.preferences = preferences
    self.now = now
    self.canRestore = canRestore
    self.reload = reload
  }

  deinit {
    observation?.cancel()
    cloudObservation?.cancel()
    accountCheckTask?.cancel()
    localCopiesTask?.cancel()
  }

  func observeChanges() {
    guard observation == nil else { return }
    let repository = repository
    observation = Task { [weak self] in
      let stream = await repository.changes()
      for await _ in stream {
        guard !Task.isCancelled else { return }
        await self?.backup(force: false)
      }
    }
    cloudObservation = Task { [weak self] in
      let events = NotificationCenter.default.notifications(
        named: NSPersistentCloudKitContainer.eventChangedNotification
      )
      .compactMap { notification -> CloudSyncEvent? in
        guard
          let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event, event.endDate != nil
        else { return nil }
        return CloudSyncEvent(
          imported: event.type == .import && event.succeeded,
          succeeded: event.succeeded,
          issue: event.succeeded ? nil : CloudSyncIssue.from(event.error))
      }
      for await event in events {
        guard !Task.isCancelled else { return }
        await self?.receivedCloudEvent(event)
      }
    }
  }

  func receivedCloudEvent(_ event: CloudSyncEvent) async {
    syncRevision += 1
    reportedSyncIssue = event.issue
    syncIssue = event.issue
    accountStatus = nil
    syncStatus = event.succeeded ? .completed : .needsAttention
    if event.imported {
      do { try await reload() } catch { recordFailure(error, during: .refreshAfterSync) }
      await backup(force: false)
    }
  }

  /// Checks account access only. SwiftData owns transport and its retry schedule.
  func checkSyncAvailability() async {
    if let accountCheckTask {
      await accountCheckTask.value
      return
    }
    let task = Task { [self] in
      defer { accountCheckTask = nil }
      await performSyncAvailabilityCheck()
    }
    accountCheckTask = task
    await task.value
  }
  private func performSyncAvailabilityCheck() async {
    isCheckingAccount = true
    let revision = syncRevision
    defer { isCheckingAccount = false }
    do {
      let state = try await account.check()
      guard !Task.isCancelled, revision == syncRevision else { return }
      switch state {
      case .available:
        syncIssue = reportedSyncIssue
        accountStatus = .available
      case .signedOut:
        accountStatus = .signedOut
        syncIssue = CloudSyncIssue(kind: .account, details: nil)
      case .restricted:
        accountStatus = .restricted
        syncIssue = CloudSyncIssue(kind: .restricted, details: nil)
      case .unavailable:
        accountStatus = .unavailable
      }
    } catch {
      guard !Task.isCancelled, revision == syncRevision else { return }
      accountStatus = .checkFailed
      syncIssue = CloudSyncIssue.from(error)
    }
  }

  func backup(force: Bool) async {
    await operations.acquire()
    defer { operations.release() }
    guard !Task.isCancelled else { return }
    isWorking = true
    defer { isWorking = false }
    var stage = RecoveryFailureContext.createBackup
    do {
      let snapshot = try await repository.recoverySnapshot(
        at: now(), themeID: preferences.colourThemeID)
      guard let saved = try await files.prepare(snapshot, force: force) else { return }
      lastBackup = saved.createdAt
      status = .savedLocally
      stage = .listBackups
      localCopies = try await files.localCopies()
      stage = .uploadBackup
      errorContext = nil
      failure = nil
      switch try await files.upload() {
      case true?: status = .uploaded
      case false?: status = .uploadPending
      case nil: status = .cloudUnavailable
      }
    } catch { recordFailure(error, during: stage) }
  }

  func loadLocalCopies() async {
    if let localCopiesTask {
      await localCopiesTask.value
      return
    }
    let task = Task { [self] in
      defer { localCopiesTask = nil }
      await performLocalCopiesLoad()
    }
    localCopiesTask = task
    await task.value
  }
  private func performLocalCopiesLoad() async {
    do { localCopies = try await files.localCopies() } catch {
      recordFailure(error, during: .listBackups)
    }
  }

  func inspect(_ url: URL) async {
    await operations.acquire()
    defer { operations.release() }
    guard !Task.isCancelled else { return }
    isWorking = true
    defer { isWorking = false }
    preview = nil
    do {
      preview = try await files.preview(url)
      errorContext = nil
      failure = nil
    } catch { recordFailure(error, during: .readFile) }
  }

  func discardPreview() { preview = nil }

  func restorePreview() async {
    await operations.acquire()
    defer { operations.release() }
    guard !Task.isCancelled else { return }
    guard canRestore() else {
      recordFailure(BackupError.restoreBlockedByConversationOperation, during: .restoreBlockedByConversationOperation)
      return
    }
    guard let preview else { return }
    isWorking = true
    isRestoring = true
    defer {
      isWorking = false
      isRestoring = false
    }
    var stage = RecoveryFailureContext.restore
    do {
      try await repository.restore(
        preview, safetyFolder: files.safetyFolder, at: now(),
        previousThemeID: preferences.colourThemeID)
      // Device authentication preferences deliberately remain untouched.
      preferences.colourThemeID = preview.colourThemeID
      self.preview = nil
      status = .restored
      errorContext = nil
      failure = nil
      stage = .refreshAfterRestore
      try await reload()
      localCopies = try await files.localCopies()
    } catch { recordFailure(error, during: stage) }
  }
  private func recordFailure(_ failure: Error, during context: RecoveryFailureContext) {
    errorContext = context
    self.failure = failure
  }

}

struct CloudSyncEvent: Sendable {
  let imported: Bool
  let succeeded: Bool
  let issue: CloudSyncIssue?
}
