import CloudKit
import Foundation

enum CloudAccountState: Sendable {
  case available, signedOut, restricted, unavailable
}

struct CloudSyncIssue: Sendable, Equatable {
  enum Kind: Sendable { case account, restricted, network, storage, configuration, unknown }
  let kind: Kind
  let details: String?

  static func from(_ error: Error?) -> Self {
    guard let error else { return Self(kind: .unknown, details: nil) }
    let nsError = error as NSError
    let kind = classify(nsError, depth: 0)
    return Self(
      kind: kind, details: diagnosticDetails(nsError, depth: 0))
  }

  // Preserve underlying failures without dumping record IDs or record contents.
  private static func diagnosticDetails(_ error: NSError, depth: Int) -> String {
    let summary = "\(error.localizedDescription) (\(error.domain), \(error.code))"
    guard depth < 8 else { return summary }
    var messages = [summary]
    if let reason = error.localizedFailureReason { messages.append(reason) }
    for child in childErrors(error) {
      messages.append(diagnosticDetails(child, depth: depth + 1))
    }
    return messages.joined(separator: "\n\n")
  }

  private static func childErrors(_ error: NSError) -> [NSError] {
    var children: [NSError] = []
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
      children.append(underlying)
    }
    if let partial = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
      children.append(contentsOf: partial.values.map { $0 as NSError })
    }
    if let detailed = error.userInfo["NSDetailedErrors"] as? [NSError] {
      children.append(contentsOf: detailed)
    }
    return children
  }

  private static func classify(_ error: NSError, depth: Int) -> Kind {
    guard depth < 8 else { return .unknown }
    if error.domain == CKErrorDomain, let code = CKError.Code(rawValue: error.code) {
      switch code {
      case .notAuthenticated: return .account
      case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
        return .network
      case .quotaExceeded: return .storage
      case .badContainer, .badDatabase, .missingEntitlement: return .configuration
      default: break
      }
    }
    for child in childErrors(error) {
      let kind = classify(child, depth: depth + 1)
      if kind != .unknown { return kind }
    }
    return .unknown
  }
}
