# CFA tidy review — 16 September 2026

## Assessment

The project is substantially easier to read and maintain after these passes. Its feature engine is independent of SwiftUI, every concrete Feature is main-actor observable, and screen events delegate to adjacent ViewModels. It is a clean CFA example under validation; iPhone runtime and interaction checks remain environment-dependent.

## Completed passes

| Pass | Finding and change | Evidence |
| --- | --- | --- |
| UI ownership | Split chat answers, native chat scrolling, the shared journal editor and tab-logo rendering into presentation components. History and answer feedback now own adjacent ViewModels. Removed unreachable Profile UI, preserving the Profile feature and stored facts. | iOS SDK source typecheck; exact Xcode membership audit. |
| Declarative screens | Moved task creation, save/export actions and submission state into ViewModels. Reused the padded purple Done button. Kept binding, dismissal and lifecycle forwarding in Views. | Reviewed screen sources: no Task construction, persistence or business workflows. UIKit responder/layout code lives in adapters. |
| Reusable engine | Source resolution belongs to Moments; authentication lock state belongs to Authentication. Query orchestration and validation run in QueryWorker. ViewModels retain draft, navigation and display wording. | Shared Model and ViewModel tests. |
| Concurrency | All seven managers are `@MainActor @Observable`. Consolidated the duplicated whole-operation FIFO gate. Query inference and processing use actors; persistence remains repository-owned. | Controlled interleaving suites and existing persistence tests. |
| Re-review | Removed obsolete chat deletion UI ownership, checked historical source fidelity, consolidated gate release with defer, formatted Swift consistently and rebuilt directory groups to mirror the filesystem. | No missing, duplicate or cyclic source membership. |

## Behaviour corrections

- A cancelled authentication request cannot publish a late successful unlock or change the lock preference.
- A historical source keeps its cited words after a journal edit or deletion. Metadata can still update while the original words match. An explanatory notice identifies changed/deleted source entries.
- `canSearch` now applies the same 500-character upper bound as search execution.

## Concurrency contracts

| Feature | Suspension boundaries and policy | Coverage |
| --- | --- | --- |
| Moments | Repository reads/writes and publication share FIFO admission. Inference runs outside the gate. After inference, source ID and text must still match before metadata is committed. Fact replacement is checked by the repository. A committed write is published even if cancellation arrives during persistence. | Concurrent writes/refresh, pre-admission cancellation, processing failure/retry, stale analysis after edit, deletion during analysis, persistence failures. |
| Profile | FIFO covers repository operations and publication. Cancelled queued callers take their turn, check cancellation, release, and do no work. | Concurrent writes/refresh; controlled suspended write, cancelled queued write, subsequent successful write. |
| Query | Independent request-local results; an actor does the search pipeline. Cancellation is checked after external inference. A search uses its captured source snapshot, which may become historical during a later edit. | Second search completes before suspended first; cancellation of first does not cancel second; existing provenance and failure tests. |
| Conversations | Rejects conflicting actions while busy. Persists the question before inference; cancelled inference does not publish a late answer. | Overlapping send/delete rejection; late answer after cancellation; failed commit; retry and feedback persistence. |
| Authentication | Single in-flight authentication, generation invalidation on background, cancellation check before publication. System authentication stays main-actor bound. | Late success after background; late success after cancellation; authentication required for setting changes. |
| Settings | Preference updates are synchronous. Export returns a repository snapshot to each caller; no shared export result. Regeneration delegates to Moments. | Overlapping exports/preferences and deliberately reversed export completion with different snapshots. |
| Life Map | Coalesces overlapping refreshes. Revalidates entry text after extraction and before publication. Failed entries do not stop the batch. | Deletion during suspended extraction and overlapping refresh; unsupported evidence; per-entry failures and retries. |

FIFO means order of arrival at the gate, not order of Task creation. Actors alone do not make a workflow atomic across `await`. Independent features are not forced through a global queue. Actor workers use Swift's normal executor scheduling; UI-bound authentication and lightweight observable-state coordination remain on MainActor.

## Validation and limits

- Shared macOS harness: 89 tests discovered, four environment/device-dependent tests skipped, zero failures in the final verification run.
- Added `PersonalAPI Race Conditions` Xcode scheme and `PersonalAPITests/RaceConditions.xctestplan`, selecting seven feature suites. The normal scheme still includes all tests.
- iOS SDK source typecheck passed for the presentation code. This substitutes observable conformance and composition only in temporary checking copies because standalone macro expansion is restricted; the real Model/ViewModel macros are exercised by SwiftPM tests.
- Xcode source graph: 67 app Swift files and 25 test Swift files, each registered exactly once, with no missing files or cyclic groups.
- Full iPhone Simulator build is blocked by CoreSimulator reporting no available runtimes during asset compilation. This is not a successful iPhone build or UI runtime test.
- Race tests cover explicit adverse schedules; they do not prove 100% race freedom. Remaining validation includes actual keyboard transitions, very long transcripts, device inference, Thread Sanitizer on a supported runtime, and broader schedules around real persistence/inference latency. No performance claim is made for large eager chat transcripts.

## Next acceptance check

With Simulator access restored, run the normal scheme and Race Conditions scheme, then verify Training focus, chat focus/Send/Done, interactive dismissal, bottom-on-open, history selection, feedback, and journal edit/delete. Only then decide whether the UI deserves showcase status.
