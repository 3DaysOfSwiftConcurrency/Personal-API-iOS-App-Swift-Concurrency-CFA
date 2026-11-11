import SwiftUI

struct LockView: View {
  @State private var viewModel = LockViewModel()
  @Environment(ThemeStore.self) private var theme
  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "lock.fill").font(.largeTitle)
      Text("Your life. Yours alone.").font(.title2)
      Button("Unlock Personal API") { viewModel.requestUnlock() }.buttonStyle(
        PersonalAPIButtonStyle(appearance: .outlined)
      ).disabled(viewModel.authenticating)
      if let error = viewModel.error {
        Text(error).font(.footnote).foregroundStyle(theme.palette.error)
      }
    }.padding()
  }
}
