import XCTest
import SwiftUI
@testable import VoidBar

@MainActor
final class AppearanceTests: XCTestCase {
    override func tearDown() {
        Theme.palette = .standard
        super.tearDown()
    }

    private func freshDefaults() -> UserDefaults {
        let suite = "dev.xand0.VoidBar.tests.appearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testDefaultsToTheOceanAccentWithContentAurora() {
        let look = Appearance(defaults: freshDefaults())
        XCTAssertEqual(look.preset, .ocean)
        XCTAssertEqual(look.aurora, .content)
        XCTAssertEqual(look.auroraIntensity, 1)
    }

    func testChoicesPersistAndReachTheTheme() {
        let defaults = freshDefaults()
        let look = Appearance(defaults: defaults)
        look.preset = .blood
        look.aurora = .accent
        look.auroraIntensity = 1.4

        let reloaded = Appearance(defaults: defaults)
        XCTAssertEqual(reloaded.preset, .blood)
        XCTAssertEqual(reloaded.aurora, .accent)
        XCTAssertEqual(reloaded.auroraIntensity, 1.4)
        XCTAssertEqual(Theme.palette.aurora, .accent)
    }

    func testRedAccentKeepsNormalLoadNeutral() {
        let blood = Palette(accent: Color(.sRGB, red: 0.86, green: 0.07, blue: 0.13), aurora: .accent, auroraIntensity: 1, animations: true)
        XCTAssertNotEqual(blood.loadNormal, blood.accent, "normal load must not look like an alarm")
        let ocean = Palette.standard
        XCTAssertEqual(ocean.loadNormal, ocean.accent)
    }

    func testCustomColourIsKept() {
        let defaults = freshDefaults()
        let look = Appearance(defaults: defaults)
        look.custom = Color(.sRGB, red: 0.2, green: 0.4, blue: 0.6)
        look.preset = .custom
        let reloaded = Appearance(defaults: defaults)
        XCTAssertEqual(reloaded.preset, .custom)
        let rgb = NSColor(reloaded.custom).usingColorSpace(.sRGB)!
        XCTAssertEqual(rgb.blueComponent, 0.6, accuracy: 0.01)
    }
}
