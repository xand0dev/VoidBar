import XCTest
import CoreAudio
@testable import VoidBar

final class SoundMixerTests: XCTestCase {
    // MARK: - Owner of a sound-producing process

    private let apps: [(id: String, name: String, icon: NSImage?)] = [
        ("com.google.Chrome", "Google Chrome", nil),
        ("com.apple.Safari", "Safari", nil),
        ("com.spotify.client", "Spotify", nil),
    ]

    @MainActor
    func testHelpersFoldIntoTheirApp() {
        XCTAssertEqual(SoundStore.parentApp(for: "com.google.Chrome.helper", among: apps)?.name, "Google Chrome")
        XCTAssertEqual(SoundStore.parentApp(for: "com.spotify.client.helper.renderer", among: apps)?.name, "Spotify")
        XCTAssertEqual(SoundStore.parentApp(for: "com.apple.WebKit.GPU", among: apps)?.name, "Safari")
        XCTAssertEqual(SoundStore.parentApp(for: "com.google.Chrome", among: apps)?.name, "Google Chrome")
        XCTAssertNil(SoundStore.parentApp(for: "com.apple.siri", among: apps))
        // A prefix that is not a component boundary is not a parent.
        XCTAssertNil(SoundStore.parentApp(for: "com.google.Chromecast", among: apps))
    }

    // MARK: - Rendering

    /// Builds an AudioBufferList over the given buffers (each [Float] with a
    /// channel count) and runs `body` with it.
    private func withBufferList(
        _ buffers: [(data: [Float], channels: Int)],
        _ body: (UnsafeMutablePointer<AudioBufferList>) -> Void
    ) -> [[Float]] {
        var storage = buffers.map(\.data)
        // A list must have room for one buffer even when it carries none.
        var list = AudioBufferList.allocate(maximumBuffers: max(buffers.count, 1))
        list.count = buffers.count
        defer { free(list.unsafeMutablePointer) }
        return storage.withUnsafeMutableBufferPointer { arrays in
            var pointers: [UnsafeMutablePointer<Float>] = []
            for index in 0..<arrays.count {
                let pointer = UnsafeMutablePointer<Float>.allocate(capacity: arrays[index].count)
                pointer.initialize(from: arrays[index], count: arrays[index].count)
                pointers.append(pointer)
                list[index] = AudioBuffer(
                    mNumberChannels: UInt32(buffers[index].channels),
                    mDataByteSize: UInt32(arrays[index].count * MemoryLayout<Float>.size),
                    mData: UnsafeMutableRawPointer(pointer)
                )
            }
            body(list.unsafeMutablePointer)
            let result = pointers.enumerated().map { index, pointer in
                Array(UnsafeBufferPointer(start: pointer, count: arrays[index].count))
            }
            pointers.forEach { $0.deallocate() }
            return result
        }
    }

    func testInterleavedStereoToSplitChannelsWithGain() {
        // Input: one interleaved stereo buffer, 3 frames: L R L R L R.
        let input: [(data: [Float], channels: Int)] = [([1, -1, 0.5, -0.5, 0.25, -0.25], 2)]
        var rendered: [[Float]] = []
        _ = withBufferList(input) { inList in
            rendered = withBufferList([([0, 0, 0], 1), ([0, 0, 0], 1)]) { outList in
                AppVolumeTap.render(from: UnsafePointer(inList), to: outList, gain: 0.5)
            }
        }
        XCTAssertEqual(rendered[0], [0.5, 0.25, 0.125])
        XCTAssertEqual(rendered[1], [-0.5, -0.25, -0.125])
    }

    func testMutedGainIsSilence() {
        let input: [(data: [Float], channels: Int)] = [([1, 1, 1, 1], 2)]
        var rendered: [[Float]] = []
        _ = withBufferList(input) { inList in
            rendered = withBufferList([([9, 9, 9, 9], 2)]) { outList in
                AppVolumeTap.render(from: UnsafePointer(inList), to: outList, gain: 0)
            }
        }
        XCTAssertEqual(rendered[0], [0, 0, 0, 0])
    }

    func testExtraOutputChannelsRepeatTheLastInputChannel() {
        // Mono-mixdown input, four output channels in one interleaved buffer.
        let input: [(data: [Float], channels: Int)] = [([0.2, 0.4], 1)]
        var rendered: [[Float]] = []
        _ = withBufferList(input) { inList in
            rendered = withBufferList([([Float](repeating: 0, count: 8), 4)]) { outList in
                AppVolumeTap.render(from: UnsafePointer(inList), to: outList, gain: 1)
            }
        }
        XCTAssertEqual(rendered[0], [0.2, 0.2, 0.2, 0.2, 0.4, 0.4, 0.4, 0.4])
    }

    func testMissingInputIsSilenceNotGarbage() {
        var rendered: [[Float]] = []
        _ = withBufferList([]) { inList in
            rendered = withBufferList([([7, 7], 2)]) { outList in
                AppVolumeTap.render(from: UnsafePointer(inList), to: outList, gain: 1)
            }
        }
        XCTAssertEqual(rendered[0], [0, 0])
    }

    // MARK: - Remembered levels

    @MainActor
    func testAppLevelsAreRemembered() {
        let suite = "dev.xand0.VoidBar.tests.sound.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SoundStore(defaults: defaults)
        let app = SoundStore.AppAudio(id: "com.google.Chrome", name: "Google Chrome", icon: nil, isPlaying: false,
                                      processObjects: [], gain: 1, muted: false)
        store.setGain(0.4, for: app)
        XCTAssertEqual((defaults.dictionary(forKey: "sound.appGains") as? [String: Double])?["com.google.Chrome"], 0.4)
        store.setGain(1.0, for: app)
        XCTAssertNil((defaults.dictionary(forKey: "sound.appGains") as? [String: Double])?["com.google.Chrome"],
                     "100% is the default and is not stored")
        store.setMuted(true, for: app)
        XCTAssertEqual(defaults.stringArray(forKey: "sound.appMuted"), ["com.google.Chrome"])
    }
}
