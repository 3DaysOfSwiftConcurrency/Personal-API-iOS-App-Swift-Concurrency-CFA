import SwiftUI

struct AppColourTheme: Equatable, Identifiable {
  let name: String
  var id: String { name }
  let background: Color
  let surface: Color
  let primary: Color
  let secondary: Color
  let accent: Color
  let interactiveAccent: Color
  let onAccent: Color
  let error: Color

  // Lazy loaded colours.
  struct Colours {
    static let brandPurple = Color(red: 103 / 255.0, green: 80 / 255.0, blue: 184 / 255.0)
    static let activeViolet = Color(red: 161 / 255.0, green: 138 / 255.0, blue: 230 / 255.0)
    static let softWhite = Color(red: 245 / 255.0, green: 243 / 255.0, blue: 248 / 255.0)
    static let coolGrey = Color(red: 165 / 255.0, green: 161 / 255.0, blue: 173 / 255.0)
    static let midnightCharcoal = Color(red: 20 / 255.0, green: 19 / 255.0, blue: 22 / 255.0)
    static let graphiteGrey = Color(white: 0.09)
    static let slateGrey = Color(white: 0.16)
    static let deepNavy = Color(red: 0.025, green: 0.055, blue: 0.1)
    static let oceanNavy = Color(red: 0.055, green: 0.105, blue: 0.17)
    static let oceanBlue = Color(red: 0.13, green: 0.36, blue: 0.65)
    static let skyBlue = Color(red: 0.42, green: 0.72, blue: 1.0)
    static let coralRed = Color(red: 1, green: 0.45, blue: 0.45)
    static let deepPine = Color(red: 0.025, green: 0.07, blue: 0.055)
    static let pineGreen = Color(red: 0.065, green: 0.13, blue: 0.1)
    static let forestGreen = Color(red: 0.13, green: 0.39, blue: 0.28)
    static let mintGreen = Color(red: 0.4, green: 0.84, blue: 0.64)
    static let deepPlum = Color(red: 0.09, green: 0.035, blue: 0.06)
    static let plum = Color(red: 0.16, green: 0.075, blue: 0.115)
    static let roseRed = Color(red: 0.6, green: 0.23, blue: 0.38)
    static let softPink = Color(red: 1.0, green: 0.56, blue: 0.72)
    static let deepUmber = Color(red: 0.09, green: 0.045, blue: 0.025)
    static let warmUmber = Color(red: 0.16, green: 0.09, blue: 0.055)
    static let burntOrange = Color(red: 0.6, green: 0.28, blue: 0.1)
    static let apricot = Color(red: 1.0, green: 0.67, blue: 0.37)
    static let deepIndigo = Color(red: 0.055, green: 0.04, blue: 0.105)
    static let twilightIndigo = Color(red: 0.105, green: 0.075, blue: 0.18)
    static let twilightPurple = Color(red: 0.38, green: 0.27, blue: 0.65)
    static let lavender = Color(red: 0.73, green: 0.62, blue: 1.0)
  }

  // Colour Themes.
  static let midnight = AppColourTheme(
    name: "Midnight",
    background: .black,
    surface: Colours.midnightCharcoal,
    primary: Colours.softWhite,
    secondary: Colours.coolGrey,
    accent: Colours.brandPurple,
    interactiveAccent: Colours.activeViolet,
    onAccent: .white,
    error: .red)

  static let graphite = AppColourTheme(
    name: "Graphite",
    background: Colours.graphiteGrey,
    surface: Colours.slateGrey,
    primary: Colours.softWhite,
    secondary: Colours.coolGrey,
    accent: Colours.brandPurple,
    interactiveAccent: Colours.activeViolet,
    onAccent: .white,
    error: .orange)

  static let ocean = AppColourTheme(
    name: "Ocean",
    background: Colours.deepNavy,
    surface: Colours.oceanNavy,
    primary: Colours.softWhite,
    secondary: Colours.coolGrey,
    accent: Colours.oceanBlue,
    interactiveAccent: Colours.skyBlue,
    onAccent: .white,
    error: Colours.coralRed)

  static let forest = AppColourTheme(
    name: "Forest",
    background: Colours.deepPine,
    surface: Colours.pineGreen,
    primary: Colours.softWhite,
    secondary: Colours.coolGrey,
    accent: Colours.forestGreen,
    interactiveAccent: Colours.mintGreen,
    onAccent: .white,
    error: Colours.coralRed)

  static let rose = AppColourTheme(
    name: "Rose",
    background: Colours.deepPlum,
    surface: Colours.plum,
    primary: Colours.softWhite,
    secondary: Colours.coolGrey,
    accent: Colours.roseRed,
    interactiveAccent: Colours.softPink,
    onAccent: .white,
    error: Colours.coralRed)

  static let ember = AppColourTheme(
    name: "Ember",
    background: Colours.deepUmber,
    surface: Colours.warmUmber,
    primary: Colours.softWhite,
    secondary: Colours.coolGrey,
    accent: Colours.burntOrange,
    interactiveAccent: Colours.apricot,
    onAccent: .white,
    error: Colours.coralRed)

  static let twilight = AppColourTheme(
    name: "Twilight",
    background: Colours.deepIndigo,
    surface: Colours.twilightIndigo,
    primary: Colours.softWhite,
    secondary: Colours.coolGrey,
    accent: Colours.twilightPurple,
    interactiveAccent: Colours.lavender,
    onAccent: .white,
    error: Colours.coralRed)

  static let all: [AppColourTheme] = [midnight, graphite, ocean, forest, rose, ember, twilight]
}

/// Keeps the visible button surface and its tap area at least 40 points tall.
struct PersonalAPIButtonStyle: ButtonStyle {
  enum Appearance { case plain, bordered, outlined }
  var appearance: Appearance = .plain
  var minimumHeight: CGFloat = 40
  @Environment(ThemeStore.self) private var theme
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, appearance == .plain ? 0 : 12)
      .frame(minHeight: minimumHeight)
      .foregroundStyle(
        appearance == .outlined ? theme.palette.interactiveAccent : theme.palette.primary
      )
      .background(background, in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        if appearance == .outlined {
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(theme.palette.interactiveAccent, lineWidth: 1)
        }
      }
      .contentShape(Rectangle())
      .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.4)
  }

  private var background: Color {
    switch appearance {
    case .plain: .clear
    case .bordered: theme.palette.surface
    case .outlined: .clear
    }
  }
}
