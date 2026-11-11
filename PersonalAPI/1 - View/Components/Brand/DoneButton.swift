import SwiftUI

struct DoneButton: View {
  let action: () -> Void
  @Environment(ThemeStore.self) private var theme
  var body: some View {
    Button(action: action) {
      Text("Done").foregroundStyle(theme.palette.interactiveAccent)
        .padding(.horizontal, 12).frame(minHeight: 40)
    }.buttonStyle(.plain).tint(theme.palette.interactiveAccent)
  }
}
