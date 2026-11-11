import Foundation

/// File I/O runs on this actor. It never opens or changes the live database.
actor RecoveryBackupFiles: RecoveryFiles {
  private let folder: URL
  nonisolated let safetyFolder: URL
  private let cloudFolder: @Sendable () -> URL?
  private let access: any BackupFileAccess
  private let automaticInterval: TimeInterval
  private let weeklyInterval: TimeInterval

  init(
    folder: URL, automaticInterval: TimeInterval = 86400,
    weeklyInterval: TimeInterval = 7 * 86400,
    access: any BackupFileAccess = CoordinatedBackupFileAccess(),
    cloudFolder: @escaping @Sendable () -> URL? = {
      FileManager.default.url(
        forUbiquityContainerIdentifier: "iCloud.com.3DaysOfSwiftConcurrency.PersonalAPI")?
        .appendingPathComponent("Documents")
    }
  ) {
    self.folder = folder
    safetyFolder = folder.appendingPathComponent("Before-restore")
    self.automaticInterval = automaticInterval
    self.weeklyInterval = weeklyInterval
    self.access = access
    self.cloudFolder = cloudFolder
  }

  func prepare(_ snapshot: RecoverySnapshot, force: Bool) throws -> RecoverySnapshot? {
    try snapshot.validate()
    let latest = folder.appendingPathComponent("Latest.json")
    let existing =
      FileManager.default.fileExists(atPath: latest.path)
      ? try RecoverySnapshot.decode(Data(contentsOf: latest)) : nil
    // A new empty installation must not create misleading recovery history.
    guard !snapshot.isEmpty || existing != nil else { return nil }
    if !force, let existing,
      snapshot.createdAt.timeIntervalSince(existing.createdAt) < automaticInterval
    {
      return existing
    }
    let weekly = folder.appendingPathComponent("Weekly")
    try FileManager.default.createDirectory(at: weekly, withIntermediateDirectories: true)
    let retained = try FileManager.default.contentsOfDirectory(
      at: weekly, includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "json" }
    let lastWeekly = try retained.map {
      try RecoverySnapshot.decode(Data(contentsOf: $0)).createdAt
    }.max()
    let bytes = try snapshot.encoded()
    if lastWeekly.map({ snapshot.createdAt.timeIntervalSince($0) >= weeklyInterval }) ?? true {
      try bytes.write(
        to: weekly.appendingPathComponent("\(UUID().uuidString).json"), options: .atomic)
    }
    if let existing {
      if try snapshot.hasSameContent(as: existing) { return existing }
      try existing.encoded().write(
        to: folder.appendingPathComponent("Previous.json"), options: .atomic)
    }
    try bytes.write(to: latest, options: .atomic)
    return snapshot
  }

  /// nil means unavailable, false means copied but not yet confirmed uploaded.
  func upload() throws -> Bool? {
    guard let cloud = cloudFolder() else { return nil }
    if let token = FileManager.default.ubiquityIdentityToken {
      try BackupCloudAccount.verify(token, in: folder)
    }
    let identityFile = folder.appendingPathComponent("Installation.txt")
    let identity: String
    if FileManager.default.fileExists(atPath: identityFile.path) {
      identity = try String(contentsOf: identityFile, encoding: .utf8)
      guard UUID(uuidString: identity) != nil else { throw BackupError.invalidFile }
    } else {
      identity = UUID().uuidString
      try Data(identity.utf8).write(to: identityFile, options: .atomic)
    }
    let destination = cloud.appendingPathComponent("Backups/\(identity)")
    try FileManager.default.createDirectory(
      at: destination.appendingPathComponent("Weekly"),
      withIntermediateDirectories: true)
    let weekly = folder.appendingPathComponent("Weekly")
    var sources = try FileManager.default.contentsOfDirectory(
      at: weekly, includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "json" }
    sources += [
      folder.appendingPathComponent("Previous.json"), folder.appendingPathComponent("Latest.json"),
    ]
    .filter { FileManager.default.fileExists(atPath: $0.path) }
    var uploaded = true
    for source in sources {
      let data = try Data(contentsOf: source)
      _ = try RecoverySnapshot.decode(data)
      let isWeekly =
        source.deletingLastPathComponent().standardizedFileURL.path
        == weekly.standardizedFileURL.path
      let target = destination.appendingPathComponent(
        isWeekly ? "Weekly/\(source.lastPathComponent)" : source.lastPathComponent)
      if isWeekly {
        try access.writeNewSnapshot(data, to: target)
      } else {
        try access.replaceSnapshot(data, at: target)
      }
      if try target.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey]).ubiquitousItemIsUploaded
        != true
      {
        uploaded = false
      }
    }
    return uploaded
  }

  func localCopies() throws -> [RecoveryCopy] {
    guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
    var copies: [RecoveryCopy] = []
    for name in ["Latest.json", "Previous.json"] {
      let url = folder.appendingPathComponent(name)
      if FileManager.default.fileExists(atPath: url.path) {
        copies.append(RecoveryCopy(url: url, name: name))
      }
    }
    for directory in ["Before-restore", "Weekly"] {
      let path = folder.appendingPathComponent(directory)
      guard FileManager.default.fileExists(atPath: path.path) else { continue }
      let urls = try FileManager.default.contentsOfDirectory(
        at: path, includingPropertiesForKeys: [.creationDateKey]
      )
      .filter { $0.pathExtension == "json" }
      for url in urls {
        let snapshot = try RecoverySnapshot.decode(Data(contentsOf: url))
        copies.append(
          RecoveryCopy(url: url, name: "\(directory) · \(snapshot.createdAt.formatted())"))
      }
    }
    return copies
  }

  func preview(_ url: URL) throws -> RecoverySnapshot {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    if try url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem == true {
      try FileManager.default.startDownloadingUbiquitousItem(at: url)
    }
    return try RecoverySnapshot.decode(access.read(url))
  }
}

/// Never silently send retained recovery files to a different iCloud account.
/// Signing back into the original account allows retries without losing files.
enum BackupCloudAccount {
  static func verify(_ token: any NSObjectProtocol & NSCoding, in folder: URL) throws {
    let file = folder.appending(path: "CloudAccount.archive")
    if FileManager.default.fileExists(atPath: file.path) {
      let reader = try NSKeyedUnarchiver(forReadingFrom: Data(contentsOf: file))
      reader.requiresSecureCoding = false
      defer { reader.finishDecoding() }
      guard let previous = reader.decodeObject(forKey: NSKeyedArchiveRootObjectKey),
        token.isEqual(previous)
      else {
        throw BackupError.accountChanged
      }
    } else {
      let data = try NSKeyedArchiver.archivedData(
        withRootObject: token, requiringSecureCoding: false)
      try data.write(to: file, options: .atomic)
    }
  }
}

protocol BackupFileAccess: Sendable {
  func writeNewSnapshot(_ data: Data, to target: URL) throws
  func replaceSnapshot(_ data: Data, at target: URL) throws
  func read(_ url: URL) throws -> Data
}

/// The operating-system boundary, replaceable by a local file double in unit tests.
struct CoordinatedBackupFileAccess: BackupFileAccess {
  func replaceSnapshot(_ data: Data, at target: URL) throws {
    var coordinationError: NSError?
    var writeError: Error?
    NSFileCoordinator().coordinate(
      writingItemAt: target, options: .forReplacing, error: &coordinationError
    ) { url in
      do {
        if FileManager.default.fileExists(atPath: url.path), try Data(contentsOf: url) == data {
          return
        }
        try data.write(to: url, options: .atomic)
      } catch { writeError = error }
    }
    if let error = coordinationError ?? writeError as NSError? { throw error }
  }
  func writeNewSnapshot(_ data: Data, to target: URL) throws {
    var coordinationError: NSError?
    var writeError: Error?
    NSFileCoordinator().coordinate(
      writingItemAt: target, options: .forReplacing, error: &coordinationError
    ) { url in
      do {
        // Immutable, unique snapshots: a fresh installation never overwrites a previous backup.
        if FileManager.default.fileExists(atPath: url.path) {
          guard try Data(contentsOf: url) == data else {
            throw BackupError.invalidFile
          }
        } else {
          try data.write(to: url, options: .atomic)
        }
      } catch { writeError = error }
    }
    if let error = coordinationError ?? writeError as NSError? { throw error }

  }
  func read(_ url: URL) throws -> Data {
    var data: Data?
    var coordinationError: NSError?
    var readError: Error?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) {
      location in
      do { data = try Data(contentsOf: location) } catch { readError = error }
    }
    if let error = coordinationError ?? readError as NSError? { throw error }
    guard let data else { throw BackupError.invalidFile }

    return data
  }
}
