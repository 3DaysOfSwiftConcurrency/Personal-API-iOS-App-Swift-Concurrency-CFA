import Foundation
import Observation

@MainActor @Observable final class QueryViewModel {
  var question = ""
  var isQuestionFocused = false
  var showsMemoryEntry = false
  var showsHistory = false
  var historySelection: UUID?
  var feedbackTurn: ChatTurn?
  var showsExport = false
  private(set) var exportDocument = ExportDocument(data: Data())
  private(set) var submittedTurnCount: Int?
  private(set) var submittedText = ""
  var rowCount: Int {
    turns.count + ((!isBusy || submittedTurnCount == turns.count) ? 1 : 0)
  }
  @discardableResult
  func submitQuestion() -> Task<Void, Never>? {
    guard canSearch else { return nil }
    submittedText = question
    submittedTurnCount = turns.count
    isQuestionFocused = false
    return submitSearch()
  }
  func showMomentEntry() {
    isQuestionFocused = false
    showsMemoryEntry = true
  }
  func showFeedback(_ turn: ChatTurn) { feedbackTurn = turn }
  func openSelectedHistory() {
    guard let historySelection else { return }
    open(historySelection)
    self.historySelection = nil
  }
  @discardableResult
  func markUseful(_ id: UUID) -> Task<Void, Never> {
    if let task = feedbackTasks[id] { return task }
    let task = Task { [self] in
      defer { feedbackTasks[id] = nil }
      _ = await feedback(.useful, explanation: "", turnID: id)
    }
    feedbackTasks[id] = task
    return task
  }
  @discardableResult
  func retryLoading() -> Task<Void, Never> {
    if let loadTask { return loadTask }
    let task = Task { [self] in
      defer { loadTask = nil }
      await load()
    }
    loadTask = task
    return task
  }
  @discardableResult
  func requestExport() -> Task<Void, Never> {
    if let exportTask { return exportTask }
    let task = Task { [self] in
      defer { exportTask = nil }
      if let data = await exportChats() {
        exportDocument = ExportDocument(data: data)
        showsExport = true
      }
    }
    exportTask = task
    return task
  }
  func exportFinished(_ result: Result<URL, Error>) {
    if case .failure(let error) = result { exportFailed(error) }
  }
  func disappeared() {
    isQuestionFocused = false
    cancelSearch()
  }

  private(set) var conversationID = UUID()
  private(set) var error: String?
  private(set) var isSubmitting = false
  private(set) var loaded = false
  private let conversationsFeature: ConversationsFeature
  private var searchTask: Task<Void, Never>?
  private var loadTask: Task<Void, Never>?
  private var exportTask: Task<Void, Never>?
  private var feedbackTasks: [UUID: Task<Void, Never>] = [:]
  init(conversationsFeature: ConversationsFeature = AppModel.shared.conversationsFeature) {
    self.conversationsFeature = conversationsFeature
  }
  var conversations: [Conversation] { conversationsFeature.conversations }
  var turns: [ChatTurn] { conversations.first { $0.id == conversationID }?.turns ?? [] }
  var isBusy: Bool { isSubmitting || conversationsFeature.isBusy }
  var activeTurnID: UUID? { conversationsFeature.activeTurnID }
  var canSearch: Bool { !isSubmitting && conversationsFeature.canSend(question) }
  func load() async {
    do {
      try await conversationsFeature.load()
      // Load history without selecting it; each launch starts with a fresh draft.
      loaded = true
      error = nil
    } catch { self.error = error.localizedDescription }
  }
  @discardableResult
  func submitSearch() -> Task<Void, Never>? {
    if let searchTask { return searchTask }
    guard canSearch else { return nil }
    isSubmitting = true
    let task = Task { [self] in
      defer { searchTask = nil }
      await sendDraft()
    }
    searchTask = task
    return task
  }
  func sendDraft() async {
    let draft = question
    let id = conversationID
    let originalCount = turns.count
    question = ""
    isSubmitting = true
    defer {
      isSubmitting = false
      submittedTurnCount = nil
      submittedText = ""
    }
    error = nil
    do {
      try await conversationsFeature.send(draft, in: id)
    } catch is CancellationError {} catch { self.error = error.localizedDescription }
    if turns.count == originalCount && question.isEmpty { question = draft }
  }
  @discardableResult
  func answerAgain() -> Task<Void, Never>? {
    if let searchTask { return searchTask }
    guard !isBusy else { return nil }
    isSubmitting = true
    let task = Task { [self] in
      defer { searchTask = nil }
      defer {
        isSubmitting = false
        submittedTurnCount = nil
        submittedText = ""
      }
      do {
        error = nil
        try await conversationsFeature.answerAgain(in: conversationID)
      } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    searchTask = task
    return task
  }
  func cancelSearch() { searchTask?.cancel() }
  func newChat() {
    guard !isBusy else { return }
    conversationID = UUID()
    question = ""
    error = nil
  }
  func open(_ id: UUID) {
    guard !isBusy else { return }
    conversationID = id
    question = ""
    error = nil
  }
  @discardableResult
  func feedback(_ rating: AnswerFeedback.Rating, explanation: String, turnID: UUID) async -> Bool {
    do {
      try await conversationsFeature.recordFeedback(
        rating, explanation: explanation, turnID: turnID, conversationID: conversationID)
      error = nil
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  func exportFailed(_ failure: Error) { error = failure.localizedDescription }
  func exportChats() async -> Data? {
    do { return try await conversationsFeature.export() } catch {
      self.error = error.localizedDescription
      return nil
    }
  }
  func failureDetails(for turn: ChatTurn) -> String? {
    switch turn.result?.failureStage {
    case .retrieval:
      return
        "AI search stopped before an answer could be generated. Any sources shown were found by keyword search."
    case .answerGeneration:
      return "AI search found relevant passages, but the model stopped while generating the answer."
    case nil: return nil
    }
  }
  func answer(for turn: ChatTurn) -> String {
    if let failure = turn.failure { return failure }
    guard let result = turn.result else {
      return "This answer was interrupted. Tap Answer again to continue."
    }
    if let answer = result.generatedAnswer { return answer.text }
    if let issue = result.answerIssue { return issue }
    switch result.method {
    case .keywords(let reason):
      return reason ?? "On-device answering is unavailable for this question."
    case .onDeviceAI:
      return "I don’t have enough information in your recorded moments to answer that yet."
    }
  }
}
