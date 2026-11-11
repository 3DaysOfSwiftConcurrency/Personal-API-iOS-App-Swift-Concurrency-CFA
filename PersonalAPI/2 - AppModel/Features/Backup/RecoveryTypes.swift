import Foundation

struct RecoveryCopy: Identifiable, Sendable {
  let url: URL
  let name: String
  var id: URL { url }
}

/// Identifies the failed stage, including whether restoration already committed.
enum RecoveryFailureContext: Sendable {
  case createBackup, uploadBackup, listBackups, readFile
  case restore, restoreBlockedByConversationOperation, refreshAfterRestore, refreshAfterSync
}

enum RecoveryStatus: Sendable, Equatable {
  case noBackup, savedLocally, uploaded, uploadPending, cloudUnavailable, restored
}

enum CloudSyncStatus: Sendable, Equatable {
  case waiting, completed, needsAttention
}

enum CloudAccountStatus: Sendable, Equatable {
  case available, signedOut, restricted, unavailable, checkFailed
}
