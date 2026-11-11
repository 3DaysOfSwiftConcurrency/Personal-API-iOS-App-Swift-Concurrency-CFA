import Foundation
import Observation

@MainActor @Observable final class SettingsViewModel {
  var exporting = false
  private var exportTask: Task<Void, Never>?
  private var lockTask: Task<Void, Never>?
  private var regenerateTask: Task<Void, Never>?
  @discardableResult
  func requestExport() -> Task<Void, Never> {
    if let exportTask { return exportTask }
    let task = Task { [self] in
      defer { exportTask = nil }
      exporting = await prepareExport()
    }
    exportTask = task
    return task
  }
  private let settingsFeature: SettingsFeature
  private let authenticationFeature: AuthenticationFeature
  private(set) var isWorking = false
  private(set) var message: String?
  private(set) var filename = ExportDocument.datasetFilename()
  private(set) var document: ExportDocument?
  init(
    settingsFeature: SettingsFeature = AppModel.shared.settingsFeature,
    authenticationFeature: AuthenticationFeature = AppModel.shared.authenticationFeature
  ) {
    self.settingsFeature = settingsFeature
    self.authenticationFeature = authenticationFeature
  }
  var lockEnabled: Bool { authenticationFeature.enabled }
  var authenticating: Bool { authenticationFeature.authenticating }
  var authenticationError: String? {
    guard let failure = authenticationFeature.failure else { return nil }
    switch failure {
    case .rejected: return "Authentication was not completed."
    case .provider(let error): return error.localizedDescription
    }
  }
  var enrichmentError: String? {
    guard let failure = settingsFeature.enrichmentFailure else { return nil }
    switch failure {
    case .metadata(let error):
      return "Your original text is saved. Metadata needs a retry: \(error.localizedDescription)"
    case .searchIndex(let error):
      return "Your original text is saved. Search indexing needs a retry: \(error.localizedDescription)"
    }
  }
  var momentCount: Int { settingsFeature.momentCount }
  var factCount: Int { settingsFeature.factCount }
  @discardableResult
  func requestLockEnabled(_ value: Bool) -> Task<Void, Never> {
    if let lockTask { return lockTask }
    let task = Task { [self] in
      defer { lockTask = nil }
      await setLockEnabled(value)
    }
    lockTask = task
    return task
  }
  func setLockEnabled(_ enabled: Bool) async { await authenticationFeature.setEnabled(enabled) }
  func prepareExport() async -> Bool {
    guard !isWorking else { return false }
    isWorking = true
    defer { isWorking = false }
    do {
      filename = ExportDocument.datasetFilename()
      document = ExportDocument(data: try await settingsFeature.exportDataset())
      message = nil
      return true
    } catch {
      document = nil
      message = error.localizedDescription
      return false
    }
  }
  func exportFinished(_ result: Result<URL, Error>) {
    switch result {
    case .success: message = "Export saved."
    case .failure(let error): message = "Export failed: \(error.localizedDescription)"
    }
    document = nil
  }
  func regenerate() async {
    guard !isWorking else { return }
    isWorking = true
    defer { isWorking = false }
    do {
      try await settingsFeature.regenerateMetadata()
      message = enrichmentError ?? "Derived metadata regenerated."
    } catch { message = error.localizedDescription }
  }
  @discardableResult
  func requestRegenerate() -> Task<Void, Never> {
    if let regenerateTask { return regenerateTask }
    let task = Task { [self] in
      defer { regenerateTask = nil }
      await regenerate()
    }
    regenerateTask = task
    return task
  }
}
