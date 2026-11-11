# CFA architecture review — 11 November 2026

Scope: the PersonalAPI app target, test target, Xcode project and repository-local architecture guidance. This is an evidence-based conformance review, not a claim of exhaustive race freedom or device validation.

## Final result

No unresolved CFA conformance issue was found in the final audit pass.

| CFA gate | Result and evidence |
| --- | --- |
| Product boundaries | Training, Life Map, Personal API, Export and Settings each map to a distinct concrete Feature. |
| Composition | `AppModel` stores concrete Features, has an explicit initializer and assembles the live graph once in `live()`. |
| Feature shape | Every Feature is a concrete `@MainActor @Observable final class`; redundant Feature protocols were removed. |
| Presentation | Every screen owns an adjacent `@MainActor @Observable` ViewModel through `@State`. Views forward intent and contain no persistence rules. |
| Task ownership | User-action tasks are retained by ViewModels. Shared refresh, authentication, account-check and enrichment work is retained by its Feature. |
| Completion semantics | Recovery awaits Moments, Profile and Conversation reloads. Reload failure propagates instead of reporting a stale success. Busy workflows share work or return an explicit error. |
| Persistence | `SwiftDataManager` lazily creates one `ModelContainer`; `SwiftDataRepository` is the `@ModelActor` context owner. Store-directory creation is explicit and retryable. |
| External boundaries | Device authentication, cloud-account checks, backup files, repositories and AI workers are injected behind narrow interfaces. |
| Safety | No production force unwrap or forced cast remains in a runtime workflow. |
| Xcode integrity | Project plist validates. All 75 app Swift files and all 38 test Swift files are registered exactly once, with no missing entries. |
| Documentation | AGENTS, README, architecture and local CFA contract describe concrete Features and the current SwiftData ownership model. |

## Operation review

- Moment and Profile refreshes are single-flight and publish only after repository success.
- Life Map callers await the same Feature-owned refresh without transferring ownership to an individual waiter.
- Authentication callers share one evaluation. A background transition invalidates late completion through the generation guard.
- Conversation load is single-flight. Mutations fail explicitly when another conversation operation owns the workflow.
- Backup account checks and local-copy loads are single-flight. Persistent observation tasks are canceled during deinitialization.
- Export has its own Feature and no longer borrows the Settings Feature boundary.
- ViewModel command methods return their retained task handles, enabling deterministic behavioural tests.

## Verification

- Shared suite: 166 tests executed, four opt-in live-AI tests skipped, zero failures.
- Strict-concurrency iOS source typecheck: passed.
- Xcode project parsing and source membership: passed.
- Generic Simulator build reached Swift compilation but asset compilation could not run because CoreSimulator reported no available runtime. This is an environment limitation, not a source or project-reference failure.

Physical-device authentication, live iCloud transport, live Foundation Models output and visual interaction remain release validation tasks rather than CFA structural defects.
