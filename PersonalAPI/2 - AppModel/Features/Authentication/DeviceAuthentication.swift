import Foundation

@MainActor protocol DeviceAuthentication: AnyObject, Sendable {
  func authenticate() async throws -> Bool
  func cancel()
}
