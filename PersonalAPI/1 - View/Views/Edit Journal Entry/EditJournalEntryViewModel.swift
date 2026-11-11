import Foundation
import Observation

@MainActor @Observable final class EditJournalEntryViewModel {
  var editing = false
  var confirmingDelete = false
  var confirmingDiscard = false
  private(set) var finished = false
  private var commandTask: Task<Void, Never>?
  func cancel() { if hasChanges { confirmingDiscard = true } else { finished = true } }
  func discard() { finished = true }
  @discardableResult
  func requestSave() -> Task<Void, Never> {
    if let commandTask { return commandTask }
    editing = false
    let task = Task { [self] in
      defer { commandTask = nil }
      finished = await save()
    }
    commandTask = task
    return task
  }
  @discardableResult
  func requestDelete() -> Task<Void, Never> {
    if let commandTask { return commandTask }
    editing = false
    let task = Task { [self] in
      defer { commandTask = nil }
      finished = await delete()
    }
    commandTask = task
    return task
  }
  private let momentsFeature: MomentsFeature
  private var original: MomentSnapshot?
  var text = ""
  private(set) var isWorking = false
  private(set) var error: String?
  init(momentsFeature: MomentsFeature = AppModel.shared.momentsFeature) { self.momentsFeature = momentsFeature }
  var hasChanges: Bool { original.map { $0.text != text } ?? false }
  var canSave: Bool { !isWorking && hasChanges && momentsFeature.canRecord(text) }
  func prepare(_ entry: MomentSnapshot) {
    guard original == nil else { return }
    original = entry
    text = entry.text
  }
  func save() async -> Bool {
    guard canSave, let original else { return false }
    isWorking = true
    defer { isWorking = false }
    do {
      try await momentsFeature.updateMoment(original, text: text)
      error = nil
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  func delete() async -> Bool {
    guard !isWorking, let original else { return false }
    isWorking = true
    defer { isWorking = false }
    do {
      try await momentsFeature.deleteMoment(original)
      error = nil
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
}
