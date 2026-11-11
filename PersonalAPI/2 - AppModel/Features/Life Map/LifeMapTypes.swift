import Foundation

struct LifeMapCandidate: Codable, Sendable, Equatable {
  let title: String
  let passage: String
}
struct LifeMapPoint: Identifiable, Sendable {
  let id: String
  let title: String
  let passage: String
  let source: MomentSnapshot
}
protocol LifeMapExtracting: Sendable {
  func extract(_ text: String) async throws -> [LifeMapCandidate]
}
