# Cooperative Feature Architecture for Personal API

This document is the repository-local CFA contract for established-product maintenance. Product behaviour must remain stable unless a change is explicitly requested.

## Ownership chain

```text
SwiftUI View → Dedicated ViewModel → Concrete Feature → Worker / Resource Manager
```

- A View declares UI, bindings and navigation, then forwards user intent.
- A dedicated `@MainActor @Observable` ViewModel owns screen-local and presentation state.
- A concrete `@MainActor @Observable` Feature owns reusable business behaviour and shared observable state.
- An actor worker performs non-UI computation or communicates with an external resource through an injectable narrow interface.
- A resource manager owns each external resource and its SDK objects.
- `AppModel` constructs the live object graph. It is not a state bucket or service locator.

The name of an initializer parameter must match the stored dependency. Avoid redundant protocols that merely mirror a concrete Feature. Protocols belong at worker and external-resource seams where substitution is required.

## Product boundaries

Each top-level tab maps to one distinct Feature:

| Tab | Feature |
| --- | --- |
| Training | `MomentsFeature` |
| Life Map | `LifeMapFeature` |
| Personal API | `ConversationsFeature` |
| Export | `ExportFeature` |
| Settings | `SettingsFeature` |

Supporting Features such as Profile, Query, Authentication and Backup remain explicit dependencies in `AppModel`.

## AppModel and lifecycle

`AppModel` stores concrete Features and offers one explicit initializer plus `live()`. Production dependencies are assembled once. Launch idempotence is represented by a Boolean. App lifecycle callbacks enter the graph through the stable application delegate, not through a conditional root view or screen-owned launch work.

Cross-feature recovery and refresh workflows must await the underlying operations. A successful return must mean the observable state is current. Concurrent callers share a retained task when the operation is single-flight.

## Task ownership

Every unstructured `Task` has an explicit owner and completion policy.

- ViewModels retain task handles for user actions.
- Repeated taps either share the same operation or deliberately replace and cancel it.
- A Feature retains app-owned work that must outlive a screen.
- Cancellation of one waiter must not accidentally cancel feature-owned shared work.
- Task handles are cleared after completion.
- Views do not hide reusable work inside `.task` or ad-hoc callbacks.

## Persistence

Personal API has one SwiftData resource owner:

- `SwiftDataManager` lazily opens exactly one `ModelContainer` and prepares its parent directory first.
- `SwiftDataRepository` is an `@ModelActor` created from that container.
- Fresh model contexts come from the model-actor boundary.
- Features and ViewModels receive immutable Sendable snapshots and never own SwiftData SDK objects.
- A failed first open remains retryable.
- Change streams do not open the database merely because they are observed.

Other device integrations follow the same rule: the resource owner keeps SDK objects behind an injectable worker-facing interface.

## Views and ViewModels

Every screen constructs its adjacent ViewModel with `@State`. Views may read shared theme presentation state from the environment. They do not access repositories, SwiftData, device APIs or business validation directly.

ViewModels may format values and coordinate sheets, focus, drafts and navigation. Reusable validation, persistence coordination, recovery, search policy and domain transformations belong to Features.

## Feature operations

Feature commands expose clear completion semantics. A command that returns successfully has completed the work its name promises. Silent early returns are not valid busy handling. Use shared tasks, explicit replacement, or a typed busy error.

Features publish successful writes only after their resource operation succeeds. Failure must not leave optimistic shared state that was never committed. Recovery reload failures must propagate rather than being converted to apparent success.

## Testing and completion gate

Architecture work is complete only when all applicable checks pass:

- Every top-level tab has its own concrete Feature and named Feature test suite.
- Every production unstructured task has explicit ownership.
- Shared operations have overlap and cancellation coverage.
- SwiftData container creation exists only in `SwiftDataManager`.
- No force unwrap is required for a runtime workflow.
- Xcode groups and build phases reference every source and test file exactly once.
- Shared Swift tests pass with strict concurrency checks.
- The iOS source graph typechecks and the Xcode project builds when the local Simulator service is available.
- Documentation describes the current concrete-Feature architecture.

Passing tests are evidence for covered behaviour, not proof that every race or product scenario is impossible.
