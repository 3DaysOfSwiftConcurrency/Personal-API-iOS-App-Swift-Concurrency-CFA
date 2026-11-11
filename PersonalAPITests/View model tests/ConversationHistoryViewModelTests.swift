import Observation
import XCTest

@testable import PersonalAPI

@MainActor final class ConversationHistoryViewModelTests: XCTestCase {
  func testLoadDisplaysSavedHistory() async throws {
    let chats = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let id = UUID()
    try await chats.send("Question", in: id)
    let vm = ConversationHistoryViewModel(conversationsFeature: chats)
    await vm.load()
    XCTAssertEqual(vm.conversations.first?.id, id)
    XCTAssertFalse(vm.isConversationOperationInProgress)
    XCTAssertNil(vm.error)
  }
  func testFailedLoadCanRetry() async {
    let store = MemoryConversationRepository()
    let chats = ConversationsFeature(
      repository: store, queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let vm = ConversationHistoryViewModel(conversationsFeature: chats)
    await store.setFailure(true)
    await vm.load()
    XCTAssertNotNil(vm.error)
    await store.setFailure(false)
    await vm.load()
    XCTAssertNil(vm.error)
  }
}

extension ConversationHistoryViewModelTests {
  func testDeleteIntentRemovesSelectionAndConversation() async throws {
    let chats = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let id = UUID()
    try await chats.send("Question", in: id)
    let vm = ConversationHistoryViewModel(conversationsFeature: chats)
    let changed = expectation(description: "History updated")
    withObservationTracking {
      _ = vm.conversations
    } onChange: {
      changed.fulfill()
    }
    vm.pendingDeletion = id
    vm.deletePending()
    XCTAssertNil(vm.pendingDeletion)
    await fulfillment(of: [changed], timeout: 2)
    XCTAssertTrue(vm.conversations.isEmpty)
    XCTAssertNil(vm.error)
  }
  func testFailedDeletionPreservesConversationAndReportsError() async throws {
    let store = MemoryConversationRepository()
    let chats = ConversationsFeature(
      repository: store, queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let id = UUID()
    try await chats.send("Question", in: id)
    let vm = ConversationHistoryViewModel(conversationsFeature: chats)
    await store.setFailure(true)
    let failed = expectation(description: "Deletion error")
    withObservationTracking {
      _ = vm.error
    } onChange: {
      failed.fulfill()
    }
    vm.pendingDeletion = id
    vm.deletePending()
    await fulfillment(of: [failed], timeout: 2)
    XCTAssertEqual(vm.conversations.count, 1)
    XCTAssertNotNil(vm.error)
  }
}
