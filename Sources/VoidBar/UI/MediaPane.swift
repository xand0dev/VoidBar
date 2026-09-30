import SwiftUI
import CoreImage

struct MediaPane: View {
    @ObservedObject var media: MediaController

    @State private var scrubHover = false
    /// Set while dragging, so the bar follows the finger instead of the clock.
    @State private var scrubbing: Double?
    /// The artwork's average colour, which tints the light behind it.
    @State private var glow: Color?

    /// Artwork and the text column share this height, so their top and bottom
    /// edges line up instead of the column floating past them.
    private let blockHeight: CGFloat = 128

    var body: some View {
        if let track = media.track {
            HStack(spacing: 18) {
                artwork(for: track)
                VStack(alignment: .leading, spacing: 0) {
                    Text(track.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                    Text(subtitle(for: track))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                        .padding(.top, 3)

                    Spacer(minLength: 6)
                    controls
                    Spacer(minLength: 6)
                    scrubber
                }
                .frame(height: blockHeight)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(alignment: .leading) { ambientLight }
            // Title and artist arrive together, so the whole column can cross-
            // fade as one unit when the track changes.
            .animation(Theme.artworkAnimation, value: track.key)
            .onAppear { glow = media.artwork.flatMap(ArtworkTint.average) }
            .onChange(of: media.artwork) { _, image in
                withAnimation(Theme.artworkAnimation) { glow = image.flatMap(ArtworkTint.average) }
            }
        } else {
            EmptyState(symbol: "music.note", title: localized("Nothing is playing"))
        }
    }

    /// The system often repeats the title as the album name; showing
    /// "Artist — Title" twice reads like a bug.
    private func subtitle(for track: MediaController.Track) -> String {
        var parts = [track.artist]
        if !track.album.isEmpty, track.album != track.title { parts.append(track.album) }
        return parts.filter { !$0.isEmpty }.joined(separator: " — ")
    }

    // MARK: - Artwork

    /// Soft light in the cover's own colour, spilling from behind it — the
    /// panel takes on the mood of what is playing without a single extra word.
    private var ambientLight: some View {
        RadialGradient(
            colors: [(glow ?? .clear).opacity(0.34), .clear],
            center: UnitPoint(x: 0.12, y: 0.5),
            startRadius: 4,
            endRadius: 230
        )
        .allowsHitTesting(false)
    }

    private func artwork(for track: MediaController.Track) -> some View {
        ZStack {
            if let image = media.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                SkeletonBox(cornerRadius: 16)
            }
        }
        .frame(width: blockHeight, height: blockHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
        .animation(Theme.artworkAnimation, value: media.artwork)
    }

    // MARK: - Scrubber

    private var progress: Double {
        if let scrubbing { return scrubbing }
        guard media.duration > 0 else { return 0 }
        return min(max(media.position / media.duration, 0), 1)
    }

    private var scrubber: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let width = geo.size.width
                let filled = width * progress
                let height: CGFloat = scrubHover ? 7 : 5

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12)).frame(height: height)
                    // Deliberately unanimated: a seek has to land under the
                    // cursor at once. Smoothness comes from the tick rate
                    // instead, which keeps each step well under a pixel.
                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: filled, height: height)
                    if scrubHover {
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .offset(x: min(max(filled - 6, 0), width - 12))
                            .shadow(color: .black.opacity(0.4), radius: 3)
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onHover { scrubHover = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard width > 0 else { return }
                            scrubbing = min(max(value.location.x / width, 0), 1)
                        }
                        .onEnded { value in
                            guard width > 0 else { return }
                            let target = min(max(value.location.x / width, 0), 1)
                            // Seek first: clearing `scrubbing` beforehand would
                            // drop the bar back to the old position for a frame
                            // before the new one lands.
                            media.seek(to: media.duration * target)
                            scrubbing = nil
                        }
                )
                .animation(Theme.contentAnimation, value: scrubHover)
            }
            .frame(height: 12)

            HStack {
                Text(formatTime(progress * media.duration))
                Spacer()
                Text("-" + formatTime(max(0, media.duration - progress * media.duration)))
            }
            .font(Theme.numeral(10, weight: .medium))
            .foregroundStyle(Theme.tertiary)
        }
    }

    // MARK: - Transport

    private var controls: some View {
        HStack(spacing: 22) {
            Button {
                media.previous()
                HapticManager.play(.alignment)
            } label: { Image(systemName: "backward.fill") }
                .buttonStyle(NotchButtonStyle(size: 34))
            Button {
                media.togglePlayPause()
                HapticManager.play(.alignment)
            } label: {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(NotchButtonStyle(size: 42, prominent: true))
            Button {
                media.next()
                HapticManager.play(.alignment)
            } label: { Image(systemName: "forward.fill") }
                .buttonStyle(NotchButtonStyle(size: 34))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Average colour of a cover, brightened a little so dark artwork still gives
/// off some light.
enum ArtworkTint {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func average(_ image: NSImage) -> Color? {
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
        return Color(hue: hue, saturation: min(1, saturation * 1.2), brightness: max(0.55, brightness))
    }
}
