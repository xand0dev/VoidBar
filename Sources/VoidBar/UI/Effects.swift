import SwiftUI
import CoreImage

// MARK: - Aurora

/// Slowly drifting light at the bottom of the open panel, in the colours of
/// whatever the panel is showing. It fades to pure black towards the top, so
/// the panel still reads as part of the notch where it meets the display.
struct Aurora: View {
    let colors: [Color]
    var intensity: Double = 0.5

    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                blob(colors[safe: 0] ?? Theme.accent, diameter: w * 0.62)
                    .offset(x: drift ? -w * 0.22 : -w * 0.34, y: drift ? h * 0.30 : h * 0.42)
                blob(colors[safe: 1] ?? Theme.accentDeep, diameter: w * 0.55)
                    .offset(x: drift ? w * 0.30 : w * 0.16, y: drift ? h * 0.46 : h * 0.34)
                blob(colors[safe: 2] ?? Theme.accent, diameter: w * 0.45)
                    .offset(x: drift ? w * 0.02 : w * 0.10, y: drift ? h * 0.52 : h * 0.60)
            }
            .frame(width: w, height: h)
        }
        .opacity(intensity)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.18),
                    .init(color: .black, location: 0.7),
                    .init(color: .black, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .animation(.easeInOut(duration: 1.2), value: colors)
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { drift = true }
        }
        .allowsHitTesting(false)
    }

    private func blob(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.9), color.opacity(0.35), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - Edge light

/// A band of light that runs once along the panel's edge as it opens.
struct EdgeSweep<S: Shape>: View {
    let shape: S
    @State private var progress: CGFloat = -0.3

    var body: some View {
        shape
            .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
            .mask(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.35)
                    .offset(x: geo.size.width * progress)
                }
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).delay(0.08)) { progress = 1.05 }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Reveal

/// Arrives with a short spring: fades in, rises, and settles to full size.
/// Staggering the delay across siblings turns an opening into a cascade.
struct Reveal: ViewModifier {
    let delay: Double
    var dx: CGFloat = 0
    var dy: CGFloat = 10

    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.94)
            .offset(x: shown ? 0 : dx, y: shown ? 0 : dy)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(delay)) { shown = true }
            }
    }
}

extension View {
    func reveal(delay: Double, dx: CGFloat = 0, dy: CGFloat = 10) -> some View {
        modifier(Reveal(delay: delay, dx: dx, dy: dy))
    }
}

// MARK: - Artwork colour

/// Average colour of a cover, brightened a little so dark artwork still gives
/// off some light.
enum ArtworkTint {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func average(_ image: NSImage) -> Color? {
        hsb(image).map { Color(hue: $0.h, saturation: $0.s, brightness: $0.b) }
    }

    /// The cover's colour and two neighbours on the colour wheel, for the aurora.
    static func palette(_ image: NSImage) -> [Color]? {
        guard let base = hsb(image) else { return nil }
        func shifted(_ amount: Double, brightness: Double) -> Color {
            var hue = base.h + amount
            if hue < 0 { hue += 1 }
            if hue > 1 { hue -= 1 }
            return Color(hue: hue, saturation: max(0.45, base.s), brightness: brightness)
        }
        return [
            Color(hue: base.h, saturation: max(0.45, base.s), brightness: base.b),
            shifted(0.09, brightness: min(1, base.b + 0.1)),
            shifted(-0.08, brightness: base.b * 0.85),
        ]
    }

    private static func hsb(_ image: NSImage) -> (h: Double, s: Double, b: Double)? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let input = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: input.extent),
        ]), let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        let color = NSColor(
            red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255, alpha: 1
        )
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (Double(hue), min(1, Double(saturation) * 1.2), max(0.55, Double(brightness)))
    }
}
