import Foundation
import Observation

@MainActor @Observable final class ConversationsFeature {
  private(set) var conversations: [Conversation] = []
  /// A conversation accepts one mutation at a time. Queuing taps would replay stale user intent
  /// after a generated answer or destructive edit; the UI instead disables those actions.
  private(set) var isConversationOperationInProgress = false
  private(set) var activeTurnID: UUID?
  private var loaded = false
  private var loadTask: Task<Void, Error>?
  private var exportTask: Task<Data, Error>?
  private let repository: any ConversationRepository
  private let queryFeature: QueryFeature
  private let now: @Sendable () -> Date
  init(
    repository: any ConversationRepository, queryFeature: QueryFeature,
    now: @escaping @Sendable () -> Date
  ) {
    self.repository = repository
    self.queryFeature = queryFeature
    self.now = now
  }
  func canSend(_ question: String) -> Bool {
    !isConversationOperationInProgress && queryFeature.canSearch(question) && question.count <= 500
  }
  func load() async throws {
    if loaded { return }
    if let loadTask {
      try await loadTask.value
      return
    }
    let task = Task { [self] in
      defer { loadTask = nil }
      try await performLoad()
    }
    loadTask = task
    try await task.value
  }
  private func performLoad() async throws {
    guard !loaded else { return }
    guard !isConversationOperationInProgress else { throw ConversationError.operationInProgress }
    isConversationOperationInProgress = true
    defer { isConversationOperationInProgress = false }
    conversations = try await repository.load()
    loaded = true
  }
  func refresh() async throws {
    loaded = false
    guard !isConversationOperationInProgress else { throw ConversationError.operationInProgress }
    try await load()
  }
  private func commit(_ updated: [Conversation]) async throws {
    do {
      try await repository.save(updated, replacing: conversations)
      conversations = updated.sorted { $0.updatedAt > $1.updatedAt }
    } catch {
      // A conflict must reload before retrying; the old baseline is no longer valid.
      loaded = false
      throw error
    }
  }
  func send(_ question: String, in conversationID: UUID) async throws {
    try await load()
    guard canSend(question) else { throw QueryFailure.invalidQuestion }
    isConversationOperationInProgress = true
    defer {
      isConversationOperationInProgress = false
      activeTurnID = nil
    }
    try Task.checkCancellation()
    var updated = conversations
    if !updated.contains(where: { $0.id == conversationID }) {
      updated.append(
        Conversation(id: conversationID, createdAt: now(), updatedAt: now(), turns: []))
    }
    guard let index = updated.firstIndex(where: { $0.id == conversationID }) else {
      throw ConversationError.missing
    }
    let turn = ChatTurn(id: UUID(), question: question, createdAt: now())
    updated[index].turns.append(turn)
    updated[index].updatedAt = now()
    // Save the question before inference, so interruption never loses it.
    try await commit(updated)
    activeTurnID = turn.id
    try await generate(in: conversationID)
  }
  func answerAgain(in conversationID: UUID) async throws {
    try await load()
    guard !isConversationOperationInProgress else { throw ConversationError.operationInProgress }
    guard let turn = conversations.first(where: { $0.id == conversationID })?.turns.last else {
      throw ConversationError.missing
    }
    isConversationOperationInProgress = true
    activeTurnID = turn.id
    defer {
      isConversationOperationInProgress = false
      activeTurnID = nil
    }
    try await generate(in: conversationID)
  }
  private func generate(in id: UUID) async throws {
    guard let conversation = conversations.first(where: { $0.id == id }),
      let turn = conversation.turns.last
    else { throw ConversationError.missing }
    var result: QueryResult?
    var failure: String?
    do {
      result = try await queryFeature.search(
        turn.question, previousQuestions: conversation.turns.dropLast().map(\.question))
      try Task.checkCancellation()
      failure = nil
    } catch is CancellationError { throw CancellationError() } catch {
      result = nil
      failure = error.localizedDescription
    }
    try Task.checkCancellation()
    var updated = conversations
    guard let index = updated.firstIndex(where: { $0.id == id }),
      let last = updated[index].turns.indices.last
    else { throw ConversationError.missing }
    updated[index].turns[last].result = result
    updated[index].turns[last].failure = failure
    updated[index].turns[last].feedback = nil
    updated[index].updatedAt = now()
    try await commit(updated)
  }
  func delete(_ id: UUID) async throws {
    try await load()
    guard !isConversationOperationInProgress else { throw ConversationError.operationInProgress }
    isConversationOperationInProgress = true
    defer { isConversationOperationInProgress = false }
    try await commit(conversations.filter { $0.id != id })
  }
  func recordFeedback(
    _ rating: AnswerFeedback.Rating, explanation: String, turnID: UUID, conversationID: UUID
  ) async throws {
    try await load()
    guard !isConversationOperationInProgress else { throw ConversationError.operationInProgress }
    isConversationOperationInProgress = true
    defer { isConversationOperationInProgress = false }
    var updated = conversations
    guard let chat = updated.firstIndex(where: { $0.id == conversationID }),
      let turn = updated[chat].turns.firstIndex(where: { $0.id == turnID })
    else { throw ConversationError.missing }
    updated[chat].turns[turn].feedback = AnswerFeedback(
      rating: rating, explanation: String(explanation.prefix(2000)), recordedAt: now())
    try await commit(updated)
  }
  func export() async throws -> Data {
    if let exportTask { return try await exportTask.value }
    let task = Task { [self] in
      defer { exportTask = nil }
      try await load()
      return try await repository.export(conversations)
    }
    exportTask = task
    return try await task.value
  }
}
