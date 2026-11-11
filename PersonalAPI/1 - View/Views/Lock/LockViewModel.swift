import Observation

@MainActor @Observable final class LockViewModel {
  private let authenticationFeature: AuthenticationFeature
  init(authenticationFeature: AuthenticationFeature = AppModel.shared.authenticationFeature) {
    self.authenticationFeature = authenticationFeature
  }
  var error: String? { authenticationFeature.error }
  var authenticating: Bool { authenticationFeature.authenticating }
  private var unlockTask: Task<Void, Never>?
  func unlock() async { await authenticationFeature.unlock() }
  @discardableResult
  func requestUnlock() -> Task<Void, Never> {
    if let unlockTask { return unlockTask }
    let task = Task { [self] in
      defer { unlockTask = nil }
      await unlock()
    }
    unlockTask = task
    return task
  }
}
