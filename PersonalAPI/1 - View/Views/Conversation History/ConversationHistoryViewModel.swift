import Foundation
import Observation

@MainActor @Observable final class ConversationHistoryViewModel {
  private let conversationsFeature: ConversationsFeature
  var pendingDeletion: UUID?
  private(set) var error: String?
  private var deleteTask: Task<Void, Never>?
  init(conversationsFeature: ConversationsFeature = AppModel.shared.conversationsFeature) {
    self.conversationsFeature = conversationsFeature
  }
  var conversations: [Conversation] { conversationsFeature.conversations }
  var isConversationOperationInProgress: Bool { conversationsFeature.isConversationOperationInProgress }
  func load() async {
    do {
      try await conversationsFeature.load()
      error = nil
    } catch { self.error = error.localizedDescription }
  }
  @discardableResult
  func deletePending() -> Task<Void, Never>? {
    guard let id = pendingDeletion else { return nil }
    if let deleteTask { return deleteTask }
    pendingDeletion = nil
    let task = Task { [self] in
      defer { deleteTask = nil }
      do {
        try await conversationsFeature.delete(id)
        error = nil
      } catch { self.error = error.localizedDescription }
    }
    deleteTask = task
    return task
  }
}
