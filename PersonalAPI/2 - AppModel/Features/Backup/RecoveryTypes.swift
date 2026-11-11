import Foundation

struct RecoveryCopy: Identifiable, Sendable {
  let url: URL
  let name: String
  var id: URL { url }
}

/// Identifies the failed stage, including whether restoration already committed.
enum RecoveryFailureContext: Sendable {
  case createBackup, uploadBackup, listBackups, readFile
  case restore, restoreBusy, refreshAfterRestore, refreshAfterSync
}
