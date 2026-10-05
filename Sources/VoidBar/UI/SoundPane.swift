import SwiftUI

/// The mixer: where sound goes, how loud everything is, and how loud each
/// app is on its own.
struct SoundPane: View {
    @ObservedObject var sound: SoundStore
    /// The app that owns Now Playing, so the music is easy to find.
    let nowPlaying: String?

    var body: some View {
        HStack(spacing: 10) {
            system
                .frame(width: 252)
                .reveal(delay: 0.04)
            apps
                .reveal(delay: 0.09)
        }
        .padding(.top, 2)
        // Polled while on screen: catches the volume keys, Control Center,
        // and apps starting or stopping sound. Nothing runs once it is gone.
        .task {
            while !Task.isCancelled {
                sound.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - System

    private var system: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: localized("Output"))
                Spacer(minLength: 6)
                DeviceMenu(devices: sound.outputs, current: sound.output) { sound.select(output: $0) }
            }
            HStack(spacing: 9) {
                Button {
                    sound.setMuted(!sound.muted)
                } label: {
                    Image(systemName: speakerSymbol)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(NotchButtonStyle(size: 30))
                .help(sound.muted ? localized("Unmute") : localized("Mute"))
                VolumeSlider(
                    value: Binding(get: { sound.muted ? 0 : sound.volume }, set: { sound.setVolume($0) }),
                    range: 0...1,
                    tint: sound.muted ? Theme.tertiary : Theme.accent,
                    height: 8
                )
                .disabled(!sound.volumeSettable)
                Text("\(Int((sound.muted ? 0 : sound.volume) * 100))%")
                    .font(Theme.numeral(13))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 40, alignment: .trailing)
            }
            Spacer(minLength: 0)
            HStack {
                SectionLabel(text: localized("Microphone"))
                Spacer(minLength: 6)
                DeviceMenu(devices: sound.inputs, current: sound.input) { sound.select(input: $0) }
            }
            HStack(spacing: 9) {
                Button {
                    sound.setInputMuted(!sound.inputMuted)
                } label: {
                    Image(systemName: sound.inputMuted ? "mic.slash.fill" : "mic.fill")
                        .foregroundStyle(sound.inputMuted ? Theme.critical : .white)
                }
                .buttonStyle(NotchButtonStyle(size: 26))
                .help(sound.inputMuted ? localized("Unmute") : localized("Mute"))
                VolumeSlider(
                    value: Binding(get: { sound.inputVolume }, set: { sound.setInputVolume($0) }),
                    range: 0...1,
                    tint: sound.inputMuted ? Theme.tertiary : Color.white.opacity(0.85),
                    height: 5
                )
                Text("\(Int(sound.inputVolume * 100))%")
                    .font(Theme.numeral(11, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 12)
    }

    private var speakerSymbol: String {
        if sound.muted || sound.volume == 0 { return "speaker.slash.fill" }
        switch sound.volume {
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    // MARK: - Apps

    private var apps: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: localized("Apps"))
                Spacer()
                if sound.tapProblem != nil {
                    Button(localized("Allow")) { SoundStore.openAudioCapturePrivacy() }
                        .buttonStyle(PillButtonStyle(prominent: true))
                }
            }
            if let problem = sound.tapProblem {
                Text(problem)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if sound.apps.isEmpty {
                EmptyState(symbol: "music.note.house", title: localized("Apps playing sound appear here"))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(ordered) { app in
                            AppRow(app: app, isNowPlaying: app.name == nowPlaying, sound: sound)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .fadingBottomEdge(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 12)
    }

    /// The music first, then everything playing, then the quiet ones.
    private var ordered: [SoundStore.AppAudio] {
        sound.apps.sorted { a, b in
            let aMusic = a.name == nowPlaying, bMusic = b.name == nowPlaying
            if aMusic != bMusic { return aMusic }
            return false
        }
    }
}

// MARK: - Rows and controls

private struct AppRow: View {
    let app: SoundStore.AppAudio
    let isNowPlaying: Bool
    @ObservedObject var sound: SoundStore

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "app.fill").foregroundStyle(Theme.tertiary)
                }
            }
            .frame(width: 18, height: 18)
            .opacity(app.isPlaying ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(app.name)
                        .font(Theme.captionEmphasis)
                        .foregroundStyle(app.isPlaying ? Theme.primary : Theme.secondary)
                        .lineLimit(1)
                    if isNowPlaying {
                        Image(systemName: "music.note")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .frame(width: 92, alignment: .leading)

            VolumeSlider(
                value: Binding(get: { app.muted ? 0 : app.gain }, set: { value in
                    if app.muted { sound.setMuted(false, for: app) }
                    sound.setGain(value, for: app)
                }),
                range: 0...1.5,
                tint: app.muted ? Theme.tertiary : (app.gain > 1 ? Theme.warning : Theme.accent),
                height: 5,
                mark: 1
            )

            Button {
                sound.reset(app)
            } label: {
                Text("\(Int(((app.muted ? 0 : app.gain) * 100).rounded()))%")
                    .font(Theme.numeral(10.5, weight: .semibold))
                    .foregroundStyle(app.gain == 1 && !app.muted ? Theme.secondary : Theme.primary)
                    .frame(width: 36, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .help(localized("Back to 100%"))

            Button {
                sound.setMuted(!app.muted, for: app)
            } label: {
                Image(systemName: app.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(app.muted ? Theme.critical : .white)
            }
            .buttonStyle(NotchButtonStyle(size: 22))
            .help(app.muted ? localized("Unmute") : localized("Mute"))
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isNowPlaying ? Theme.accent.opacity(0.1) : Theme.surface)
        )
    }
}

/// Output or input device chooser.
private struct DeviceMenu: View {
    let devices: [AudioHAL.Device]
    let current: AudioHAL.Device?
    let choose: (AudioHAL.Device) -> Void

    var body: some View {
        Menu {
            ForEach(devices) { device in
                Button {
                    choose(device)
                } label: {
                    if device == current {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: current?.symbol ?? "speaker.wave.2")
                    .font(.system(size: 9.5, weight: .semibold))
                Text(current?.name ?? localized("None"))
                    .font(Theme.captionEmphasis)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Theme.tertiary)
            }
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(Theme.surfaceHover))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(devices.count < 2)
    }
}

/// A drag-anywhere capsule slider, with an optional mark (100% for apps).
struct VolumeSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var tint: Color = Theme.accent
    var height: CGFloat = 6
    var mark: Double?

    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let span = range.upperBound - range.lowerBound
            let fraction = CGFloat((min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / span)
            let thickness: CGFloat = hovering ? height + 2 : height
            let knob: CGFloat = thickness + 6
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1)).frame(height: thickness)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(thickness, width * fraction), height: thickness)
                if let mark {
                    let x = width * CGFloat((mark - range.lowerBound) / span)
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 1.5, height: thickness + 6)
                        .offset(x: x - 0.75)
                }
                Circle()
                    .fill(.white)
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(x: min(max(width * fraction - knob / 2, 0), width - knob))
                    .opacity(hovering ? 1 : 0)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering = $0 && isEnabled }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard width > 0, isEnabled else { return }
                        let position = Double(min(max(drag.location.x / width, 0), 1))
                        var raw = range.lowerBound + span * position
                        // Snap to the mark so 100% is easy to land on.
                        if let mark, abs(raw - mark) < span * 0.03 { raw = mark }
                        value = raw
                    }
            )
            .animation(Theme.contentAnimation, value: hovering)
        }
        .frame(height: 18)
        .opacity(isEnabled ? 1 : 0.4)
    }
}
