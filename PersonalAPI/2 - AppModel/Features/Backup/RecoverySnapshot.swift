import Foundation

/// Recovery format, separate from the public dataset export.
struct RecoverySnapshot: Codable, Sendable {
  var format = "Personal API Recovery"
  var version = 1
  var appVersion =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
  var appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
  let createdAt: Date
  let moments: [MomentSnapshot]
  let facts: [PersonalFactSnapshot]
  let conversations: [Conversation]
  let colourThemeID: String?

  var isEmpty: Bool { moments.isEmpty && facts.isEmpty && conversations.isEmpty }

  func validate() throws {
    guard format == "Personal API Recovery", version == 1 else {
      throw BackupError.unsupportedFile
    }
    guard Set(moments.map(\.id)).count == moments.count,
      Set(facts.map(\.id)).count == facts.count,
      Set(conversations.map(\.id)).count == conversations.count,
      conversations.allSatisfy({ Set($0.turns.map(\.id)).count == $0.turns.count })
    else { throw BackupError.invalidFile }
    for fact in facts {
      if let source = fact.derivation {
        guard moments.contains(where: { $0.id == source.momentID && $0.text == source.sourceText })
        else { throw BackupError.invalidFile }
      }
    }
  }

  func encoded() throws -> Data {
    try validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  static func decode(_ data: Data) throws -> Self {
    let snapshot = try JSONDecoder().decode(Self.self, from: data)
    try snapshot.validate()
    return snapshot
  }

  func hasSameContent(as other: Self) throws -> Bool {
    let comparison = Self(
      createdAt: other.createdAt, moments: moments, facts: facts,
      conversations: conversations, colourThemeID: colourThemeID)
    return try comparison.encoded() == other.encoded()
  }
}

enum BackupError: LocalizedError {
  case unsupportedFile, invalidFile, restoreBlockedByConversationOperation, changedConversation, accountChanged
  var errorDescription: String? {
    switch self {
    case .unsupportedFile:
      return "Choose a Personal API recovery file supported by this app version."
    case .invalidFile:
      return "This recovery file contains inconsistent records. Nothing was restored."
    case .restoreBlockedByConversationOperation: return "Please wait for the current operation to finish."
    case .changedConversation:
      return "This chat changed on another device. Reopen it before trying again."
    case .accountChanged:
      return "The iCloud account changed. Local backups are safe; cloud copying is paused."
    }
  }
}
