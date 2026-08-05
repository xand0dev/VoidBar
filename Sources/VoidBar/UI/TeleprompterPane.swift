import SwiftUI

struct TeleprompterPane: View {
    @ObservedObject var store: TeleprompterStore
    @FocusState private var isFocused: Bool
    
    // For auto-scrolling
    @State private var offset: CGFloat = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(localized("Teleprompter"))
                    .font(.headline)
                    .foregroundColor(Theme.secondary)
                
                Spacer()
                
                // Controls
                Slider(value: $store.speed, in: 0.2...3.0, step: 0.1)
                    .frame(width: 80)
                    .tint(Color.white)
                
                Button {
                    togglePlay()
                } label: {
                    Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(store.isPlaying ? Color.white : Theme.secondary)
                        .padding(6)
                        .background(Theme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Content
            ZStack(alignment: .top) {
                if store.isPlaying {
                    // Playing mode: Auto-scrolling text
                    GeometryReader { geo in
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(store.text)
                                .font(.system(size: 24, weight: .medium, design: .default))
                                .foregroundColor(Color.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.vertical, geo.size.height / 2) // Start from middle
                                .offset(y: -offset)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(true) // Disable manual scroll while playing
                    }
                } else {
                    // Edit mode: Standard TextEditor
                    TextEditor(text: $store.text)
                        .font(.system(size: 16))
                        .foregroundColor(Color.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 12)
                        .focused($isFocused)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .onDisappear {
            stopTimer()
        }
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
