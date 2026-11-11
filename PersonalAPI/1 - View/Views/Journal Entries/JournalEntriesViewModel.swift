import Foundation
import Observation

@MainActor @Observable final class JournalEntriesViewModel {
  private let momentsFeature: MomentsFeature
  init(momentsFeature: MomentsFeature = AppModel.shared.momentsFeature) { self.momentsFeature = momentsFeature }
  var entries: [MomentSnapshot] { momentsFeature.moments }
  var isLoading: Bool { momentsFeature.isLoading }
  var error: String? { momentsFeature.loadError }
  private var refreshTask: Task<Void, Never>?
  func refresh() async { await momentsFeature.refresh() }
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
