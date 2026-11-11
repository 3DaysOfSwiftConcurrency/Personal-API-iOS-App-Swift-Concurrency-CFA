<p align="center">
  <img src="readme-images/PersonalAPI-Logo.png" width="160" alt="Personal API fingerprint logo">
</p>

# Personal API — A dataset about you.

**A lifetime, one Moment at a time.**

Personal API turns journal entries into a searchable dataset of your life. Capture meaningful Moments, explore your experiences with on-device AI, and export your words in a portable JSON file.

**Created and published by [3 Days of Swift Concurrency](https://www.3daysofswiftconcurrency.com/).**

Built with **SwiftUI**, **Swift Concurrency** and **Cooperative Feature Architecture (CFA)**. This repository is a working application and an evolving example of readable, testable iOS code.

## Your life, in your own words

- **Training.** Write detailed journal entries and build your dataset over time.
- **Life Map.** Explore AI-identified experiences and inspect the original passages behind them. One journal entry can describe several Moments.
- **Personal API.** Ask questions about your life, follow up in a conversation, and inspect the source entries behind answers.
- **Export.** Save your journal entries, recorded dates, IDs, stored facts and derived metadata in one JSON file. Conversations have a separate export.
- **Settings.** Edit or delete journal entries, enable the privacy lock, and choose from seven colour themes. Your theme choice persists across launches.

The dataset is yours to refine. Exporting creates a portable snapshot; it does not upload your journal or train an AI model. Using the file with another AI tool depends on that tool's capabilities.

## Built with Cooperative Feature Architecture

**CFA gives every responsibility a clear home.** Its purpose here is to keep the app understandable as features grow, change or are removed.

The guiding principles are **KISS and readability**: clear names, straightforward control flow, explicit ownership and small, meaningful components. Compact code is not automatically simple code.

```text
SwiftUI View → Dedicated ViewModel → Concrete Feature
                                      ├── Worker actors
                                      └── Resource managers

AppModel.live() assembles the shared feature dependencies.
```

| Layer | Responsibility in Personal API |
| --- | --- |
| SwiftUI Views | Describe content, bindings and presentation; forward user intent. |
| Dedicated ViewModels | Own each screen's drafts, selection, presentation state and feature interactions. |
| Features | Own reusable business behaviour and shared state, independent of a particular screen. Concrete Features expose observable state on the Main Actor. |
| Worker actors | Perform suitable processing, search and generation work across explicit isolation boundaries. |
| Resource managers | Own persistence and device integration behind injectable worker-facing interfaces. |
| AppModel | Construct and connect the live feature graph in one composition root. |

### The engine belongs to the features

The architectural question we use during review is: **if we added another UI target, would this behaviour come with the model, or would we have to copy it out of a ViewModel?**

Validation, journal workflows, retrieval policy and persistence coordination belong to features. Focus, navigation, drafts and visual styling belong to presentation. Small UIKit adapters remain where they support specific interaction requirements: the shared journal editor controls touch responsiveness and keyboard submission.

### Concurrency requires explicit policies

Actors protect isolated state, but an asynchronous operation can suspend and allow other work to enter. Personal API therefore uses explicit operation policies, cancellation handling and checks against stale results. Where whole operations must remain ordered across suspension points, a FIFO asynchronous gate coordinates them without blocking a thread.

The race-condition suites exercise controlled interleavings for Authentication, Conversations, Life Map, Moments, Profile, Query and Settings. Passing these tests is evidence for the cases tested, not proof that all races are impossible.

### A project structure you can navigate

```text
PersonalAPI/
├── 1 - View/
│   ├── Views/             # Screens and adjacent ViewModels
│   ├── Components/        # Shared presentation components and adapters
│   └── Theme/             # Named colours, palettes and theme selection
├── 2 - AppModel/
│   ├── AppModel.swift     # Feature composition
│   ├── Features/          # Concrete Features, value types and workers
│   ├── Operation Scheduling/
│   └── User Data Storage/
├── 3 - App Resources/
└── 4 - Swift Extensions/

PersonalAPITests/
├── View model tests/
├── AppModel tests/
└── Race Conditions/       # Organised by feature
```

**[Explore the CFA Toolkit on GitHub →](https://github.com/3DaysOfSwift/cooperative-feature-architecture)**

The toolkit provides focused workflows for app creation, architecture adoption, Swift Concurrency migration, architecture review, feature work, testing and iterative codebase tidying. They give developers and coding agents a shared set of ownership rules and verification steps. Generated code still needs human review and appropriate testing.

For this app's implementation details, see [ARCHITECTURE.md](ARCHITECTURE.md), the [CFA tidy review](Documentation/CFA_TIDY_REVIEW.md) and [project instructions](AGENTS.md).

## Build and run

1. Open **PersonalAPI.xcodeproj** in Xcode.
2. Select the **PersonalAPI** scheme and an iPhone simulator or connected iPhone.
3. For a physical device, select your development team under **Signing & Capabilities**.
4. Run the app.

- Minimum deployment target: **iOS 17.0**.
- Project developed with **Xcode 26.2**.
- No third-party packages, API keys or server setup are required.
- On-device semantic search, answer generation and Life Map require **iOS 26+ and an available Apple Intelligence model**. Model availability must be checked on the actual device or runtime. Query includes keyword fallback; Life Map reports model unavailability.

## Try the app

1. Write a journal entry in **Training**. Include details you can ask about later.
2. Open the saved Moment and inspect your words and its derived metadata.
3. Ask a related question in **Personal API**, then inspect its sources.
4. Open **Life Map** on a supported device to explore identified experiences.
5. Export your dataset from **Export** and inspect the JSON.
6. Use **Settings → Manage journal entries** to refine an entry. Select a colour theme and relaunch to check that it is restored.

## Tests and verification

Run **Product → Test** with the PersonalAPI scheme for the Xcode test target. Additional schemes select race-condition tests and opt-in live-AI evaluations.

For shared Model and presentation-state tests on macOS:

```sh
swift test
```

The latest local shared-suite run on **11 November 2026** completed with **166 tests executed, four opt-in live-AI checks skipped, and zero failures**. Coverage includes dedicated suites for screen ViewModels, every top-level Feature, persistence, theme restoration and controlled concurrency cases.

The macOS harness does not exercise iPhone rendering or UIKit keyboard interaction. Recent UI changes passed source typechecking; Simulator access was unavailable for visual verification. See [VALIDATION.md](VALIDATION.md) and the [unit-test audit](Documentation/UNIT_TEST_AUDIT.md) for recorded checks and their scope; older entries describe earlier project states.

## The publisher and its training

[![3 Days of Swift Concurrency — iOS developer training](readme-images/Publisher-Logo.png)](https://www.3daysofswiftconcurrency.com/)

**[Explore the training at 3DaysOfSwiftConcurrency.com →](https://www.3daysofswiftconcurrency.com/)**

3 Days of Swift Concurrency offers Swift Concurrency training for iOS developers and publishes the CFA Toolkit. Personal API puts those architectural principles into practice in a real application, with source code that developers can inspect and learn from. No course purchase is required to explore this repository.

## Project status

Personal API is under active development. Life Map is experimental, AI results can be incomplete or incorrect, and original journal passages remain available for inspection. Private iCloud sync and recovery backups are implemented, with Apple container provisioning and signed-device verification still required. Public dataset import and HealthKit integration are not implemented. See [iCloud and recovery setup](Documentation/ICLOUD_AND_RECOVERY.md).

See [PRODUCT.md](PRODUCT.md) for product principles. When proposing changes, preserve original journal content, keep business behaviour in its owning feature, and include relevant tests and verification details.
