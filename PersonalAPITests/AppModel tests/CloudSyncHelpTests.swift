import CloudKit
import XCTest

@testable import PersonalAPI

@MainActor final class CloudSyncHelpTests: XCTestCase {
  func testCloudFailuresHaveActionableGuidance() {
    let cases: [(CKError.Code, CloudSyncIssue.Kind)] = [
      (.notAuthenticated, .account), (.networkUnavailable, .network),
      (.quotaExceeded, .storage), (.missingEntitlement, .configuration),
      (.badContainer, .configuration), (.badDatabase, .configuration),
    ]
    for (code, kind) in cases {
      let issue = CloudSyncIssue.from(NSError(domain: CKErrorDomain, code: code.rawValue))
      XCTAssertEqual(issue.kind, kind)
      XCTAssertFalse(issue.guidance.isEmpty)
      XCTAssertNotNil(issue.details)
      XCTAssertEqual(issue.offersSettings, kind != .configuration)
    }
  }

  func testWrappedConfigurationFailureIsNotBlamedOnUser() {
    let error = NSError(
      domain: "CoreData", code: 1,
      userInfo: [
        NSUnderlyingErrorKey:
          NSError(domain: CKErrorDomain, code: CKError.Code.missingEntitlement.rawValue)
      ])
    let issue = CloudSyncIssue.from(error)
    XCTAssertEqual(issue.kind, .configuration)
    XCTAssertFalse(issue.offersSettings)
  }

  func testBackupSuccessCannotEraseSyncFailure() async {
    let manager = makeManager()
    let issue = CloudSyncIssue(kind: .configuration, details: "Missing container")
    await manager.receivedCloudEvent(
      CloudSyncEvent(imported: false, succeeded: false, issue: issue))
    await manager.backup(force: true)
    XCTAssertEqual(manager.syncIssue, issue)
    XCTAssertTrue(manager.syncStatus.contains("attention"))
    XCTAssertNil(manager.error)
  }

  func testAccountAvailableDoesNotClaimSuccessfulSync() async {
    let manager = makeManager()
    let issue = CloudSyncIssue(kind: .network, details: "Offline")
    await manager.receivedCloudEvent(
      CloudSyncEvent(imported: false, succeeded: false, issue: issue))
    await manager.checkSyncAvailability()
    XCTAssertEqual(manager.syncIssue, issue)
    XCTAssertTrue(manager.accountStatus?.contains("does not confirm") == true)
    await manager.receivedCloudEvent(CloudSyncEvent(imported: false, succeeded: true, issue: nil))
    XCTAssertNil(manager.syncIssue)
  }

  func testSignedOutAndRestrictedAccountsExplainNextStep() async {
    let account = CloudAccountStub()
    let manager = makeManager(account: account)
    await account.setState(.signedOut)
    await manager.checkSyncAvailability()
    XCTAssertEqual(manager.syncIssue?.kind, .account)
    await account.setState(.restricted)
    await manager.checkSyncAvailability()
    XCTAssertEqual(manager.syncIssue?.kind, .restricted)
    await account.setState(.available)
    await manager.checkSyncAvailability()
    XCTAssertNil(manager.syncIssue)
    XCTAssertFalse(manager.isCheckingAccount)
  }

  func testOlderAccountCheckCannotOverwriteNewSyncEvent() async {
    let account = PausedCloudAccount()
    let manager = makeManager(account: account)
    let check = Task { await manager.checkSyncAvailability() }
    await account.waitUntilChecking()
    let issue = CloudSyncIssue(kind: .configuration, details: "Configuration changed")
    await manager.receivedCloudEvent(
      CloudSyncEvent(imported: false, succeeded: false, issue: issue))
    await account.complete()
    await check.value
    XCTAssertEqual(manager.syncIssue, issue)
    XCTAssertNil(manager.accountStatus)
  }

  private func makeManager(account: any CloudAccountChecking = CloudAccountStub()) -> BackupFeature
  {
    BackupFeature(
      repository: RecoveryRepositoryStub(), files: RecoveryFilesStub(), account: account,
      preferences: MemoryPreferences(), now: { Date() }, canRestore: { true }, reload: {})
  }
}

private actor PausedCloudAccount: CloudAccountChecking {
  var started = false
  var waiter: CheckedContinuation<Void, Never>?
  var completion: CheckedContinuation<CloudAccountState, Never>?
  func check() async -> CloudAccountState {
    started = true
    waiter?.resume()
    waiter = nil
    return await withCheckedContinuation { completion = $0 }
  }
  func waitUntilChecking() async {
    if !started { await withCheckedContinuation { waiter = $0 } }
  }
  func complete() {
    completion?.resume(returning: .signedOut)
    completion = nil
  }
}

extension CloudSyncHelpTests {
  func testPartialFailurePreservesUnderlyingDiagnostic() {
    let child = NSError(domain: CKErrorDomain, code: CKError.Code.badContainer.rawValue,
      userInfo: [NSLocalizedDescriptionKey: "Container is not provisioned"])
    let error = NSError(domain: CKErrorDomain, code: CKError.Code.partialFailure.rawValue,
      userInfo: [CKPartialErrorsByItemIDKey: ["private-record-id": child]])
    let issue = CloudSyncIssue.from(error)
    XCTAssertEqual(issue.kind, .configuration)
    XCTAssertTrue(issue.details?.contains("Container is not provisioned") == true)
    XCTAssertFalse(issue.details?.contains("private-record-id") == true)
  }
}
