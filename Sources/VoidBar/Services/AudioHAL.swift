import AudioToolbox
import CoreAudio
import Foundation

/// Thin, typed access to the Core Audio hardware layer: devices, volume,
/// mute, the default devices, and the processes that are making sound.
///
/// Everything here is a property read or write on an `AudioObjectID`; it is
/// cheap, synchronous, and safe to call from the main thread.
enum AudioHAL {
    struct Device: Identifiable, Equatable, Hashable {
        let id: AudioObjectID
        let uid: String
        let name: String
        let transport: UInt32

        /// SF Symbol for the kind of device.
        var symbol: String {
            switch transport {
            case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
                let lower = name.lowercased()
                return lower.contains("airpods") ? "airpods" : "headphones"
            case kAudioDeviceTransportTypeAirPlay: return "airplayaudio"
            case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "tv"
            case kAudioDeviceTransportTypeUSB: return "hifispeaker"
            case kAudioDeviceTransportTypeBuiltIn:
                return name.lowercased().contains("microphone") ? "mic" : "laptopcomputer"
            default: return "speaker.wave.2"
            }
        }
    }

    enum Direction {
        case output, input
        var scope: AudioObjectPropertyScope {
            self == .output ? kAudioObjectPropertyScopeOutput : kAudioObjectPropertyScopeInput
        }
        var defaultSelector: AudioObjectPropertySelector {
            self == .output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice
        }
    }

    // MARK: - Generic property access

    static func address(
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        _ element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func get<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, initial: T) -> T? {
        var value = initial
        var address = address
        var size = UInt32(MemoryLayout<T>.size)
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    @discardableResult
    static func set<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, _ value: T) -> Bool {
        var value = value
        var address = address
        let size = UInt32(MemoryLayout<T>.size)
        return AudioObjectSetPropertyData(object, &address, 0, nil, size, &value) == noErr
    }

    static func isSettable(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(object, &address) else { return false }
        return AudioObjectIsPropertySettable(object, &address, &settable) == noErr && settable.boolValue
    }

    static func objectList(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> [AudioObjectID] {
        var address = address
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr,
              let value else { return nil }
        return value.takeRetainedValue() as String
    }

    // MARK: - Devices

    static func devices(_ direction: Direction) -> [Device] {
        objectList(AudioObjectID(kAudioObjectSystemObject), address(kAudioHardwarePropertyDevices))
            .filter { hasStreams($0, direction) && !isHidden($0) }
            .compactMap { id in
                guard let uid = string(id, kAudioDevicePropertyDeviceUID),
                      let name = string(id, kAudioObjectPropertyName) else { return nil }
                let transport = get(id, address(kAudioDevicePropertyTransportType), initial: UInt32(0)) ?? 0
                return Device(id: id, uid: uid, name: name, transport: transport)
            }
            // VoidBar's own private aggregate devices never belong in a picker.
            .filter { !$0.uid.hasPrefix("dev.xand0.VoidBar.") }
    }

    private static func hasStreams(_ device: AudioObjectID, _ direction: Direction) -> Bool {
        var address = address(kAudioDevicePropertyStreams, direction.scope)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func isHidden(_ device: AudioObjectID) -> Bool {
        (get(device, address(kAudioDevicePropertyIsHidden), initial: UInt32(0)) ?? 0) != 0
    }

    static func defaultDevice(_ direction: Direction) -> AudioObjectID? {
        get(AudioObjectID(kAudioObjectSystemObject), address(direction.defaultSelector), initial: AudioObjectID(0))
            .flatMap { $0 == kAudioObjectUnknown ? nil : $0 }
    }

    @discardableResult
    static func setDefaultDevice(_ device: AudioObjectID, _ direction: Direction) -> Bool {
        let system = AudioObjectID(kAudioObjectSystemObject)
        let ok = set(system, address(direction.defaultSelector), device)
        // Alerts and UI sounds follow the main output, as macOS does when the
        // device is chosen in Control Center.
        if direction == .output {
            set(system, address(kAudioHardwarePropertyDefaultSystemOutputDevice), device)
        }
        return ok
    }

    // MARK: - Volume and mute

    /// 0…1, or nil if the device has no volume control (some HDMI outputs).
    static func volume(_ device: AudioObjectID, _ direction: Direction) -> Float? {
        get(device, address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, direction.scope), initial: Float32(0))
    }

    static func canSetVolume(_ device: AudioObjectID, _ direction: Direction) -> Bool {
        isSettable(device, address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, direction.scope))
    }

    @discardableResult
    static func setVolume(_ device: AudioObjectID, _ direction: Direction, _ value: Float) -> Bool {
        set(device, address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, direction.scope),
            Float32(min(max(value, 0), 1)))
    }

    static func isMuted(_ device: AudioObjectID, _ direction: Direction) -> Bool? {
        get(device, address(kAudioDevicePropertyMute, direction.scope), initial: UInt32(0)).map { $0 != 0 }
    }

    @discardableResult
    static func setMuted(_ device: AudioObjectID, _ direction: Direction, _ muted: Bool) -> Bool {
        set(device, address(kAudioDevicePropertyMute, direction.scope), UInt32(muted ? 1 : 0))
    }

    // MARK: - Processes making sound

    struct AudioProcess: Equatable {
        let object: AudioObjectID
        let pid: pid_t
        let bundleID: String?
        let isPlaying: Bool
    }

    /// Every process Core Audio knows about that can output sound, with
    /// whether it is outputting right now.
    static func processes() -> [AudioProcess] {
        objectList(AudioObjectID(kAudioObjectSystemObject), address(kAudioHardwarePropertyProcessObjectList))
            .compactMap { object in
                guard let pid = get(object, address(kAudioProcessPropertyPID), initial: pid_t(0)), pid > 0 else { return nil }
                let playing = (get(object, address(kAudioProcessPropertyIsRunningOutput), initial: UInt32(0)) ?? 0) != 0
                return AudioProcess(
                    object: object,
                    pid: pid,
                    bundleID: string(object, kAudioProcessPropertyBundleID),
                    isPlaying: playing
                )
            }
    }

    // MARK: - Change notifications

    /// Calls `handler` on the main queue whenever the property changes.
    /// Returns a token for `removeListener`.
    static func addListener(
        _ object: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        _ handler: @escaping () -> Void
    ) -> AudioObjectPropertyListenerBlock? {
        var address = address
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        let status = AudioObjectAddPropertyListenerBlock(object, &address, DispatchQueue.main, block)
        return status == noErr ? block : nil
    }

    static func removeListener(
        _ object: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        _ block: @escaping AudioObjectPropertyListenerBlock
    ) {
        var address = address
        AudioObjectRemovePropertyListenerBlock(object, &address, DispatchQueue.main, block)
    }
}
