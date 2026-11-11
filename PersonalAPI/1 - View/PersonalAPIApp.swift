import SwiftUI

@MainActor final class ApplicationDelegate: NSObject, UIApplicationDelegate {
  private var launchTask: Task<Void, Never>?
  private var activeTask: Task<Void, Never>?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    guard launchTask == nil else { return true }
    launchTask = Task { [weak self] in
      await AppModel.shared.applicationDidFinishLaunching()
      self?.launchTask = nil
    }
    return true
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    guard activeTask == nil else { return }
    activeTask = Task { [weak self] in
      await AppModel.shared.applicationDidBecomeActive()
      self?.activeTask = nil
    }
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    activeTask?.cancel()
    activeTask = nil
    AppModel.shared.applicationDidEnterBackground()
  }
}

@main struct PersonalAPIApp: App {
  @UIApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
  @State private var theme = ThemeStore(preferences: LocalPreferences(defaults: .standard))
  var body: some Scene {
    WindowGroup {
      RootView()
      .environment(theme)
      .buttonStyle(PersonalAPIButtonStyle())
      .preferredColorScheme(.dark)
      .tint(theme.palette.interactiveAccent)
      .foregroundStyle(theme.palette.primary)
    }
  }
}
