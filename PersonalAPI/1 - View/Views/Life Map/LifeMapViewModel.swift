import Foundation
import Observation

@MainActor @Observable final class LifeMapViewModel {
  private let lifeMapFeature: LifeMapFeature
  init(lifeMapFeature: LifeMapFeature = AppModel.shared.lifeMapFeature) { self.lifeMapFeature = lifeMapFeature }
  var points: [LifeMapPoint] { lifeMapFeature.points }
  var entryCount: Int { lifeMapFeature.entryCount }
  var processedCount: Int { lifeMapFeature.processedCount }
  var attemptedCount: Int { lifeMapFeature.attemptedCount }
  var failedCount: Int { lifeMapFeature.failedCount }
  var isReading: Bool { lifeMapFeature.isReading }
  var issue: String? {
    let descriptions = Set(lifeMapFeature.failures.map(\.localizedDescription))
    return descriptions.isEmpty ? nil : descriptions.sorted().joined(separator: "\n\n")
  }
  private var refreshTask: Task<Void, Never>?
  func refresh() async { await lifeMapFeature.refresh() }
  @discardableResult
  func requestRefresh() -> Task<Void, Never> {
    if let refreshTask { return refreshTask }
    let task = Task { [self] in
      defer { refreshTask = nil }
      await refresh()
    }
    refreshTask = task
    return task
  }
}
