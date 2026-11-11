# Prompt fix and current test schemes

The captured iPhone experiment is preserved in `PROMPT-COMPARISON-RESULTS.txt`.
The old long prompt abstained on all six supported cases. The short prompt answered
all six, including the single-entry case. Adding entries did not fix the old prompt.
Production now uses the exact short prompt from that experiment.

## Run in Xcode

- **PersonalAPI**: regular tests; four opt-in model experiments/checks skip.
- **PersonalAPI Live AI Checks**: regular tests plus live model checks (60 tests).
  Only the prompt comparison is excluded. Select iPhone Air and press Command-U.
- **PersonalAPI Prompt Experiment**: only the 16-call comparison, preserving the old
  prompt as a test-local baseline. Baseline abstentions are reported in the attachment;
  model errors still fail this diagnostic. A green experiment does not certify answer quality.

The direct and full-pipeline live job checks both assert answer content and second-person
wording. They still fail if production cannot answer the supported questions.

Verification after this change: shared macOS suite, 61 discovered, 57 passed, four
opt-in checks skipped, zero failures. Live iPhone inference must still be verified in
Xcode: this shell cannot access the simulator model service. The earlier short-prompt
experiment is evidence for the change, not a completed live run of the updated pipeline.

The short prompt expresses missing information in natural language; only the legacy
INSUFFICIENT_MEMORY marker currently maps to the explicit missing-memory result.
Broader evaluation of missing-information classification and nuanced answers remains needed.
No journal data or safety handling changed. Changes remain uncommitted.

---

## Earlier investigation (historical)

# Job answer regression checks — 15 September 2026

## Executed

57 shared macOS tests passed. Three live-model checks are opt-in and were skipped in the normal suite.

A regression fixture based on the supplied job entry verifies the actual JSON payload builder used by OnDeviceMomentAnswerer for:
- What is my job?
- Do I like my job?
- Do I make apps?

With controlled semantic selection, all three payloads contain both the explicit occupation and “I love making iOS apps.” The school-only entry is excluded. One job entry is sufficient to get those statements through the deterministic app pipeline.

This does not establish that the live semantic selector picks the same passages or that the model reasons correctly. The tests intentionally replace semantic selection and generation to locate application data-flow faults separately.

## Live attempt

The direct model test was attempted from this environment. It failed before answering with:
“Underlying connection was invalidated. Reason: failed at lookup with error 159 - Sandbox restriction”

This is an environment access failure, not an observed refusal or incorrect model answer.

## Run from Xcode

1. Select the **PersonalAPI Live AI Checks** scheme.
2. Select your existing iPhone Air simulator (or eligible physical iPhone).
3. Press **⌘U**.
4. Inspect QueryFeatureTests in the Test or Report navigator.

The dedicated scheme enables two live tests using an in-memory synthetic job entry:
- Direct generation: skips retrieval, checks an answer exists and addresses you; basic content assertions are smoke checks, not a complete factuality evaluation.
- Full pipeline: runs local candidate selection, on-device semantic selection, and answer generation; failure text includes the stage and insufficient-evidence status.

If direct generation passes but the pipeline fails, investigate selection. If direct generation itself abstains or refuses, retrieval is not necessary to reproduce that failure. These tests do not read or modify the installed journal database. Restore the normal PersonalAPI scheme for everyday runs.

## Prompt and data comparison

The Live AI Checks scheme now also selects testLivePromptAndDataComparisonWhenRequested.

It makes 16 direct generation requests: two prompts (current and short), two questions (occupation and enjoyment), and four datasets:
1. One explicit job/enjoyment entry.
2. Three identical copies of that entry.
3. Three distinct supporting entries.
4. An unrelated entry as a missing-information control.

Each request uses a fresh session and the same greedy sampling policy and payload format. Retrieval is excluded to isolate generation. Actual responses and thrown errors are retained in the “Prompt and data comparison” XCTest attachment and console output. Every case runs even if earlier cases fail.

Read the actual responses, including the negative control. A nonempty response is not automatically correct, and the test's abstention/error assertions are diagnostic checks, not a complete semantic evaluator. If the short prompt answers where the current one abstains, that supports a prompt effect. If repeated or additional data helps with the same prompt, it supports a data-volume effect for these fixtures, not a requirement that users repeat themselves. Repeat the experiment before drawing a reliability conclusion.

Production still uses the current prompt. Normal shared tests: 57 passed, four live checks skipped. This environment still cannot access the live model service; run the Live AI Checks scheme in Xcode with ⌘U, reopening the project if Xcode has cached its scheme definition.
