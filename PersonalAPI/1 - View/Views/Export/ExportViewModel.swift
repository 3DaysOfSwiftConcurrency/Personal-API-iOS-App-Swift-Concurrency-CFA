import Foundation
import Observation

@MainActor @Observable final class ExportViewModel {
  var showsExporter = false
  private var exportTask: Task<Void, Never>?
  @discardableResult
  func requestExport() -> Task<Void, Never> {
    if let exportTask { return exportTask }
    let task = Task { [self] in
      defer { exportTask = nil }
      showsExporter = await prepareExport()
    }
    exportTask = task
    return task
  }
  private let exportFeature: ExportFeature
  private(set) var isExporting = false
  private(set) var filename = ExportDocument.datasetFilename()
  private(set) var document: ExportDocument?
  private(set) var message: String?
  init(exportFeature: ExportFeature = AppModel.shared.exportFeature) {
    self.exportFeature = exportFeature
  }
  var momentCount: Int { exportFeature.momentCount }
  func prepareExport() async -> Bool {
    guard !isExporting else { return false }
    isExporting = true
    defer { isExporting = false }
    do {
      filename = ExportDocument.datasetFilename()
      document = ExportDocument(data: try await exportFeature.exportDataset())
      message = nil
      return true
    } catch {
      document = nil
      message = "Couldn’t prepare your file. \(error.localizedDescription)"
      return false
    }
  }
  func exportFinished(_ result: Result<URL, Error>) {
    switch result {
    case .success:
      message =
        "Your personal dataset is saved. Keep adding Moments and export a fresh copy whenever you’re ready."
    case .failure(let error): message = "Couldn’t save your file. \(error.localizedDescription)"
    }
    document = nil
  }
}
