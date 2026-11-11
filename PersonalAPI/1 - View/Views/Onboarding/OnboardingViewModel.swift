import Observation

@MainActor @Observable final class OnboardingViewModel {
  private let settingsFeature: SettingsFeature
  init(settingsFeature: SettingsFeature = AppModel.shared.settingsFeature) { self.settingsFeature = settingsFeature }
  func startDataset() { settingsFeature.completeOnboarding() }
}
