# Personal API — Cooperative Feature Architecture

This project follows the repository-local [CFA contract](Documentation/APPMODEL_IOS_APPLICATION_TEMPLATE.md). [AGENTS.md](AGENTS.md) records the maintenance workflow for future changes.

## Visible structure

```text
PersonalAPI
├── 1 - View
│   ├── PersonalAPIApp.swift
│   ├── Theme
│   │   ├── AppColourTheme.swift
│   │   └── ThemeStore.swift
│   └── Views
│       ├── Root
│       ├── Onboarding
│       ├── Lock
│       ├── Training
│       ├── Moment Detail
│       ├── Profile
│       ├── Query
│       └── Settings
│           (each screen has its adjacent ViewModel)
├── 2 - AppModel
│   ├── AppModel.swift
│   ├── Features
│   │   ├── Moments
│   │   ├── Profile
│   │   ├── Query
│   │   ├── Conversations
│   │   ├── Life Map
│   │   ├── Export
│   │   ├── Backup
│   │   ├── Authentication
│   │   └── Settings
│   └── User Data Storage
│       ├── Protocols
│       └── Local
├── 3 - App Resources
│   └── PrivacyInfo.xcprivacy
└── 4 - Swift Extensions
    (reserved; no extensions needed yet)

PersonalAPITests
├── View model tests
└── AppModel tests
    └── Test Support
```

Xcode groups mirror the physical folders. There are no empty CloudKit/Networking implementations, redundant routers or speculative managers. The first prototype uses no external package dependencies.

## Responsibilities

**Views** construct their own `@State private var viewModel`, own presentation, render state and report intent. Only immutable data reaches a destination. ThemeStore is a presentation dependency, supplied through the environment. Midnight is the production palette; Graphite is a Debug-only alternative. Both remain dark.

**ViewModels** retain concrete Features, with live defaults from `AppModel.shared`. They own drafts, display errors, task handles and export presentation. They do not use SwiftData or repositories, mutate shared collections, or validate domain data.

**AppModel** has a fully explicit initializer and a `live()` factory. It assembles and retains the concrete Features. `ApplicationDelegate` initiates launch through a stable root. A Boolean makes initial launch idempotent, while feature-owned tasks provide single-flight work. Authentication and settings preferences load before the initial data refresh completes.

**Features** own validation, shared state, retrieval policy, authentication state and workflow ordering. Export has its own Feature rather than borrowing Settings. Each capability is usable from another UI without moving business logic. Features publish successful writes only after the resource operation returns.

**Resource managers and repositories** own database, JSON and device integration. `SwiftDataManager` is an actor that lazily opens one SwiftData container after preparing its directory. It creates the `@ModelActor` `SwiftDataRepository`, which owns model-context access. Models and UI receive immutable Sendable snapshots. `LocalDeviceAuthentication` wraps LocalAuthentication; `LocalPreferences` wraps app-owned UserDefaults.

## Capture and enrichment

TrainingView → TrainingViewModel → MomentsFeature → PersonalDataRepository → SwiftDataManager.

The manager rejects blank input without trimming the stored text, assigns a stable ID and capture time using its injected clock, saves the source, publishes it, and requests enrichment. The command returns after the raw save, so the draft can clear independently of analysis. A save failure retains the draft and publishes no new source.

MomentProcessor accepts immutable source input. LocalMomentProcessor is an actor that currently extracts a title only. The app-owned enrichment task coalesces requests and attempts each pending source once per pass; failed processing remains pending and exposes a retry message. Regeneration finishes an existing pass, marks all analyses pending in one repository transaction and requests another pass. Original text is never replaced.

A FIFO continuation gate in MomentsFeature orders repository writes/reads with publication across suspension. ProfileFeature uses the same local pattern for its independent collection. They do not serialize unrelated feature workflows. Cancellation is checked before writes begin; once saved, the committed result is published even if cancellation arrives during the write. Enrichment intentionally outlives its initiating screen.

## Retrieval and search lifetime

QueryFeature reads authoritative original Moments through the repository. Its injected
OnDeviceMomentSearch actor uses Foundation Models on iOS 26+/macOS 26+ when the local
Apple Intelligence model is available. Each fresh model session selects relevant
passage indices from JSON input; only validated repository IDs become evidence.
Entries are split into overlapping 1,200-character passages in batches of three,
so long entries are not silently truncated. Results are deduplicated and ordered
by capture date, capped at 20 original Moments. This is a small-dataset semantic
search prototype, not an embedding index.

The model treats question/entry text as untrusted data. Prompt instructions alone
cannot prove relevance; source inspection remains essential. Invalid IDs, unavailable
models and generation failures fall back to keyword overlap with explicit status.
Cancellation propagates instead of starting fallback. A valid empty AI selection
remains empty. Every search uses a fresh repository snapshot and writes nothing.

QueryViewModel owns the replaceable task and request identity, preventing late
results from replacing a newer search. The UI reports AI versus keyword search and
lets users open exact source text. Questions are limited to 500 characters. Journal Moments remain answer evidence; source-linked extracted facts expand local retrieval; relative-date resolution remains outside this search slice. Runtime model availability is checked each search.

## Authentication

Enabling/disabling the lock requires device-owner authentication. Backgrounding locks the feature, invalidates any active system context, and increments an operation generation. A late successful authentication cannot unlock after that transition. Authentication-caused inactive transitions only conceal the screen, avoiding a lock loop.

The app gate is not a separate encryption system. Exported JSON is plaintext. Physical-device Face ID/passcode and app-switcher checks remain required. [Apple’s LocalAuthentication documentation](https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id) describes the underlying system policy.

## Persistence and compatibility

The original v1 SwiftData class identities (`Moment`, `PersonalFact`) and stored properties are retained inside storage. Domain snapshots are separate types, so refactoring folder ownership does not require renaming the persistent entities. No store-reset fallback is used. Failed loads remain visible and retryable; one feature’s error does not conceal the others.

The live configuration selects a private CloudKit container with one current schema for entries, facts and conversations. Because the app is pre-release, no historical schema migration or legacy chat-file import is maintained. Test repositories explicitly disable CloudKit.

`BackupFeature` owns recovery status and serializes backup/restore workflows. `RecoveryBackupFiles` owns file rotation and coordinated iCloud Drive copying. `SwiftDataManager` takes full snapshots and restores them with a pre-restore safety copy. See [the behaviour contract and provisioning checklist](Documentation/ICLOUD_AND_RECOVERY.md).

Queries, export and enrichment still load whole collections. Indexed lookup, pagination and background batching are subsequent scaling work, not claims about this prototype.

## Open export

The v1 JSON structure is retained: format, schemaVersion, exportedAt, moments and facts. Source text, UUIDs, source provenance, timestamps and derived envelopes survive export. Dates use Foundation Codable numeric seconds since 2001-01-01 UTC. Unknown/corrupt derived data remains preserved as base64 while raw text stays readable; the UI exposes a metadata issue and regeneration option.

Export reads both collections without suspension between them on the repository actor, preventing app writes from interleaving. SwiftUI’s FileDocument adapter stays in the View layer. Public dataset import is not implemented; versioned recovery-file restoration is a separate capability.

PrivacyInfo declares app-owned UserDefaults access using CA92.1, consistent with [Apple’s required-reason documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). No developer-server collection or tracking is implemented.

## Foundation Models extension

Implement a new availability-gated MomentProcessor adapter. Keep extractive fallback for unsupported or unavailable models. Require source support for factual tags, distinguish explicit emotions from interpretations, and preserve uncertainty in significance/life-event annotations. Dates need evidence, precision and time-zone context; inferred dates must not replace user-supplied dates. Add those evidence fields before inferring classifications.

Treat journal content as data, never instructions. Test negation, quotations, imagined events and events involving other people. Keep retrieval evaluation separate from synthesis evaluation; future answers must cite original source IDs.

## Validation

[VALIDATION.md](VALIDATION.md) records executed checks and limits. The canonical [architecture checklist](Documentation/ARCHITECTURE_REVIEW.md) is an implementation review, not a scored project dashboard.

## Conversational on-device answers

QueryFeature asks its injected OnDeviceMomentAnswerer actor for a natural-language
answer after semantic retrieval. AppModel.live() assembles this dependency. The
model receives retrieved original text and instructions to answer directly, avoid
outside knowledge and invented facts, attribute opinions, and admit missing evidence.
The answer now uses ordinary text generation: generated JSON and exact quotations
are not required to display a response. This removes a brittle rejection point;
it does not prove the model's factual accuracy. Source records remain available
behind a collapsed Sources control. Journal text is never replaced by a response.

The context budget remains 6,000 characters, at most 2,000 per Moment. Omitted
context is disclosed. Model refusals, context overflow, unavailable assets, language
limitations and service errors are presented as answer failures, never as successful
match-count responses. The composer is bottom-inset with a 96-point resting gap. Query hides the tab bar by default and offers a top navigation toggle. Focusing the composer hides tabs and reduces the gap to 12 points above the keyboard. These are local View presentation states.
Query now displays persistent multi-turn conversations; see the conversation feature below.

## Local model reliability

Both selection and prose generation use greedy sampling to reduce sampling variation.
A fresh model session retries once after a cancellable 750 ms delay only for explicit
rate limiting/concurrent-request errors or Cocoa XPC interruption/invalidation.
Refusals, guardrail responses, missing assets, unsupported language and context errors
are not automatically retried. The retry helper inherits its caller’s actor isolation.
Identical submissions while the current query is running are ignored; a changed query
can still replace and cancel the previous request. Answer instructions prioritise the
recorded relationship and relevant facts, attribute uncertainty and avoid endorsing
character judgments or predicting someone’s future. These are safeguards to evaluate,
not proof that model refusals or inaccurate answers have been eliminated.

## Personal response voice

Answer instructions address the journal owner directly as you/your, mapping first-person
memories to a second-person response. Relationship-first answers use recorded details
only. Perceptions remain attributed and time-bounded; the prompt must not infer "always",
locations or stronger claims than the source supports. Style instructions contain no fictional personal facts: an earlier example contaminated
a live response with an unsupported claim of loneliness and was removed.

### Query gaps and journal invitations

Query distinguishes a successful retrieval with no evidence, an explicit answer abstention, and technical model failures. Missing evidence invites the user to record more; service errors retain their actual failure message. The local answer prompt requests an exact abstention marker for unsupported questions. This is model-reported uncertainty, not proof that the entire dataset lacks the information.

“Log a memory about this” opens Training with the submitted question as context. The question and generated answer are never automatically stored as journal facts. Only the user's typed entry is saved through the existing Moments feature. After saving, the user can return to Query and ask again.

## Conversation feature

QueryView → QueryViewModel → ConversationsFeature owns the chat workflow. QueryFeature remains responsible for fresh journal retrieval and grounded generation. AppModel.live() explicitly composes both features and SwiftDataManager.

Conversations are stored alongside journal data in SwiftData by the shared repository actor. Questions are saved before inference. Interrupted turns can be answered again; retries replace only the latest answer without duplicating its question. A single in-flight mutation prevents archive writes racing across suspension. Failed writes are surfaced and never published as saved state.

The model receives the current question and at most four earlier questions (500 characters each) to resolve conversational references. Earlier generated answers and feedback are excluded from the model input. Only freshly retrieved journal text is evidence. This deliberately bounded prototype may need clarification when a reference depends on older discussion or an AI answer. Prompt guidance is not a factuality guarantee.

Saved chats retain answer results, source snapshots and optional feedback. Deleting a chat removes its database record. Chat export is available independently from journal export, via the conversation menu. Feedback is local evaluation data; it is neither model training nor a journal correction.

UI state (selected conversation, composer, sheets, keyboard and cancellable task) remains in QueryView/QueryViewModel. The conversation feature owns authoritative messages and persistence. The raised composer and navigation toggle are preserved.

## Qualified answers and retained passages

Semantic retrieval now returns the selected original passages as well as Moment identity. QueryFeature verifies each passage is a nonempty exact substring of its source before forwarding it. AnswerContext passes these excerpts to generation instead of replacing them with the first 2,000 characters of each record. The 6,000-character budget keeps whole passages; omitted context remains disclosed.

Answer instructions permit partial and qualified answers from mixed or uncertain recollections. They preserve negation and distinguish present-day judgments from feelings at the time. No personal example or question-specific answer is embedded. Refusals remain reported and are not automatically retried. This improves evidence delivery but cannot guarantee model compliance or factual accuracy. Optional passage metadata remains compatible with older saved chats.

## Local candidate selection before AI

AppModel.live() now injects a LocalQueryIndex actor into QueryFeature. Each query reads the canonical repository snapshot; the actor refreshes changed entries and removes deleted entries from its regenerable in-memory cache. It indexes exact 600-character passages with 100-character overlap, outside the Main Actor. This is a lexical candidate index with a small explicit synonym vocabulary, not an embedding index or a persisted AI summary database.

The current question ranks candidates across the local collection before any model call. At most 12 passages are sent to semantic selection, with at most three per entry (one per entry for broad timeline wording). Matched topic vocabulary narrows candidates; childhood is not excluded by a fixed rule. A passage relevant to both work and childhood can legitimately appear in a work search.

Only reference-bearing follow-ups inherit recent questions. A standalone topic change does not resend old questions. This heuristic can miss implicit follow-ups and is not a general conversation resolver.

No local candidates means no AI request and a message suggesting a more specific person, place or topic. The app never silently falls back to sending the whole journal. Semantic output must reference text from the supplied candidates; answers still use original, validated passages. No original source or SwiftData schema is changed.

Known limits: English vocabulary, lexical recall, character-based passage boundaries, capped coverage for broad questions, full repository snapshot reads and an index rebuilt after relaunch. Persistent indexing and richer enrichment remain future work. This change reduces irrelevant input; it does not bypass model guardrails or guarantee successful answers.


## Journal-only Training and automatic fact indexing

Training has no Facts input. MomentsFeature now owns automatic extraction after the
original journal save, independently of title enrichment. LocalJournalFactExtractor
runs off the main actor and extracts explicit English statements as qualified original
paragraphs. Labels are search hints, not verified personal attributes or model output.
No dates, current status, or confidence scores are inferred. Opposing entries stay
separate and retain their original timestamps and text.

PersonalFactSnapshot has optional FactDerivation (source UUID, original source revision,
extractor version). PersonalFact adds one optional derivationData property for additive
SwiftData migration. Legacy rows decode without derivation and remain in export, but
cannot enter new searches. SwiftDataManager atomically replaces an entry's derived rows,
validates its current source revision, and keeps unchanged extractions stable. Journal
text is never rewritten. The existing export envelope is retained with optional fact
metadata. No new UI or separate manager was introduced.

Completed older Moments are backfilled on load; new saves enqueue extraction. Retry
and Regenerate Metadata retry indexing. Extraction failure leaves the saved entry
usable and publishes an enrichment error. This is foreground app work, not a scheduled
background job. The cheap local extraction pass is rechecked after app relaunch.

LocalQueryIndex checks source UUID, full text revision, extractor version and exact
support before ranking a derived passage. Missing or changed sources are ineligible
immediately. Only original journal text reaches the AI, with original journal IDs for
citations. Existing bounds (12 candidates, 3 per entry) apply, and duplicate passages
are removed. Legacy archived fact citations remain readable.

Limits: this first extractor recognises a small set of English first-person patterns
(work, preferences, residence, education, possessions and background). Paragraphs over
600 characters are left to raw journal retrieval rather than shortened and potentially
misrepresented. It is deliberately not a general semantic extractor. There is no journal
edit/delete UI yet; stale/orphaned rows are excluded, and replacement validates revisions.
Future edit/delete commands must invoke replacement/removal in their storage transaction.

Validation: shared tests cover automatic extraction, completed-entry backfill, negative
qualifications, failure/retry, original-source answer payloads, stale/orphan exclusion,
legacy preservation, repeat extraction, reopen and export. iPhone UI and migration of an
installed pre-change store still require Xcode/device validation.

## Life Map experiment

LifeMapFeature/LifeMapFeature owns source-backed event candidates; LifeMapExtractor performs on-device inference as an actor. LifeMapViewModel exposes this feature to LifeMapView. AppModel supplies a shared read-only journal repository. Derived cache is in-memory and revision checked; there is no schema/export change. See Documentation/LIFE-MAP-EXPERIMENT.md for removal steps and limitations.

## Journal maintenance in Settings

Settings opens JournalEntriesView and EditJournalEntryView, each with its own adjacent ViewModel. Both use MomentsFeature; MomentsFeature owns validation and serialized publication. SwiftDataManager atomically edits/deletes the source and removes its derived facts. Edits retain the ID, recorded date and source, reset metadata, and request reprocessing. Revision checks reject stale editor saves/deletes, and in-flight analysis cannot overwrite an edited entry. Life Map revalidates its source cache on refresh; new queries and exports read current storage. Existing saved conversations and files already exported are historical copies and are not rewritten.

Validation includes durable reopen/export after edit/delete, derived-fact invalidation, stale edit rejection, failed deletion publication, failed-save draft retention, shared list updates and processing/edit races. No storage schema migration is required. iPhone UI runtime checks remain separate from shared model tests.


## Tidy review and race contracts

See [CFA_TIDY_REVIEW.md](Documentation/CFA_TIDY_REVIEW.md) for screen ownership, actor boundaries, FIFO admission, cancellation policies, and validation limitations. Shared presentation adapters live in `1 - View/Components`; each interactive screen owns its adjacent ViewModel. Run the `PersonalAPI Race Conditions` scheme for controlled feature interleavings.
