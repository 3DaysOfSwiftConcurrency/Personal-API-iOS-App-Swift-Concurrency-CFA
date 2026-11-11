import Foundation

/// The single live graph. Feature rules and screen state belong to their owners.
@MainActor final class AppModel {
  static let shared = AppModel.live()
  let backupFeature: BackupFeature
  let exportFeature: ExportFeature
  let lifeMapFeature: LifeMapFeature
  let momentsFeature: MomentsFeature
  let profileFeature: ProfileFeature
  let conversationsFeature: ConversationsFeature
  let queryFeature: QueryFeature
  let authenticationFeature: AuthenticationFeature
  let settingsFeature: SettingsFeature
  private var didFinishLaunching = false

  init(
    momentsFeature: MomentsFeature, profileFeature: ProfileFeature, queryFeature: QueryFeature,
    authenticationFeature: AuthenticationFeature, settingsFeature: SettingsFeature,
    conversationsFeature: ConversationsFeature, lifeMapFeature: LifeMapFeature,
    backupFeature: BackupFeature, exportFeature: ExportFeature
  ) {
    self.backupFeature = backupFeature
    self.exportFeature = exportFeature
    self.lifeMapFeature = lifeMapFeature
    self.conversationsFeature = conversationsFeature
    self.momentsFeature = momentsFeature
    self.profileFeature = profileFeature
    self.queryFeature = queryFeature
    self.authenticationFeature = authenticationFeature
    self.settingsFeature = settingsFeature
  }
  static func live() -> AppModel {
    let now: @Sendable () -> Date = { Date() }
    let repository = SwiftDataManager(cloudEnabled: true)
    let preferences = LocalPreferences(defaults: .standard)
    let moments = MomentsFeature(
      repository: repository, processor: LocalMomentProcessor(now: now), now: now)
    let profile = ProfileFeature(repository: repository, now: now)
    let query = QueryFeature(
      repository: repository, retriever: MomentRetriever(), index: LocalQueryIndex(),
      semanticSearch: OnDeviceMomentSearch(), answerer: OnDeviceMomentAnswerer())
    let conversations = ConversationsFeature(
      repository: repository, queryFeature: query, now: now)
    let backup = BackupFeature(
      repository: repository,
      files: RecoveryBackupFiles(
        folder: URL.applicationSupportDirectory.appendingPathComponent("PersonalAPI/Backups")),
      account: CloudAccountChecker(), preferences: preferences, now: now,
      canRestore: { !conversations.isConversationOperationInProgress },
      reload: {
        async let refreshMoments: Void = moments.reloadAfterRecovery()
        async let refreshProfile: Void = profile.reloadAfterRecovery()
        _ = try await (refreshMoments, refreshProfile)
        try await conversations.refresh()
      })
    return AppModel(
      momentsFeature: moments, profileFeature: profile,
      queryFeature: query,
      authenticationFeature: AuthenticationFeature(
        client: LocalDeviceAuthentication(), preferences: preferences),
      settingsFeature: SettingsFeature(
        preferences: preferences, repository: repository, momentsFeature: moments, profileFeature: profile),
      conversationsFeature: conversations,
      lifeMapFeature: LifeMapFeature(repository: repository, extractor: LifeMapExtractor()),
      backupFeature: backup,
      exportFeature: ExportFeature(repository: repository, momentsFeature: moments)
    )
  }
  func applicationDidFinishLaunching() async {
    guard !didFinishLaunching else { return }
    didFinishLaunching = true
    // Preferences are ready before any screen renders; construction itself does no I/O.
    authenticationFeature.loadPreference()
    settingsFeature.loadPreference()
    backupFeature.observeChanges()
    async let momentsFeature: Void = momentsFeature.loadIfRequired()
    async let profileFeature: Void = profileFeature.loadIfRequired()
    _ = await (momentsFeature, profileFeature)
    await backupFeature.backup(force: false)
  }

  func applicationDidBecomeActive() async {
    await backupFeature.backup(force: false)
  }

  func applicationDidEnterBackground() {
    authenticationFeature.lockForBackground()
  }
}
