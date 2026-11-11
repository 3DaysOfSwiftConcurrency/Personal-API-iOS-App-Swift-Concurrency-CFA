import Foundation
import Observation

@MainActor @Observable final class RootViewModel {
  private let backupFeature: BackupFeature
  private let settingsFeature: SettingsFeature
  private let authenticationFeature: AuthenticationFeature
  init(
    settingsFeature: SettingsFeature = AppModel.shared.settingsFeature,
    authenticationFeature: AuthenticationFeature = AppModel.shared.authenticationFeature,
    backupFeature: BackupFeature = AppModel.shared.backupFeature
  ) {
    self.backupFeature = backupFeature
    self.settingsFeature = settingsFeature
    self.authenticationFeature = authenticationFeature
  }
  var isRestoring: Bool { backupFeature.isRestoring }
  var requiresUnlock: Bool { authenticationFeature.requiresUnlock }
  var needsOnboarding: Bool { !settingsFeature.onboarded }
}
