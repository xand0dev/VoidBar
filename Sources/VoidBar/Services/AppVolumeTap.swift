import AudioToolbox
import CoreAudio
import Foundation

/// Per-app volume through a Core Audio process tap (macOS 14.2+).
///
/// The tap captures an app's sound and mutes the original; a private
/// aggregate device built around the current output plays the captured
/// sound back, multiplied by the app's gain. Nothing is recorded or kept:
/// samples go straight from the tap to the speakers inside one IO callback.
///
/// A tap exists only while an app's volume is not 100% or it is muted. The
/// first one prompts macOS's "capture audio from other apps" permission.
/// When VoidBar quits — or crashes — the system removes the tap and the
/// app's own sound comes back at full volume.
final class AppVolumeTap {
    enum Failure: Error {
        case tap(OSStatus)
        case aggregate(OSStatus)
        case ioProc(OSStatus)
        case start(OSStatus)
        case noOutput
    }

    /// Read from the real-time audio thread; written from the main thread.
    /// A single `Float` store is atomic on Apple silicon, so the audio thread
    /// sees either the old or the new gain, never a torn value.
    private final class Gain: @unchecked Sendable {
        var value: Float = 1
    }

    let processObjects: [AudioObjectID]
    private let gain = Gain()
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "dev.xand0.VoidBar.app-volume", qos: .userInteractive)

    init(processObjects: [AudioObjectID], outputUID: String, name: String) throws {
        self.processObjects = processObjects

        let description = CATapDescription(stereoMixdownOfProcesses: processObjects)
        description.uuid = UUID()
        description.name = "VoidBar \(name)"
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped

        var tap = AudioObjectID(kAudioObjectUnknown)
        let tapStatus = AudioHardwareCreateProcessTap(description, &tap)
        guard tapStatus == noErr else { throw Failure.tap(tapStatus) }
        tapID = tap

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "VoidBar \(name)",
            kAudioAggregateDeviceUIDKey: "dev.xand0.VoidBar.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        var device = AudioObjectID(kAudioObjectUnknown)
        let aggregateStatus = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &device)
        guard aggregateStatus == noErr else {
            teardown()
            throw Failure.aggregate(aggregateStatus)
        }
        aggregateID = device

        let gain = self.gain
        var procID: AudioDeviceIOProcID?
        let procStatus = AudioDeviceCreateIOProcIDWithBlock(&procID, device, queue) { _, input, _, output, _ in
            AppVolumeTap.render(from: input, to: output, gain: gain.value)
        }
        guard procStatus == noErr, let procID else {
            teardown()
            throw Failure.ioProc(procStatus)
        }
        ioProcID = procID

        let startStatus = AudioDeviceStart(device, procID)
        guard startStatus == noErr else {
            teardown()
            throw Failure.start(startStatus)
        }
    }

    deinit { teardown() }

    /// 0…1.5 — above 1 boosts quiet apps; 0 is silence.
    func setGain(_ value: Float) {
        gain.value = min(max(value, 0), 1.5)
    }

    private func teardown() {
        if aggregateID != kAudioObjectUnknown {
            if let ioProcID {
                AudioDeviceStop(aggregateID, ioProcID)
                AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        ioProcID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    // MARK: - Rendering

    /// Copies the tapped sound to the output with a gain applied, whatever the
    /// buffer layouts: interleaved or not, any channel counts. Output channels
    /// beyond the input's repeat its last channel; missing input is silence.
    /// Allocation-free — it runs on the real-time audio thread.
    static func render(
        from input: UnsafePointer<AudioBufferList>,
        to output: UnsafeMutablePointer<AudioBufferList>,
        gain: Float
    ) {
        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outputs = UnsafeMutableAudioBufferListPointer(output)

        var inputChannels = 0
        for buffer in inputs { inputChannels += Int(buffer.mNumberChannels) }

        var outputChannel = 0
        for index in 0..<outputs.count {
            let out = outputs[index]
            guard let outData = out.mData?.assumingMemoryBound(to: Float.self) else { continue }
            let outStride = max(Int(out.mNumberChannels), 1)
            let outFrames = Int(out.mDataByteSize) / (MemoryLayout<Float>.size * outStride)

            for channel in 0..<outStride {
                let source = inputChannels == 0 ? -1 : min(outputChannel + channel, inputChannels - 1)
                var frames = outFrames
                var inData: UnsafeMutablePointer<Float>?
                var inStride = 1
                var inOffset = 0
                if source >= 0 {
                    // Find the buffer and position of input channel `source`.
                    var remaining = source
                    for buffer in inputs {
                        let channels = Int(buffer.mNumberChannels)
                        if remaining < channels {
                            inData = buffer.mData?.assumingMemoryBound(to: Float.self)
                            inStride = max(channels, 1)
                            inOffset = remaining
                            frames = min(frames, Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * inStride))
                            break
                        }
                        remaining -= channels
                    }
                }
                for frame in 0..<outFrames {
                    let sample: Float
                    if let inData, frame < frames {
                        sample = inData[frame * inStride + inOffset] * gain
                    } else {
                        sample = 0
                    }
                    outData[frame * outStride + channel] = sample
                }
            }
            outputChannel += outStride
        }
    }
}
