import Foundation
import Observation

/// Owns creation of the portable dataset exposed by the Export tab.
@MainActor @Observable final class ExportFeature {
  private let repository: any PersonalDataRepository
  private let momentsFeature: MomentsFeature

  init(repository: any PersonalDataRepository, momentsFeature: MomentsFeature) {
    self.repository = repository
    self.momentsFeature = momentsFeature
  }

  var momentCount: Int { momentsFeature.moments.count }

  func exportDataset() async throws -> Data {
    try await repository.exportArchive()
  }
}
