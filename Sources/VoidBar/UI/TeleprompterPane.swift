import SwiftUI

struct TeleprompterPane: View {
    @ObservedObject var store: TeleprompterStore
    @FocusState private var isFocused: Bool
    
    // For auto-scrolling
    @State private var offset: CGFloat = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                if store.isPlaying {
                    // Playing mode: auto-scrolling text, starting mid-card.
                    GeometryReader { geo in
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(store.text)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 20)
                                .padding(.vertical, geo.size.height / 2)
                                .offset(y: -offset)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(true) // No manual scrolling while playing.
                    }
                    // The reading line: text is sharpest at the middle.
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.3),
                                .init(color: .black, location: 0.7),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                } else {
                    TextEditor(text: $store.text)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.primary)
                        .lineSpacing(3)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.hidden)
                        .tint(Theme.accent)
                        .background(Color.clear)
                        .focused($isFocused)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .card(padding: 8)

            controls
        }
        .padding(.top, 2)
        .onDisappear {
            stopTimer()
        }
    }
    
    private var controls: some View {
        HStack(spacing: 8) {
            SectionLabel(text: localized("Speed"))
            Image(systemName: "tortoise.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiary)
            Slider(value: $store.speed, in: 0.2...3.0)
                .controlSize(.mini)
                .tint(Theme.accent)
                .frame(width: 130)
            Image(systemName: "hare.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiary)
            Spacer()
            Button {
                togglePlay()
            } label: {
                Label(
                    store.isPlaying ? localized("Pause") : localized("Play"),
                    systemImage: store.isPlaying ? "pause.fill" : "play.fill"
                )
            }
            .buttonStyle(PillButtonStyle(prominent: !store.isPlaying))
        }
        .frame(height: 24)
    }

    private func togglePlay() {
        store.isPlaying.toggle()
        if store.isPlaying {
            isFocused = false
            offset = 0 // Reset scroll
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        // 60 fps
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                offset += store.speed
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        store.isPlaying = false
    }
}
