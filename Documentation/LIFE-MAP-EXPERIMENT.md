# Life Map experiment

## Ownership and removal

LifeMapView -> LifeMapViewModel -> LifeMapFeature.
The Feature reads PersonalDataRepository and delegates inference to the LifeMapExtractor actor. AppModel.live constructs these dependencies; tests inject an extractor. The View only lays out results and selects source detail.

Before: Root tabs Training, Personal API, Export, Settings; no event segmentation.
After: Life Map tab reads journal entries and extracts several event candidates per entry. No changes to journal persistence, query rules, or JSON exports. Derived results are cached in manager memory against exact source revisions.

Remove the Life Map View and feature folders, Root tab, AppModel dependency and live construction, test-factory argument, package/project entries and LifeMapTests to remove this experiment. No migration or data deletion is needed.

## Behaviour and limits

On tab entry or refresh, load original entries, discard outdated cached revisions, process uncached entries on-device and validate every returned passage as an exact nonempty source substring. Re-read sources after inference to avoid stale evidence. Publish partial progress and errors. Cancelling the screen task stops further requests. Failed entries retry on the next refresh. Titles are AI interpretations; matching text proves provenance, not semantic accuracy.

No cloud requests or journal writes. Apple Intelligence availability is required. No synthetic/fallback nodes are shown. Entries without specific lived experiences may yield zero nodes. Model output uses a dynamic FoundationModels generation schema with typed event properties; free-form JSON parsing is not used. Content refusals are reported without changing originals or bypassing model restrictions. Attempted entries and failed entries are tracked separately from successful reads; remaining entries continue after a failure. Long entries are processed in 2,400-character chunks, which can split a single experience. Duplicate passages within an entry are removed; semantic deduplication across entries, dates/people/place extraction, corrections, merging and persistent cache are not implemented in this trial. The map is a readable adaptive constellation of labelled points, not a claim about relationships between events.

## Validation

73 shared tests: 69 passed, 4 live-AI tests skipped. New injected-extractor tests cover three entries yielding five points, exact-source provenance, stable cached IDs, rejection of unsupported evidence, continued processing after refusal, accurate attempt/failure counts and retry state reset. These tests do not establish live model accuracy. iOS SDK typecheck passed for the actual LifeMapView and extractor with stand-in screen dependencies. Project plist and whitespace checks passed. Device appearance, live extraction quality, and accessibility navigation still need runtime validation.
