import Foundation
import Observation

@MainActor @Observable final class MomentsFeature {
  private(set) var moments: [MomentSnapshot] = []
  private(set) var isLoading = false
  private(set) var loadFailure: Error?
  private(set) var enrichmentFailure: MomentEnrichmentFailure?
  private var loaded = false
  private var refreshTask: Task<Void, Never>?
  private let repository: any PersonalDataRepository
  private let processor: any MomentProcessor
  private let factExtractor: any JournalFactExtracting
  private var indexedSources: [UUID: String] = [:]
  private let now: @Sendable () -> Date
  private var enrichmentTask: Task<Void, Never>?
  private var regenerationTask: Task<Void, Error>?
  private let operations = FIFOOperationGate()

  init(
    repository: any PersonalDataRepository, processor: any MomentProcessor,
    now: @escaping @Sendable () -> Date, factExtractor: (any JournalFactExtracting)? = nil
  ) {
    self.repository = repository
    self.processor = processor
    self.now = now
    self.factExtractor = factExtractor ?? LocalJournalFactExtractor(now: now)
  }
  // Serialise persistence AND publication across suspension, preventing stale refreshes.

  func sourceState(for snapshot: MomentSnapshot) -> MomentSourceState {
    guard loaded, loadFailure == nil else { return .unavailable }
    guard let current = moments.first(where: { $0.id == snapshot.id }) else { return .deleted }
    return current.text == snapshot.text ? .current : .edited
  }
  func currentMoment(_ fallback: MomentSnapshot) -> MomentSnapshot {
    moments.first(where: { $0.id == fallback.id && $0.text == fallback.text }) ?? fallback
  }
  func canRecord(_ text: String) -> Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  func loadIfRequired() async {
    guard !loaded else { return }
    await refresh()
  }
  func refresh() async {
    if let refreshTask {
      await refreshTask.value
      return
    }
    let task = Task { [self] in
      defer { refreshTask = nil }
      await performRefresh()
    }
    refreshTask = task
    await task.value
  }
  private func performRefresh() async {
    await operations.acquire()
    defer { operations.release() }
    // Cancellation before a read leaves previously published state intact.
    guard !Task.isCancelled else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      moments = try await repository.loadMoments()
      loaded = true
      loadFailure = nil
      requestEnrichment()
    } catch {
      loadFailure = error
    }
  }
  func reloadAfterRecovery() async throws {
    loaded = false
    await refresh()
    if let loadFailure { throw loadFailure }
  }
  func recordMoment(text: String, happenedAt: Date?) async throws {
    guard canRecord(text) else { throw MomentError.emptyMoment }
    await operations.acquire()
    defer { operations.release() }
    try Task.checkCancellation()
    let moment = MomentSnapshot(
      id: UUID(), text: text, createdAt: now(), happenedAt: happenedAt,
      source: "manual", analysisData: nil, processingState: "pending")
    try await repository.saveMoment(moment)
    // A committed source must publish even if cancellation arrived during the save.
    moments.insert(moment, at: 0)
    requestEnrichment()
  }
  func updateMoment(_ original: MomentSnapshot, text: String) async throws {
    guard canRecord(text) else { throw MomentError.emptyMoment }
    await operations.acquire()
    defer { operations.release() }
    try Task.checkCancellation()
    let updated = try await repository.updateMoment(original, text: text)
    if let index = moments.firstIndex(where: { $0.id == original.id }) { moments[index] = updated }
    indexedSources.removeValue(forKey: original.id)
    requestEnrichment()
  }
  func deleteMoment(_ original: MomentSnapshot) async throws {
    await operations.acquire()
    defer { operations.release() }
    try Task.checkCancellation()
    try await repository.deleteMoment(original)
    moments.removeAll { $0.id == original.id }
    indexedSources.removeValue(forKey: original.id)
  }
  private func requestEnrichment() {
    guard enrichmentTask == nil else { return }
    enrichmentTask = Task { [self] in
      defer { enrichmentTask = nil }
      await analysePendingSources()
    }
  }
  func enrichPendingMoments() async {
    requestEnrichment()
    await enrichmentTask?.value
  }
  private func analysePendingSources() async {
    var attempted: [UUID: String] = [:]
    enrichmentFailure = nil
    while let moment = moments.first(where: {
      ($0.processingState != "complete" || indexedSources[$0.id] != $0.text)
        && attempted[$0.id] != $0.text
    }) {
      attempted[moment.id] = moment.text
      if moment.processingState != "complete" {
        do {
          let result = try await processor.analyse(
            MomentInput(text: moment.text, createdAt: moment.createdAt))
          guard try await saveAnalysis(result, for: moment) else { continue }
        } catch {
          enrichmentFailure = .metadata(error)
        }
      }
      do {
        let facts = try await factExtractor.extract(from: moment)
        try await repository.replaceDerivedFacts(facts, source: moment)
        indexedSources[moment.id] = moment.text
      } catch {
        enrichmentFailure = .searchIndex(error)
      }
    }
  }
  /// Publication shares the write gate; inference runs outside it so editing stays responsive.
  private func saveAnalysis(_ result: MomentAnalysis, for source: MomentSnapshot) async throws
    -> Bool
  {
    await operations.acquire()
    defer { operations.release() }
    guard moments.contains(where: { $0.id == source.id && $0.text == source.text }) else {
      return false
    }
    let updated = try await repository.saveAnalysis(result, source: source)
    if let index = moments.firstIndex(where: { $0.id == source.id }) { moments[index] = updated }
    return true
  }

  private func markMetadataPending() async throws {
    await operations.acquire()
    defer { operations.release() }
    try Task.checkCancellation()
    moments = try await repository.markAnalysesPending()
    indexedSources.removeAll()
  }

  func regenerateMetadata() async throws {
    if let regenerationTask {
      try await regenerationTask.value
      return
    }
    let task = Task { [self] in
      defer { regenerationTask = nil }
      try await performMetadataRegeneration()
    }
    regenerationTask = task
    try await task.value
  }

  private func performMetadataRegeneration() async throws {
    // Finish the old pass before marking data pending, so it cannot erase this request.
    await enrichmentTask?.value
    try await markMetadataPending()
    await enrichPendingMoments()
  }
}

enum MomentEnrichmentFailure {
  case metadata(Error)
  case searchIndex(Error)
}
