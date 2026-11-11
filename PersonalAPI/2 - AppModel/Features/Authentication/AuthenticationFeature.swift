import Foundation
import Observation

@MainActor @Observable final class AuthenticationFeature {
  private(set) var enabled = false
  private(set) var unlocked = false
  private(set) var authenticating = false
  private(set) var error: String?
  private let client: any DeviceAuthentication
  private let preferences: any PreferencesRepository
  private var generation = 0
  private var authenticationTask: Task<Bool, Never>?
  init(client: any DeviceAuthentication, preferences: any PreferencesRepository) {
    self.client = client
    self.preferences = preferences
  }
  func loadPreference() { enabled = preferences.lockEnabled }
  var requiresUnlock: Bool { enabled && !unlocked }
  func lockForBackground() {
    generation += 1
    client.cancel()
    unlocked = false
  }
  private func authenticate() async -> Bool {
    if let authenticationTask { return await authenticationTask.value }
    let task = Task { [self] in
      defer { authenticationTask = nil }
      return await performAuthentication()
    }
    authenticationTask = task
    return await task.value
  }
  private func performAuthentication() async -> Bool {
    authenticating = true
    let request = generation
    defer { authenticating = false }
    do {
      let success = try await client.authenticate()
      try Task.checkCancellation()
      guard generation == request else { return false }
      error = success ? nil : "Authentication was not completed."
      return success
    } catch is CancellationError {
      return false
    } catch {
      guard generation == request else { return false }
      self.error = error.localizedDescription
      return false
    }
  }
  func unlock() async {
    let success = await authenticate()
    guard !Task.isCancelled, success else { return }
    unlocked = true
  }
  func setEnabled(_ value: Bool) async {
    let success = await authenticate()
    guard !Task.isCancelled, success else { return }
    unlocked = true
    preferences.lockEnabled = value
    enabled = value
  }
}
