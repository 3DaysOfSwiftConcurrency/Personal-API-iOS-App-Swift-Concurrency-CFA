import Foundation
import Observation

@MainActor @Observable final class SettingsFeature {
  private(set) var onboarded = false
  private let preferences: any PreferencesRepository
  private let repository: any PersonalDataRepository
  private let momentsFeature: MomentsFeature
  private let profileFeature: ProfileFeature
  init(
    preferences: any PreferencesRepository, repository: any PersonalDataRepository,
    momentsFeature: MomentsFeature, profileFeature: ProfileFeature
  ) {
    self.preferences = preferences
    self.repository = repository
    self.momentsFeature = momentsFeature
    self.profileFeature = profileFeature
  }
  var momentCount: Int { momentsFeature.moments.count }
  var factCount: Int { profileFeature.facts.count }
  var enrichmentError: String? { momentsFeature.enrichmentError }
  func loadPreference() { onboarded = preferences.onboarded }
  func completeOnboarding() {
    preferences.onboarded = true
    onboarded = true
  }
  func exportDataset() async throws -> Data { try await repository.exportArchive() }
  func regenerateMetadata() async throws { try await momentsFeature.regenerateMetadata() }
}
