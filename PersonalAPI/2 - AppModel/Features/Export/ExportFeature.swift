import Foundation
import Observation

/// Owns creation of the portable dataset exposed by the Export tab.
@MainActor @Observable final class ExportFeature {
  private let repository: any PersonalDataRepository
  private let momentsFeature: MomentsFeature
  private var exportTask: Task<Data, Error>?

  init(repository: any PersonalDataRepository, momentsFeature: MomentsFeature) {
    self.repository = repository
    self.momentsFeature = momentsFeature
  }

  var momentCount: Int { momentsFeature.moments.count }

  func exportDataset() async throws -> Data {
    if let exportTask { return try await exportTask.value }
    let task = Task { [repository] in try await repository.exportArchive() }
    exportTask = task
    defer { exportTask = nil }
    return try await task.value
  }
}
