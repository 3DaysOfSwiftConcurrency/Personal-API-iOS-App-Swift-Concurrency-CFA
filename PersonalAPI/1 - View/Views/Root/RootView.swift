import SwiftUI
import UIKit

struct RootView: View {
  @State private var viewModel = RootViewModel()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(ThemeStore.self) private var theme
  @State private var tab = AppTab.training
  var body: some View {
    ZStack {
      theme.palette.background.ignoresSafeArea()
      if viewModel.requiresUnlock {
        LockView()
      } else if viewModel.needsOnboarding {
        OnboardingView()
      } else {
        TabView(selection: $tab) {
          TrainingView().tabItem { Label("Training", systemImage: "square.and.pencil") }.tag(
            AppTab.training)
          LifeMapView().tabItem { Label("Life Map", systemImage: "sparkles") }.tag(AppTab.lifeMap)
          QueryView().tabItem {
            Label {
              Text("Personal API")
            } icon: {
              Image("PersonalAPITab")
                .renderingMode(.original)
            }
          }.tag(AppTab.personalAPI)
          ExportView().tabItem { Label("Export", systemImage: "square.and.arrow.up") }.tag(
            AppTab.export)
          SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(
            AppTab.settings)
        }
      }
      if scenePhase != .active {
        Color.black.ignoresSafeArea().overlay {
          VStack(spacing: 12) {
            Image("PersonalAPIBrand")
              .resizable()
              .scaledToFit()
              .frame(width: 160, height: 160)
              .accessibilityHidden(true)
            Text("PERSONAL API")
              .font(.caption)
              .tracking(4)
              .foregroundStyle(theme.palette.secondary)
          }
          .padding(24)
        }
      }
    }
    .disabled(viewModel.isRestoring)
  }
}

enum AppTab: Hashable { case training, lifeMap, personalAPI, export, settings }
