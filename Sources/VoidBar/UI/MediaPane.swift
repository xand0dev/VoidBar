import SwiftUI

struct MediaPane: View {
    @ObservedObject var media: MediaController

    @State private var scrubHover = false
    /// Set while dragging, so the bar follows the finger instead of the clock.
    @State private var scrubbing: Double?

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
    ///
    /// Centred on the cover and fully faded before any edge of the pane, which
    /// clips its content: light that reached an edge would draw a rectangle.
    private var ambientLight: some View {
        let tint = media.artworkPalette?.first ?? .clear
        return RadialGradient(
            stops: [
                .init(color: tint.opacity(0.42), location: 0),
                .init(color: tint.opacity(0.16), location: 0.5),
                .init(color: tint.opacity(0), location: 0.82),
            ],
            center: .center,
            startRadius: 0,
            endRadius: 82
        )
        .frame(width: 164, height: 164)
        .offset(x: 4 + blockHeight / 2 - 82)
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
