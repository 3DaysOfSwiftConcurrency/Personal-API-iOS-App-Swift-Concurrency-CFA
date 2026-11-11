import XCTest

@testable import PersonalAPI

@MainActor final class BackupsViewModelTests: XCTestCase {
  func testCommandsAndStatusUseFeature() async {
    let repository = ViewRecoveryRepositoryStub()
    let files = ViewRecoveryFilesStub()
    let feature = makeBackupFeature(repository: repository, files: files)
    let viewModel = BackupsViewModel(backupFeature: feature)

    await viewModel.backupNow()
    let preparedForces = await files.preparedForces
    XCTAssertEqual(preparedForces, [true])

    let url = URL(fileURLWithPath: "/test.json")
    await viewModel.inspect(url)
    let inspected = await files.inspected
    XCTAssertEqual(inspected, url)
    await viewModel.restore()
    let restores = await repository.restores
    XCTAssertEqual(restores, 1)
    XCTAssertEqual(viewModel.status, feature.status)
  }

  func testImportFailureIsVisible() {
    let viewModel = BackupsViewModel(backupFeature: makeBackupFeature())
    viewModel.importFinished(.failure(TestFailure.unavailable))
    XCTAssertNotNil(viewModel.error)
  }

  func testSyncCheckAndIssueAreExposedFromFeature() async {
    let account = CloudAccountStub()
    await account.setState(.signedOut)
    let feature = makeBackupFeature(account: account)
    let viewModel = BackupsViewModel(backupFeature: feature)

    await viewModel.checkSync()

    let calls = await account.calls
    XCTAssertEqual(calls, 1)
    XCTAssertEqual(viewModel.syncIssue?.kind, .account)
    XCTAssertFalse(viewModel.isCheckingAccount)
  }

  func testErrorContextDistinguishesLocalBackupFromCloudCopy() async {
    let files = ViewRecoveryFilesStub()
    let feature = makeBackupFeature(files: files)
    let viewModel = BackupsViewModel(backupFeature: feature)

    await files.setFailurePoint(.prepare)
    await viewModel.backupNow()
    XCTAssertEqual(viewModel.errorTitle, "Recovery backup could not be created")
    XCTAssertTrue(viewModel.errorGuidance.contains("No new recovery backup"))

    await files.setFailurePoint(.upload)
    await viewModel.backupNow()
    XCTAssertTrue(viewModel.errorTitle.contains("saved locally"))
    XCTAssertTrue(viewModel.errorGuidance.contains("still saved on this device"))
  }

  func testPostRestoreRefreshFailureDoesNotSuggestRestoringAgain() async {
    let files = ViewRecoveryFilesStub()
    let feature = makeBackupFeature(files: files, reload: { throw TestFailure.unavailable })
    let viewModel = BackupsViewModel(backupFeature: feature)

    await viewModel.inspect(URL(fileURLWithPath: "/test.json"))
    await viewModel.restore()

    XCTAssertTrue(viewModel.errorTitle.contains("Data restored"))
    XCTAssertTrue(viewModel.errorGuidance.contains("do not need to restore again"))
  }

  func testFilePickerFailureHasFileContext() {
    let viewModel = BackupsViewModel(backupFeature: makeBackupFeature())
    viewModel.importFinished(.failure(TestFailure.unavailable))
    XCTAssertEqual(viewModel.errorTitle, "Recovery file could not be opened")
    XCTAssertTrue(viewModel.errorGuidance.contains("Nothing has been restored"))
  }

  func testFastAccountCheckPresentsResult() async {
    let account = CloudAccountStub()
    let feature = makeBackupFeature(account: account)
    let viewModel = BackupsViewModel(backupFeature: feature)

    await viewModel.checkAccountWithFeedback()

    XCTAssertTrue(viewModel.showingAccountCheckResult)
    XCTAssertNotNil(viewModel.accountStatus)
    let calls = await account.calls
    XCTAssertEqual(calls, 1)
  }
}
