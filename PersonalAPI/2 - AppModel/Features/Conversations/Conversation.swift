import Foundation

struct ChatTurn: Identifiable, Codable, Sendable {
  let id: UUID
  let question: String
  let createdAt: Date
  var result: QueryResult?
  var failure: String?
  var feedback: AnswerFeedback?
}
struct AnswerFeedback: Codable, Sendable {
  enum Rating: String, Codable, CaseIterable {
    case useful, inventedDetail, misunderstood, missingInformation
  }
  let rating: Rating
  let explanation: String
  let recordedAt: Date
}
struct Conversation: Identifiable, Codable, Sendable {
  let id: UUID
  let createdAt: Date
  var updatedAt: Date
  var turns: [ChatTurn]
  var title: String { turns.first.map { String($0.question.prefix(70)) } ?? "New chat" }
}
enum ConversationError: LocalizedError {
  case busy, missing, unsupportedArchive
  var errorDescription: String? {
    switch self {
    case .busy: return "Please wait for the current operation to finish."
    case .missing: return "This conversation is no longer available."
    case .unsupportedArchive: return "This conversation archive needs a newer app version."
    }
  }
}
