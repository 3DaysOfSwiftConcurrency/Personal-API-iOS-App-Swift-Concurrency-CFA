import Foundation

actor QueryWorker: QuerySearching {
  private let index: LocalQueryIndex
  private let repository: any PersonalDataRepository
  private let answerer: (any MomentAnswering)?
  private let retriever: MomentRetriever
  private let semanticSearch: (any SemanticMomentSearching)?
  init(
    repository: any PersonalDataRepository, retriever: MomentRetriever, index: LocalQueryIndex,
    semanticSearch: (any SemanticMomentSearching)? = nil, answerer: (any MomentAnswering)? = nil
  ) {
    self.index = index
    self.repository = repository
    self.retriever = retriever
    self.semanticSearch = semanticSearch
    self.answerer = answerer
  }
  func canSearch(_ question: String) -> Bool {
    !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  func search(_ question: String) async throws -> QueryResult {
    try await search(question, previousQuestions: [])
  }
  func search(_ question: String, previousQuestions: [String]) async throws -> QueryResult {
    try Task.checkCancellation()
    guard canSearch(question), question.count <= 500 else { throw QueryFailure.invalidQuestion }
    let moments = try await repository.loadMoments()
    let facts = try await repository.loadFacts()
    let selection = try await index.select(
      question: question, previousQuestions: previousQuestions, moments: moments, facts: facts)
    let context = selection.previousQuestions.map { String($0.prefix(500)) }
    let contextualQuestion: String
    if context.isEmpty {
      contextualQuestion = question
    } else {
      let data = try JSONEncoder().encode([
        "currentQuestion": [question], "previousQuestions": context,
      ])
      contextualQuestion = String(decoding: data, as: UTF8.self)
    }
    if let semanticSearch {
      guard !selection.candidates.isEmpty else {
        return QueryResult(
          evidence: [], searchedCount: moments.count, needsMoreMemories: true,
          answerIssue:
            "I couldn’t find relevant passages in your recorded moments. Try naming the person, place or topic, or log a moment about it.",
          candidatePassageCount: 0)
      }
      do {
        let passages = try await semanticSearch.selectPassages(
          question: contextualQuestion, moments: selection.candidates)
        try Task.checkCancellation()
        // Only repository-owned source records can become evidence. Model output is not source data.
        let selected = Set(passages.map(\.momentID))
        guard
          passages.allSatisfy({ passage in
            !passage.text.isEmpty
              && selection.candidates.contains {
                $0.id == passage.momentID && $0.text.contains(passage.text)
              }
          })
        else { throw QueryFailure.invalidSelection }
        let matches = moments.filter { selected.contains($0.id) }.sorted {
          $0.createdAt > $1.createdAt
        }
        var result = QueryResult(
          evidence: Array(matches.prefix(20)).map { moment in
            Evidence(
              moment: moment, score: 1,
              passages: passages.filter { $0.momentID == moment.id }.map(\.text))
          },
          searchedCount: moments.count, method: .onDeviceAI,
          candidatePassageCount: selection.candidates.count)
        result.needsMoreMemories = matches.isEmpty
        return try await addAnswer(to: result, question: contextualQuestion)
      } catch is CancellationError { throw CancellationError() } catch {
        try Task.checkCancellation()
        var fallback = try await retriever.search(question, moments: moments)
        fallback.method = .keywords(reason: answerFailureMessage(error))
        fallback.failureStage = .retrieval
        fallback.candidatePassageCount = selection.candidates.count
        return fallback
      }
    }
    return try await retriever.search(question, moments: moments)
  }

  private func addAnswer(to result: QueryResult, question: String) async throws -> QueryResult {
    guard let answerer, !result.evidence.isEmpty else { return result }
    var result = result
    do {
      guard let answer = try await answerer.answer(question: question, evidence: result.evidence)
      else {
        result.needsMoreMemories = true
        result.answerIssue =
          "I don’t have enough information in your recorded moments to answer that yet."
        return result
      }
      try Task.checkCancellation()
      // Validate provenance, not semantic truth: the user can inspect each exact supporting quote.
      guard !answer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        answer.citations.allSatisfy({ citation in
          !citation.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && result.evidence.contains {
              $0.id == citation.momentID && $0.moment.text.contains(citation.quote)
            }
        })
      else { throw QueryFailure.invalidSelection }
      result.generatedAnswer = answer
    } catch is CancellationError { throw CancellationError() } catch {
      try Task.checkCancellation()
      result.answerIssue = answerFailureMessage(error)
      result.failureStage = .answerGeneration
    }
    return result
  }
}
