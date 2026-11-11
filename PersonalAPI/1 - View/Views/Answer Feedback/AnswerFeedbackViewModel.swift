import Foundation
import Observation

@MainActor @Observable final class AnswerFeedbackViewModel {
  private let conversationsFeature: ConversationsFeature
  var reason: AnswerFeedback.Rating = .inventedDetail
  var explanation = ""
  private(set) var error: String?
  private(set) var saved = false
  private(set) var isSaving = false
  private var saveTask: Task<Void, Never>?
  init(conversationsFeature: ConversationsFeature = AppModel.shared.conversationsFeature) {
    self.conversationsFeature = conversationsFeature
  }
  @discardableResult
  func submit(conversationID: UUID, turnID: UUID) -> Task<Void, Never> {
    if let saveTask { return saveTask }
    let task = Task { [self] in
      defer { saveTask = nil }
      await save(conversationID: conversationID, turnID: turnID)
    }
    saveTask = task
    return task
  }
  func save(conversationID: UUID, turnID: UUID) async {
    isSaving = true
    defer { isSaving = false }
    do {
      try await conversationsFeature.recordFeedback(
        reason, explanation: explanation, turnID: turnID, conversationID: conversationID)
      error = nil
      saved = true
    } catch { self.error = error.localizedDescription }
  }
}
