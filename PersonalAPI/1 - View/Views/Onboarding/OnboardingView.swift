import SwiftUI

struct OnboardingView: View {
  @State private var viewModel = OnboardingViewModel()
  @Environment(ThemeStore.self) private var theme
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        VStack(spacing: 4) {
          Image("PersonalAPIBrand")
            .resizable()
            .scaledToFit()
            .frame(width: 112, height: 112)
            .frame(height: 84)
            .clipped()
            .blendMode(.screen)
            .accessibilityHidden(true)
          Text("PERSONAL API").font(.caption).tracking(4).foregroundStyle(theme.palette.secondary)
        }
        Text("A lifetime,\none Moment\nat a time.").font(.largeTitle.bold())
        Text("Build the dataset of yourself that future AI will be able to interrogate.").font(
          .title3)
        Text(
          "Think in years, not days. Capture what matters. Your original words stay on this device, ready to export whenever you choose."
        ).foregroundStyle(theme.palette.secondary)
        Button("Start your dataset") { viewModel.startDataset() }.buttonStyle(
          PersonalAPIButtonStyle(appearance: .outlined, minimumHeight: 44)
        ).frame(maxWidth: .infinity)
      }.padding(28).padding(.top, 12)
    }
  }
}
