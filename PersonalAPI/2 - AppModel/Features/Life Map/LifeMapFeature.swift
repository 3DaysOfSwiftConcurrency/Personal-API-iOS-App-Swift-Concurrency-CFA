import Foundation
import Observation

@MainActor @Observable final class LifeMapFeature {
  private(set) var points: [LifeMapPoint] = []
  private(set) var entryCount = 0
  private(set) var processedCount = 0
  private(set) var attemptedCount = 0
  private(set) var failedCount = 0
  private(set) var isReading = false
  private(set) var issue: String?
  private let repository: any PersonalDataRepository
  private let extractor: any LifeMapExtracting
  private var refreshTask: Task<Void, Never>?
  // Disposable derived state. No schema changes or writes to the journal.
  private var cache: [UUID: (text: String, candidates: [LifeMapCandidate])] = [:]
  init(repository: any PersonalDataRepository, extractor: any LifeMapExtracting) {
    self.repository = repository
    self.extractor = extractor
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
    isReading = true
    defer { isReading = false }
    issue = nil
    failedCount = 0
    attemptedCount = 0
    var failures = Set<String>()
    do {
      let entries = try await repository.loadMoments()
      entryCount = entries.count
      cache = cache.filter { id, value in entries.contains { $0.id == id && $0.text == value.text }
      }
      publish(entries)
      attemptedCount = processedCount
      for entry in entries where cache[entry.id] == nil {
        try Task.checkCancellation()
        defer { attemptedCount += 1 }
        do {
          let candidates = try await extractor.extract(entry.text)
          try Task.checkCancellation()
          guard
            candidates.allSatisfy({
              !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.passage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && entry.text.contains($0.passage)
            })
          else { throw LifeMapError.invalidEvidence }
          // Recheck the source after inference; never publish stale excerpts.
          let current = try await repository.loadMoments()
          guard current.contains(where: { $0.id == entry.id && $0.text == entry.text }) else {
            continue
          }
          var seen = Set<String>()
          cache[entry.id] = (entry.text, candidates.filter { seen.insert($0.passage).inserted })
          publish(current)
        } catch is CancellationError { throw CancellationError() } catch {
          failedCount += 1
          failures.insert(error.localizedDescription)
          issue = failures.sorted().joined(separator: "\n\n")
        }
      }
      let current = try await repository.loadMoments()
      publish(current)
    } catch is CancellationError {} catch { issue = error.localizedDescription }
  }
  private func publish(_ entries: [MomentSnapshot]) {
    entryCount = entries.count
    processedCount = entries.filter { cache[$0.id]?.text == $0.text }.count
    points = entries.flatMap { source -> [LifeMapPoint] in
      guard let cached = cache[source.id], cached.text == source.text else { return [] }
      return cached.candidates.enumerated().map { index, candidate in
        LifeMapPoint(
          id: "\(source.id)-\(index)", title: candidate.title, passage: candidate.passage,
          source: source)
      }
    }
  }
}
