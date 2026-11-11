import Foundation
import Observation

@MainActor @Observable final class SettingsFeature {
  private(set) var onboarded = false
  private let preferences: any PreferencesRepository
  private let repository: any PersonalDataRepository
  private let momentsFeature: MomentsFeature
  private let profileFeature: ProfileFeature
  private var exportTask: Task<Data, Error>?
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
  var enrichmentFailure: MomentEnrichmentFailure? { momentsFeature.enrichmentFailure }
  func loadPreference() { onboarded = preferences.onboarded }
  func completeOnboarding() {
    preferences.onboarded = true
    onboarded = true
  }
  func exportDataset() async throws -> Data {
    if let exportTask { return try await exportTask.value }
    let task = Task { [repository] in try await repository.exportArchive() }
    exportTask = task
    defer { exportTask = nil }
    return try await task.value
  }
  func regenerateMetadata() async throws { try await momentsFeature.regenerateMetadata() }
}
