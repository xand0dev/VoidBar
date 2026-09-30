import SwiftUI

/// VoidBar's design tokens.
///
/// The panel itself stays pure black — it has to read as part of the notch —
/// and everything on it is built from a small set of layers: translucent
/// white surfaces lit slightly from above, hairline edges, one cool accent for
/// "active" and "in progress", and three status colours that only appear when
/// something needs attention. Numbers use SF Rounded, words use SF Pro.
enum Theme {
    // MARK: Motion

    static let openAnimation = Animation.spring(response: 0.3, dampingFraction: 0.84)
    static let contentAnimation = Animation.easeOut(duration: 0.16)
    /// Pane switching: the outgoing pane leaves faster than the incoming one
    /// arrives, so the two are never both half-visible for long.
    static let paneAnimation = Animation.easeOut(duration: 0.18)
    static let paneIn = Animation.easeOut(duration: 0.22).delay(0.04)
    static let paneOut = Animation.easeIn(duration: 0.12)
    static let artworkAnimation = Animation.easeOut(duration: 0.28)

    // MARK: Shape

    static let collapsedTopRadius: CGFloat = 6
    static let collapsedBottomRadius: CGFloat = 10
    static let openTopRadius: CGFloat = 14
    static let openBottomRadius: CGFloat = 26
    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8

    // MARK: Colour

    static let primary = Color.white.opacity(0.94)
    static let secondary = Color.white.opacity(0.58)
    static let tertiary = Color.white.opacity(0.34)
    static let quaternary = Color.white.opacity(0.16)

    static let surface = Color.white.opacity(0.07)
    static let surfaceHover = Color.white.opacity(0.12)
    static let surfaceActive = Color.white.opacity(0.16)
    static let hairline = Color.white.opacity(0.09)

    /// The user's choices from Preferences → Appearance. Written only on the
    /// main thread by `Appearance`; read while views render.
    nonisolated(unsafe) static var palette = Palette.standard

    /// The one accent — a cool blue unless the user picked another.
    static var accent: Color { palette.accent }
    static var accentDeep: Color { palette.accentDeep }
    static let positive = Color(red: 0.40, green: 0.84, blue: 0.58)
    static let warning = Color(red: 1.0, green: 0.74, blue: 0.36)
    static let critical = Color(red: 1.0, green: 0.43, blue: 0.41)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .leading, endPoint: .trailing)
    }

    /// Accent while there is room, amber when it gets tight, red near the end.
    static func load(_ fraction: Double) -> Color {
        switch fraction {
        case 0.9...: return critical
        case 0.75..<0.9: return warning
        default: return palette.loadNormal
        }
    }

    // MARK: Type

    /// Large numerals: timers, temperatures, percentages.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static let title = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 12)
    static let bodyEmphasis = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 10.5)
    static let captionEmphasis = Font.system(size: 10.5, weight: .medium)
    static let micro = Font.system(size: 9, weight: .semibold)
}

// MARK: - Surfaces

/// A lit, hairline-edged surface: the building block of every pane.
struct Card: ViewModifier {
    var radius: CGFloat = Theme.cardRadius
    var padding: CGFloat = 10
    var emphasis: Double = 1

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.085 * emphasis),
                                Color.white.opacity(0.045 * emphasis),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func card(radius: CGFloat = Theme.cardRadius, padding: CGFloat = 10, emphasis: Double = 1) -> some View {
        modifier(Card(radius: radius, padding: padding, emphasis: emphasis))
    }

    /// Lets a scrolling list dissolve at its bottom edge instead of slicing
    /// the last row in half.
    func fadingBottomEdge(_ length: CGFloat = 18) -> some View {
        mask(
            VStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: length)
            }
        )
    }

    /// Tracks hover without triggering layout changes in the parent.
    func onHoverChange(_ action: @escaping (Bool) -> Void) -> some View {
        onHover(perform: action)
    }
}

/// Small caps label above a group of content.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.micro)
            .tracking(0.9)
            .foregroundStyle(Theme.tertiary)
            .lineLimit(1)
    }
}

/// A symbol on a tinted rounded square, marking what kind of thing a row is.
struct IconChip: View {
    let symbol: String
    var tint: Color = .white
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(tint == .white ? Theme.secondary : tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(tint == .white ? Theme.surface : tint.opacity(0.16))
            )
    }
}

/// Nothing to show yet, said calmly: a symbol, a line, and an optional hint.
struct EmptyState: View {
    let symbol: String
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.tertiary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.surface))
            Text(title)
                .font(Theme.bodyEmphasis)
                .foregroundStyle(Theme.secondary)
            if let message {
                Text(message)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Progress

/// A ring filled clockwise from the top.
struct RingGauge: View {
    let progress: Double
    var lineWidth: CGFloat = 6
    var tint: Color = Theme.accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.55), tint],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(progress, 0.01))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

/// A thin horizontal bar.
struct CapsuleProgress: View {
    let fraction: Double
    var tint: Color = Theme.accent
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Buttons

/// Flat, focus-free round button used for transport and tool controls.
struct NotchButtonStyle: ButtonStyle {
    var size: CGFloat = 26
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        StateButton(configuration: configuration, size: size, prominent: prominent)
    }

    private struct StateButton: View {
        let configuration: ButtonStyle.Configuration
        let size: CGFloat
        let prominent: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: prominent ? size * 0.4 : size * 0.46, weight: .semibold))
                .foregroundStyle(prominent ? Color.black : Color.white)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(
                        prominent
                            ? Color.white.opacity(hovering ? 1 : 0.92)
                            : (hovering ? Theme.surfaceHover : Color.clear)
                    )
                )
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .contentShape(Circle())
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .animation(Theme.contentAnimation, value: hovering)
        }
    }
}

/// Text button on a capsule. Prominent is white-on-black's inverse, used once
/// per pane at most.
struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        Pill(configuration: configuration, prominent: prominent)
    }

    private struct Pill: View {
        let configuration: ButtonStyle.Configuration
        let prominent: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(Theme.captionEmphasis)
                .foregroundStyle(prominent ? Color.black : Theme.primary)
                .padding(.horizontal, 11)
                .frame(height: 24)
                .background(
                    Capsule().fill(
                        prominent
                            ? Color.white.opacity(hovering ? 1 : 0.9)
                            : (hovering ? Theme.surfaceActive : Theme.surfaceHover)
                    )
                )
                .contentShape(Capsule())
                .opacity(configuration.isPressed ? 0.7 : 1)
                .onHover { hovering = $0 }
                .animation(Theme.contentAnimation, value: hovering)
        }
    }
}

// MARK: - Formatting

func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "--:--" }
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}

/// "4 min", "2 hr", "3 days" — one unit, in the panel's language.
func shortAge(since date: Date, now: Date = Date()) -> String {
    let formatter = DateComponentsFormatter()
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: appLanguage)
    formatter.calendar = calendar
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 1
    formatter.allowedUnits = [.minute, .hour, .day]
    return formatter.string(from: max(60, now.timeIntervalSince(date))) ?? ""
}
