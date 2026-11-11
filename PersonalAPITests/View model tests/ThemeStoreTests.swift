import XCTest

@testable import PersonalAPI

@MainActor final class ThemeStoreTests: XCTestCase {
  func testMissingOrUnknownPreferenceUsesMidnight() {
    let preferences = MemoryPreferences()
    XCTAssertEqual(ThemeStore(preferences: preferences).palette, .midnight)
    preferences.colourThemeID = "Removed theme"
    XCTAssertEqual(ThemeStore(preferences: preferences).palette, .midnight)
  }

  func testEveryThemePersistsAcrossReconstruction() throws {
    let suiteName = "ThemeStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = ThemeStore(preferences: LocalPreferences(defaults: defaults))

    for theme in AppColourTheme.all {
      store.palette = theme
      let restoredDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
      let restored = ThemeStore(preferences: LocalPreferences(defaults: restoredDefaults))
      XCTAssertEqual(restored.palette, theme)
    }
  }
}
