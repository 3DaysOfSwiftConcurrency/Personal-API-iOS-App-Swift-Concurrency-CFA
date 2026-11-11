# Unit-test audit — 11 November 2026

## Result

The shared suite executed 166 tests with zero failures. Four opt-in live-AI tests were skipped by design. The Xcode test target contains all 38 test source files exactly once.

## Coverage inventory

- Every screen ViewModel has a dedicated test suite.
- Every top-level tab Feature has direct behavioural coverage, including the new `ExportFeatureTests`.
- Supporting Features cover Moments, Profile, Query, Conversations, Authentication and Backup behaviour.
- Controlled overlap tests cover Authentication, Backup, Conversations, Life Map, Moments, Profile, Query and Settings.
- SwiftData tests cover real temporary stores, first-open coalescing, missing-directory creation, failed-directory retry, persistence, recovery and export behaviour.
- Recovery tests verify that refresh failures remain visible after committed restore work.
- ViewModel tests exercise retained command-task sharing, success and failure presentation, cancellation and draft preservation.

## Limits

The Swift package compiles the production Feature, worker, persistence and ViewModel sources on macOS. It does not execute SwiftUI rendering, UIKit keyboard behaviour, real LocalAuthentication, live CloudKit transport or live Foundation Models inference.

The entire iOS source graph separately passes strict-concurrency typechecking. A generic Xcode Simulator build cannot complete asset compilation in the current environment because no Simulator runtime is available.
