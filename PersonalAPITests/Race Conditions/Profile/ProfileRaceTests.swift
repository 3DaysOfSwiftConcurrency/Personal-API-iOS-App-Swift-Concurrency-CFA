import XCTest

@testable import PersonalAPI

@MainActor final class ProfileRaceTests: XCTestCase {
  func testConcurrentWritesAndRefreshPreserveBothFacts() async throws {
    let repository = MemoryRepository()
    let manager = ProfileFeature(repository: repository, now: { Date() })
    async let first: Void = manager.addFact(label: "First", value: "One")
    async let second: Void = manager.addFact(label: "Second", value: "Two")
    async let refresh: Void = manager.refresh()
    _ = try await (first, second, refresh)
    let stored = try await repository.loadFacts()
    XCTAssertEqual(Set(stored.map(\.label)), ["First", "Second"])
    XCTAssertEqual(Set(manager.facts.map(\.label)), ["First", "Second"])
  }
}

extension ProfileRaceTests {
  func testCancelledQueuedWriteDoesNotCommitAndQueueContinues() async throws {
    let entered = expectation(description: "First write suspended")
    let barrier = RaceBarrier(entered)
    defer { Task { await barrier.release() } }
    let repository = PausedRepository(.factWrite, barrier: barrier)
    let manager = ProfileFeature(repository: repository, now: { Date() })
    let first = Task { try await manager.addFact(label: "First", value: "One") }
    await fulfillment(of: [entered], timeout: 2)
    let queued = expectation(description: "Second operation submitted")
    let second = Task {
      queued.fulfill()
      try await manager.addFact(label: "Cancelled", value: "Two")
    }
    await fulfillment(of: [queued], timeout: 2)
    second.cancel()
    await barrier.release()
    try await first.value
    do {
      try await second.value
      XCTFail("Expected cancellation")
    } catch is CancellationError {}
    try await manager.addFact(label: "Third", value: "Three")
    let stored = try await repository.loadFacts()
    XCTAssertEqual(stored.map(\.label), ["Third", "First"])
    XCTAssertEqual(manager.facts.map(\.label), ["Third", "First"])
  }
}
