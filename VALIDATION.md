# CFA conformance migration — 11 November 2026

- Replaced mirrored Feature protocols and `*Manager` concrete types with concrete `@MainActor @Observable` Features.
- Added a distinct Export Feature, retained task ownership, single-flight shared operations and failure-propagating recovery reloads.
- Introduced one lazy `SwiftDataManager` resource owner and an `@ModelActor` `SwiftDataRepository`, including directory preparation and failed-open retry coverage.
- Xcode project plist validates. All 75 app Swift files and 38 test Swift files are present exactly once.
- Strict-concurrency iOS source typecheck passed.
- Shared suite: 166 tests executed, four opt-in live-AI checks skipped, zero failures.
- Generic Simulator build reached compilation setup but stopped at asset catalog compilation because CoreSimulator exposed no installed runtime. Device UI, live iCloud, real authentication and live-model checks remain release validation work.

---

# SwiftUI chat scrolling — 16 September 2026

Removed ChatScrollView, ChatDraftBounds, and their Xcode references. Query now uses SwiftUI ScrollView/ScrollViewReader with native keyboard safe-area handling, interactive dismissal, bottom anchoring and a bottom target including 20 points of padding. A viewport-height change scrolls the focused composer into view. The shared UITextView adapter remains, with the same touch-delay configuration as Training.

iOS presentation source typechecking passed. Shared tests: 128 passed, four skipped, zero failures. No UIViewControllerRepresentable remains in app source. Keyboard timing, interactive dismissal and first-visible bottom positioning need device/Simulator validation; the shared tests cannot establish those UI behaviours. Earlier entries below describe historical implementations.

---

# Unit-test completeness pass — 16 September 2026

**128 passed, four opt-in live-AI tests skipped, zero failed.** All 13 ViewModels have dedicated suites. Added 44 tests and replaced one combined test. Audited all seven managers; coverage instrumentation found no unexecuted manager functions in the shared run. All 31 test source files are registered exactly once in Xcode.

See [Unit-test audit](Documentation/UNIT_TEST_AUDIT.md) for the behaviour map and validation limits. No production Swift code changed in this pass.

---

# CFA tidy verification — 16 September 2026

- Final shared macOS suite: **89 tests, four skipped, zero failures** (85 executed successfully).
- iOS presentation source typecheck: passed using temporary composition/Observable stand-ins; not a full app build.
- Xcode target membership: all 67 app Swift files and 25 test Swift files appear exactly once; no missing files or group cycles. Project plist validates.
- Added the **PersonalAPI Race Conditions** scheme and feature-organized controlled-interleaving suites.
- Full iPhone Simulator build remains blocked at asset compilation: CoreSimulator reports no available runtimes. Device keyboard, layout and inference checks are outstanding.
- No claim of exhaustive race freedom. See [CFA tidy review](Documentation/CFA_TIDY_REVIEW.md) for contracts, coverage and remaining acceptance checks.

---

# Unsupported answer correction — 15 September 2026

The user reported an unrecorded claim of loneliness. That phrase matched a fictional
style example in the answer instructions. This is strong evidence of example leakage,
not evidence of learning from feedback. Removed the factual example; added explicit
question relevance and insufficient-evidence instructions. No journal data was changed.
Live validation must repeat the original question and check that the answer admits
missing evidence about parenting instead of supplying an invented emotion.
Feedback buttons remain session-only and do not train or update the local model.

# Reliability update — 15 September 2026

- The user supplied evidence of a model refusal followed by a successful generated
  answer after manual retry on the simulator. The full on-device path is demonstrated.
- Added greedy sampling, one bounded retry for temporary service failures and a
  duplicate-submission guard. No automatic retry of refusals or guardrail responses.
- 39 deterministic tests pass; one opt-in live-model test is skipped. New checks
  cover retry recovery, retry exhaustion, permanent errors, cancellation during
  backoff and refusal/guardrail classification. iPhone app and test targets build.
- Whether this reduces refusal frequency needs repeated simulator trials. Greedy
  sampling does not guarantee determinism of the entire service or safety checks.

## Previous evidence

# Conversational response correction — 15 September 2026

The user demonstrated answer failure on the simulator after successful retrieval.
The previous catch-all error did not distinguish quote-validation failure from a
Foundation Models error, so its exact cause cannot be inferred from that screenshot.

Removed mandatory generated quotations/structured answer decoding. Plain-text model
answers now occupy the main response area; sources are collapsed and failure reasons
are explicit. Added regression tests for answers without quotes and failure wording.
34 tests pass, one opt-in model test is skipped.
The iPhone app/test targets build. Live answer generation remains unverified in this
sandbox; the user must run the updated app to verify the response or see the actual
model failure category. No claim of successful live answering is made from mocks.

## Previous implementation evidence

# Grounded answers — 15 September 2026

- 32 deterministic tests pass; one opt-in live-model test is skipped by default.
- iPhone app and test targets: TEST BUILD SUCCEEDED, Xcode 26.2.
- Added checks for supported-answer delivery, fabricated-quote rejection with retained
  evidence, abstention and ViewModel presentation of actual generated text.
- The user’s screenshot confirms semantic retrieval ran on their simulator. This
  does not establish answer-generation quality, which still needs a live simulator
  check outside this session’s inference-service restriction.
- No journal database, schema or bundle identifier changes. No simulator reinstall
  or erase was performed. Run the updated app from Xcode to test the answer stage.

## Previous search implementation evidence

# Local AI search — 15 September 2026

- 28 deterministic tests pass. The suite now also contains one opt-in real-model
  evaluation, skipped unless PERSONAL_API_LIVE_AI_TEST=1.
- iPhone Simulator app and test targets build with Xcode 26.2, arm64/x86_64.
  The command-line build uses OTHER_SWIFT_FLAGS=-disable-sandbox to allow compiler
  macro subprocesses in this environment; this is not a project setting.
- Coverage includes injected semantic selection without keyword overlap, unchanged
  source records, unavailable-model fallback, rejection of invented IDs, cancellation,
  AI abstention, full-text chunking and existing stale-result suppression.
- The actual Mac model reports available, but an attempted synthetic real-model
  query failed with Apple inference service “Sandbox restriction” (lookup error 159).
  This is recorded as an unverified live path, not a passing AI quality test.
- CoreSimulator service access is blocked from this session. The updated app was
  not installed or run against the user’s iPhone Air journal database. No simulator
  was erased, no app was uninstalled, and the persistence schema/bundle ID are unchanged.

Run the app from Xcode and confirm “On-device AI” after a search. Check paraphrases,
unrelated questions, long entries and repeated searches against known journal facts.
Open each source to assess false matches and omissions. Use the opt-in synthetic
model test outside the restricted environment for a repeatable initial quality check.

## Earlier prototype evidence

# Validation — 15 September 2026, after AppModel refactor

## Executed successfully

- **22 XCTest tests passed, zero failures**, using Package.swift on macOS and the actual shared Model/ViewModel source files (no alternate implementations).
- The suites cover all eight ViewModels, feature ownership and failures, concurrent saves/refresh, stale search suppression, cancellation, late authentication results, raw-source preservation, JSON export and a SwiftData read through a second independently created container.
- **iPhone Simulator app and test targets: TEST BUILD SUCCEEDED**, Xcode 26.2, Debug, arm64 and x86_64. No Swift source warnings or errors in the final build.
- Numbered Xcode groups match the filesystem. Bundle IDs remain unchanged in Debug/Release. PrivacyInfo.xcprivacy is included in the application resources phase.

## Reproduce

Open PersonalAPI.xcodeproj and use Product → Test on an available iPhone Simulator.

For shared logic tests without Simulator, run `swift test` from this project directory on macOS 14+ with Xcode installed. Package.swift compiles the same feature, repository and ViewModel files used by the iPhone target; it excludes iPhone-only Views and application startup.

This constrained tool environment required local cache directories and command-line `-disable-sandbox` for Swift’s nested macro launcher. Those environment accommodations are not stored in Xcode build settings. SwiftPM reported inaccessible optional user-cache folders, and CoreData reported a system notification-registration warning; the persistence test and all assertions nevertheless completed successfully.

## Not verified

- Running the iPhone app or XCTest suite in Simulator: write access to its folders was not granted.
- Visual layout, VoiceOver, keyboard/Dynamic Type, system Files export, real Face ID/passcode and app-switcher concealment.
- Physical-device signing/install or App Store packaging.
- Opening a pre-refactor store from an installed iPhone. Model names and stored fields were preserved by source inspection, but this is not a tested migration guarantee.
- Foundation Models, iCloud, semantic retrieval and imports: still outside this slice.

The macOS tests establish behaviour for the shared code, not an end-to-end iPhone verification or coverage percentage.

## Conversation prototype — 15 September 2026

- Shared macOS suite: 45 passed, 1 opt-in live-model check skipped, no failures.
- iPhone Simulator build-for-testing: succeeded with the existing development-environment compiler flag.
- Added checks for bounded question context, fresh journal reads after logging, saved chat reload, feedback persistence, cancellation, failed writes, corrupt archive preservation, and independent chat deletion.
- No simulator UI or live Foundation Models inference was executed by this validation. Follow Documentation/CONVERSATION_TESTING.md in the user's existing simulator. Existing journal data was not erased or migrated.

## Local query index — 15 September 2026

Shared macOS checks: 56 passed, one live-model test skipped, no failures. Added boundary checks proving a job query does not send school-only passages to the semantic worker, childhood remains searchable, topic changes drop old context, follow-ups retain references, new/deleted entries refresh candidates, unmatched queries do not call AI, and candidate payloads are bounded exact source excerpts. Project-file syntax passes validation. Live inference and simulator UI remain unverified in this environment.

## Job-answer regression tests — 15 September 2026

57 deterministic checks passed, 3 opt-in live checks skipped. Direct live generation was attempted separately and failed at model-service connection with sandbox restriction error 159; no live answer-quality conclusion is supported. The PersonalAPI Live AI Checks scheme enables direct and end-to-end checks from Xcode. Details: Documentation/JOB-ANSWER-TEST-RESULTS.md.

## Automatic journal fact indexing — 2026-09-15

Shared macOS suite: 70 tests executed, 66 passed, 4 opt-in live model tests skipped,
0 failures. Includes real temporary SwiftData stores for replacement, reopen, export,
legacy preservation and rejected unsupported replacements. New feature tests cover
backfill, extraction failure/retry, qualifications, source-grounded search payloads,
and stale/orphaned source exclusion. Diff whitespace check passed.
This does not validate the installed iPhone store migration or the live AI model.
Device follow-up: launch with an existing journal, let indexing finish, query an
explicit recorded statement, and inspect its original journal source. No Facts input
screen should appear. No user data was erased and no commit was made.

## Launch build repair — 16 September 2026

Removed the failing LaunchScreen.storyboard and all project references. Both app configurations now merge an explicit Info.plist containing UILaunchScreen with LaunchBackground and LaunchBrand assets. The launch artwork preserves the existing fingerprint and grey wordmark. Project/plist syntax and git diff whitespace checks pass. A fresh simulator build contains no CompileStoryboard step; full build remains unverified because asset compilation cannot access any simulator runtimes in this execution environment. Device appearance remains unverified.

## Chat layout cycle repair — 16 September 2026

User confirmed the app runs after the launch repair, but supplied repeated AttributeGraph cycle warnings. Removed the composer geometry callback and the SwiftUI clearance/height state that rebuilt the hosted composer after layout. Transcript and composer now share a native controller with direct constraints to one another and the keyboard guide. Removed the obsolete passthrough overlay controller. Responder changes are deferred outside updateUIView and coalesced using the current focus request. Swift parsing, standalone iOS SDK typechecking of both native components, and diff checks pass. Runtime disappearance of the warnings and interactive keyboard tracking still require device validation; no simulator runtime is accessible here.


## iCloud and recovery implementation — 16 September 2026

- Shared macOS suite: 153 discovered, 149 passed, 4 opt-in live-AI checks skipped; zero failures.
- iOS UI source typecheck passed. This uses the existing isolated UI harness, not an iPhone runtime.
- Generic iOS Xcode build attempted, blocked by unavailable CoreSimulator runtimes at asset-catalog compilation. No signed-cloud or visual validation claimed.
- V1 unversioned store migration exercised using a disk-backed fixture; real installed-device upgrade remains pending.
- Cloud copy policy tested with local-file adapter; actual coordinated cloud I/O remains a device check.
- See Documentation/ICLOUD_AND_RECOVERY.md for the behaviour contract and release checklist.
- Corrected a pre-existing ThemeStore setter typo (`theme.id` → `palette.id`) that prevented the initial shared-suite baseline compiling.

## Pre-release simplification

Removed the unused JSON conversation repository, its import/marker code, historical schema migration and migration-only tests at the owner's request. One current schema is used. Conversation reopen/export coverage now exercises the shared database directly. Earlier migration results above describe the superseded implementation.

## Actionable sync errors

Shared suite: 158 discovered, 154 passed, 4 opt-in live-AI checks skipped. Added guidance classification, nested CloudKit failures, backup/sync error separation, account checks, stale-result protection and ViewModel coverage. iOS UI source typecheck passed; no device runtime or live CloudKit transport verification claimed.

## Recovery error context

The Backups screen now labels the failed operation, explains its data impact and next step, and places raw errors inside Technical details. Restore failures distinguish pre-commit failure from post-restore refresh failure. Shared suite: 157 passed, 4 opt-in checks skipped; iOS UI source typecheck passed.
