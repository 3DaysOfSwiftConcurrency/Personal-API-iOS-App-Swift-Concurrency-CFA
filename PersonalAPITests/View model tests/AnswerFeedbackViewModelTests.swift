import XCTest

@testable import PersonalAPI

@MainActor final class AnswerFeedbackViewModelTests: XCTestCase {
  func testSavePersistsSelectedReasonAndExplanation() async throws {
    let chats = ConversationsFeature(
      repository: MemoryConversationRepository(), queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let id = UUID()
    try await chats.send("Question", in: id)
    let turn = try XCTUnwrap(chats.conversations.first?.turns.first)
    let vm = AnswerFeedbackViewModel(conversationsFeature: chats)
    vm.reason = .missingInformation
    vm.explanation = "More context needed"
    await vm.save(conversationID: id, turnID: turn.id)
    XCTAssertTrue(vm.saved)
    XCTAssertFalse(vm.isSaving)
    XCTAssertNil(vm.error)
    XCTAssertEqual(chats.conversations.first?.turns.first?.feedback?.rating, .missingInformation)
    XCTAssertEqual(chats.conversations.first?.turns.first?.feedback?.explanation, vm.explanation)
  }
  func testFailureKeepsFeedbackDraftForRetry() async throws {
    let store = MemoryConversationRepository()
    let chats = ConversationsFeature(
      repository: store, queryFeature: QueryFeature(searcher: ConversationQueryStub()), now: { Date() })
    let id = UUID()
    try await chats.send("Question", in: id)
    let turn = try XCTUnwrap(chats.conversations.first?.turns.first)
    let vm = AnswerFeedbackViewModel(conversationsFeature: chats)
    vm.explanation = "Keep this draft"
    await store.setFailure(true)
    await vm.save(conversationID: id, turnID: turn.id)
    XCTAssertFalse(vm.saved)
    XCTAssertEqual(vm.explanation, "Keep this draft")
    XCTAssertNotNil(vm.error)
    await store.setFailure(false)
    await vm.save(conversationID: id, turnID: turn.id)
    XCTAssertTrue(vm.saved)
    XCTAssertNil(vm.error)
  }
}
