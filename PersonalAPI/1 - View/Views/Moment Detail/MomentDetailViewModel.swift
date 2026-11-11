import Foundation
import Observation

@MainActor @Observable final class MomentDetailViewModel {
  private let momentsFeature: MomentsFeature
  init(momentsFeature: MomentsFeature = AppModel.shared.momentsFeature) { self.momentsFeature = momentsFeature }
  func load() async { await momentsFeature.loadIfRequired() }
  func sourceNotice(for snapshot: MomentSnapshot) -> String? {
    switch momentsFeature.sourceState(for: snapshot) {
    case .unavailable, .current: return nil
    case .edited:
      return "This entry has since been edited. These are the words saved with this source."
    case .deleted:
      return
        "This entry has been deleted from your dataset. This saved source is a historical copy."
    }
  }
  func current(_ snapshot: MomentSnapshot) -> MomentSnapshot {
    momentsFeature.currentMoment(snapshot)
  }
}
