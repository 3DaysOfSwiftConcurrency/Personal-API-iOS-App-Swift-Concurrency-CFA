import Foundation
import Observation

@MainActor @Observable final class TrainingViewModel {
  var text = ""
  var isMomentFocused = false
  private(set) var dismissRequested = false
  func done() {
    if isMomentFocused { isMomentFocused = false } else { dismissRequested = true }
  }
  private(set) var error: String?
  private(set) var didSave = false
  private(set) var isSaving = false
  private var saveTask: Task<Void, Never>?
  private var retryTask: Task<Void, Never>?
  private let momentsFeature: MomentsFeature
  init(momentsFeature: MomentsFeature = AppModel.shared.momentsFeature) {
    self.momentsFeature = momentsFeature
  }
  var moments: [MomentSnapshot] { momentsFeature.moments }
  var canSave: Bool { !isSaving && momentsFeature.canRecord(text) }
  var loadError: String? { momentsFeature.loadError }
  var enrichmentError: String? { momentsFeature.enrichmentError }
  var isLoading: Bool { momentsFeature.isLoading }
  func load() async { await momentsFeature.loadIfRequired() }
  func retry() async { await momentsFeature.refresh() }
  func save() async {
    guard !isSaving else { return }
    didSave = false
    isSaving = true
    defer { isSaving = false }
    do {
      try await momentsFeature.recordMoment(text: text, happenedAt: nil)
      text = ""
      error = nil
      didSave = true
    } catch { self.error = "Your draft is still here. \(error.localizedDescription)" }
  }
  @discardableResult
  func requestSave() -> Task<Void, Never> {
    if let saveTask { return saveTask }
    let task = Task { [self] in
      defer { saveTask = nil }
      await save()
    }
    saveTask = task
    return task
  }
  @discardableResult
  func requestRetry() -> Task<Void, Never> {
    if let retryTask { return retryTask }
    let task = Task { [self] in
      defer { retryTask = nil }
      await retry()
    }
    retryTask = task
    return task
  }
}
