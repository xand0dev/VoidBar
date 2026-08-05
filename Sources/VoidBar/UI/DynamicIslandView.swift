import SwiftUI

struct DynamicIslandView: View {
    @ObservedObject var vm: NotchViewModel
    
    // The width of the actual physical notch
    private var notchWidth: CGFloat { vm.geometry.notchSize.width }
    // The height of the physical notch
    private var notchHeight: CGFloat { vm.geometry.notchSize.height }
    
    // Animation for equalizer
    @State private var phase: CGFloat = 0

    var body: some View {
        // We position the islands exactly outside the physical notch width.
        // We are drawing inside a frame that is `size.width + 2*topRadius` wide.
        // The center of this frame corresponds to the center of the notch.
        
        ZStack {
            if vm.media.isPlaying {
                if vm.geometry.isPhysical {
                    // Left Wing (Equalizer / Icon)
                    HStack {
                        Spacer() // push to right edge of the left wing
                        EqualizerBars(isAnimating: true)
                            .padding(.trailing, 10)
                    }
                    .frame(width: 44, height: notchHeight)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
                    .offset(x: -notchWidth / 2 - 22 + 8) // Overlap slightly to merge with notch
                    
                    // Right Wing (Timer / Source)
                    HStack {
                        if vm.media.track != nil {
                            // Very simple static text for now, ideally an updating timer
                            Text(formatTime(vm.media.position))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundColor(Color.white)
                                .padding(.leading, 10)
                        }
                        Spacer()
                    }
                    .frame(width: 44, height: notchHeight)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
                    .offset(x: notchWidth / 2 + 22 - 8)
                } else {
                    // Unified Pill for non-notched screens
                    HStack(spacing: 8) {
                        EqualizerBars(isAnimating: true)
                        
                        if vm.media.track != nil {
                            Text(formatTime(vm.media.position))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundColor(Color.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: notchHeight)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
                    // When unified, it just floats in the center
                }
            }
        }
        .frame(width: notchWidth, height: notchHeight) // Center aligns with notch
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.media.isPlaying)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
