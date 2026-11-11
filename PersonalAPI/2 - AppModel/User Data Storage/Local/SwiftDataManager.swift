import Foundation
import SwiftData

/// Owns lazy creation and the single shared SwiftData store used by the application.
actor SwiftDataManager: PersonalDataRepository, ConversationRepository, RecoveryRepository {
  private let storeURL: URL?
  private let cloudEnabled: Bool
  private var repository: SwiftDataRepository?
  private var changeContinuations: [AsyncStream<Void>.Continuation] = []

  init(storeURL: URL? = nil, cloudEnabled: Bool = false) {
    self.storeURL = storeURL
    self.cloudEnabled = cloudEnabled
  }

  func changes() -> AsyncStream<Void> {
    let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    changeContinuations.append(continuation)
    return stream
  }

  private func database() throws -> SwiftDataRepository {
    if let repository { return repository }

    let schema = Schema([Moment.self, PersonalFact.self, StoredConversation.self])
    let configuration: ModelConfiguration
    if let storeURL {
      configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
    } else {
      configuration = ModelConfiguration(
        schema: schema,
        cloudKitDatabase: cloudEnabled
          ? .private("iCloud.com.3DaysOfSwiftConcurrency.PersonalAPI.SwiftData") : .none)
    }
    try FileManager.default.createDirectory(
      at: configuration.url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let repository = SwiftDataRepository(modelContainer: container)
    self.repository = repository
    return repository
  }

  private func reportChange() {
    changeContinuations.removeAll { continuation in
      if case .terminated = continuation.yield(()) { return true }
      return false
    }
  }

  func loadMoments() async throws -> [MomentSnapshot] {
    try await database().loadMoments()
  }

  func saveMoment(_ moment: MomentSnapshot) async throws {
    try await database().saveMoment(moment)
    reportChange()
  }

  func updateMoment(_ original: MomentSnapshot, text: String) async throws -> MomentSnapshot {
    let updated = try await database().updateMoment(original, text: text)
    reportChange()
    return updated
  }

  func deleteMoment(_ original: MomentSnapshot) async throws {
    try await database().deleteMoment(original)
    reportChange()
  }

  func saveAnalysis(_ analysis: MomentAnalysis, momentID: UUID) async throws -> MomentSnapshot {
    let updated = try await database().saveAnalysis(analysis, momentID: momentID)
    reportChange()
    return updated
  }

  func saveAnalysis(_ analysis: MomentAnalysis, source: MomentSnapshot) async throws
    -> MomentSnapshot
  {
    let updated = try await database().saveAnalysis(analysis, source: source)
    reportChange()
    return updated
  }

  func markAnalysesPending() async throws -> [MomentSnapshot] {
    let updated = try await database().markAnalysesPending()
    reportChange()
    return updated
  }

  func loadFacts() async throws -> [PersonalFactSnapshot] {
    try await database().loadFacts()
  }

  func saveFact(_ fact: PersonalFactSnapshot) async throws {
    try await database().saveFact(fact)
    reportChange()
  }

  func replaceDerivedFacts(_ facts: [PersonalFactSnapshot], source: MomentSnapshot) async throws {
    try await database().replaceDerivedFacts(facts, source: source)
    reportChange()
  }

  func exportArchive() async throws -> Data {
    try await database().exportArchive()
  }

  func load() async throws -> [Conversation] {
    try await database().load()
  }

  func save(_ conversations: [Conversation]) async throws {
    try await database().save(conversations)
    reportChange()
  }

  func save(_ conversations: [Conversation], replacing original: [Conversation]) async throws {
    try await database().save(conversations, replacing: original)
    reportChange()
  }

  func export(_ conversations: [Conversation]) async throws -> Data {
    try await database().export(conversations)
  }

  func recoverySnapshot(at date: Date, themeID: String?) async throws -> RecoverySnapshot {
    try await database().recoverySnapshot(at: date, themeID: themeID)
  }

  func restore(
    _ snapshot: RecoverySnapshot, safetyFolder: URL, at date: Date,
    previousThemeID: String? = nil
  ) async throws {
    try await database().restore(
      snapshot, safetyFolder: safetyFolder, at: date, previousThemeID: previousThemeID)
    reportChange()
  }
}
