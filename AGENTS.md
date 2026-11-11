# Personal API architecture

CFA workflow: established-product maintenance.

Read `Documentation/APPMODEL_IOS_APPLICATION_TEMPLATE.md` completely before architecture changes. `ARCHITECTURE.md` maps those rules onto this product.

Preserve the numbered Xcode groups, one adjacent ViewModel per screen, concrete `@MainActor @Observable` Features, `AppModel.live()` composition, actor-owned external resources, and injectable worker/repository boundaries. Views remain declarative. ViewModels own presentation state and retained UI task handles, but no reusable business rules or persistence.

Each top-level tab owns a distinct Feature. `AppModel` is the only live composition root and stores concrete Features, never feature protocols. Cross-feature workflows belong to their owning Feature and must await the actual operation before reporting success.

`SwiftDataManager` owns the one lazily opened `ModelContainer`. `SwiftDataRepository` is the `@ModelActor` implementation created from that container. Do not construct containers or contexts in Views, ViewModels, Features, or workers.

Preserve original journal text and the principles in `PRODUCT.md`. The app bundle identifier remains `com.3DaysOfSwiftConcurrency.PersonalAPI`.

Validate with the iPhone Xcode test target when Simulator access is available. `Package.swift` runs the shared Model/ViewModel tests on macOS without iPhone Views. Always distinguish package-test evidence from an iPhone runtime build.
