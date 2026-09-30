import AppKit
import SwiftUI

/// The user's look for the panel: accent colour, aurora, and motion.
///
/// Stored in preferences and mirrored into `Theme.palette`, which every view
/// reads. The panel re-renders from scratch when any of it changes — it is a
/// settings change, not something that happens while typing.
@MainActor
final class Appearance: ObservableObject {
    static let shared: Appearance = {
        #if DEBUG
        // A capture never reads or writes the user's own look: it starts from
        // the defaults in a throwaway suite, optionally set from the
        // environment (VOIDBAR_CAPTURE_ACCENT, VOIDBAR_CAPTURE_AURORA).
        if DemoCapture.requestedDirectory() != nil {
            let suite = "dev.xand0.VoidBar.capture.appearance"
            UserDefaults().removePersistentDomain(forName: suite)
            let look = Appearance(defaults: UserDefaults(suiteName: suite) ?? .standard)
            let env = ProcessInfo.processInfo.environment
            if let accent = env["VOIDBAR_CAPTURE_ACCENT"].flatMap(AccentPreset.init(rawValue:)) { look.preset = accent }
            if let aurora = env["VOIDBAR_CAPTURE_AURORA"].flatMap(AuroraMode.init(rawValue:)) { look.aurora = aurora }
            return look
        }
        #endif
        return Appearance()
    }()

    enum AccentPreset: String, CaseIterable, Identifiable {
        case ocean, blood, violet, emerald, amber, mono, custom
        var id: String { rawValue }

        var title: String {
            switch self {
            case .ocean: return localized("Ocean")
            case .blood: return localized("Blood red")
            case .violet: return localized("Violet")
            case .emerald: return localized("Emerald")
            case .amber: return localized("Amber")
            case .mono: return localized("Graphite")
            case .custom: return localized("Custom")
            }
        }

        /// sRGB components of the preset; nil for custom.
        var rgb: (Double, Double, Double)? {
            switch self {
            case .ocean: return (0.52, 0.66, 1.0)
            case .blood: return (0.86, 0.07, 0.13)
            case .violet: return (0.68, 0.50, 1.0)
            case .emerald: return (0.30, 0.84, 0.56)
            case .amber: return (1.0, 0.70, 0.28)
            case .mono: return (0.86, 0.87, 0.90)
            case .custom: return nil
            }
        }
    }

    enum AuroraMode: String, CaseIterable, Identifiable {
        /// Colours of what is on screen: the cover, the sky, the timer.
        case content
        /// Shades of the accent only.
        case accent
        case off
        var id: String { rawValue }

        var title: String {
            switch self {
            case .content: return localized("By content")
            case .accent: return localized("Accent")
            case .off: return localized("Off")
            }
        }
    }

    @Published var preset: AccentPreset { didSet { persist() } }
    @Published var custom: Color { didSet { persist() } }
    @Published var aurora: AuroraMode { didSet { persist() } }
    @Published var auroraIntensity: Double { didSet { persist() } }
    @Published var animations: Bool { didSet { persist() } }
    /// Bumped on every change; the panel uses it to redraw everything.
    @Published private(set) var version = 0

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preset = AccentPreset(rawValue: defaults.string(forKey: Keys.preset) ?? "") ?? .ocean
        if let parts = defaults.array(forKey: Keys.custom) as? [Double], parts.count == 3 {
            custom = Color(.sRGB, red: parts[0], green: parts[1], blue: parts[2])
        } else {
            custom = Color(.sRGB, red: 0.86, green: 0.07, blue: 0.13)
        }
        aurora = AuroraMode(rawValue: defaults.string(forKey: Keys.aurora) ?? "") ?? .content
        auroraIntensity = defaults.object(forKey: Keys.intensity) as? Double ?? 1
        animations = defaults.object(forKey: Keys.animations) as? Bool ?? true
        apply()
    }

    private enum Keys {
        static let preset = "appearance.accent"
        static let custom = "appearance.customAccent"
        static let aurora = "appearance.aurora"
        static let intensity = "appearance.auroraIntensity"
        static let animations = "appearance.animations"
    }

    var accentColor: Color {
        if let rgb = preset.rgb { return Color(.sRGB, red: rgb.0, green: rgb.1, blue: rgb.2) }
        return custom
    }

    private func persist() {
        defaults.set(preset.rawValue, forKey: Keys.preset)
        if let rgb = NSColor(custom).usingColorSpace(.sRGB) {
            defaults.set([Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent)], forKey: Keys.custom)
        }
        defaults.set(aurora.rawValue, forKey: Keys.aurora)
        defaults.set(auroraIntensity, forKey: Keys.intensity)
        defaults.set(animations, forKey: Keys.animations)
        apply()
    }

    private func apply() {
        Theme.palette = Palette(
            accent: accentColor,
            aurora: aurora,
            auroraIntensity: auroraIntensity,
            animations: animations && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        version += 1
    }
}

/// What `Theme` hands out, resolved from `Appearance`.
struct Palette {
    var accent: Color
    var aurora: Appearance.AuroraMode
    var auroraIntensity: Double
    var animations: Bool

    static let standard = Palette(
        accent: Color(.sRGB, red: 0.52, green: 0.66, blue: 1.0),
        aurora: .content,
        auroraIntensity: 1,
        animations: true
    )

    /// A deeper, slightly shifted partner of the accent for gradients.
    var accentDeep: Color {
        let (h, s, b) = hsb
        return Color(hue: (h + (isRed ? 0.985 : 0.03)).truncatingRemainder(dividingBy: 1), saturation: min(1, s + 0.1), brightness: b * 0.72)
    }

    /// Normal load: the accent — unless the accent is itself red, where it
    /// would read as an alarm. Then normal is plain white.
    var loadNormal: Color { isRed ? Color.white.opacity(0.85) : accent }

    private var isRed: Bool {
        let (h, s, _) = hsb
        return s > 0.35 && (h < 0.04 || h > 0.93)
    }

    private var hsb: (Double, Double, Double) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(accent).usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b))
    }
}
