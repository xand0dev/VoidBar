import AppKit
import CoreAudio
import SwiftUI

/// The sound mixer: output and input devices, the system and microphone
/// volume, and a volume for each app that plays sound.
///
/// System volume, mute, and devices are plain Core Audio properties. Per-app
/// volume needs a process tap (`AppVolumeTap`), which exists only while an
/// app is set to something other than 100% or muted — an untouched app is
/// never intercepted. App levels are remembered by bundle ID and applied
/// again whenever the app makes sound.
@MainActor
final class SoundStore: ObservableObject {
    struct AppAudio: Identifiable, Equatable {
        /// The owning app's bundle ID — helper processes are folded into it.
        let id: String
        let name: String
        let icon: NSImage?
        var isPlaying: Bool
        var processObjects: [AudioObjectID]
        var gain: Double
        var muted: Bool

        static func == (a: AppAudio, b: AppAudio) -> Bool {
            a.id == b.id && a.isPlaying == b.isPlaying && a.processObjects == b.processObjects
                && a.gain == b.gain && a.muted == b.muted
        }
    }

    @Published private(set) var outputs: [AudioHAL.Device] = []
    @Published private(set) var inputs: [AudioHAL.Device] = []
    @Published private(set) var output: AudioHAL.Device?
    @Published private(set) var input: AudioHAL.Device?
    @Published private(set) var volume: Double = 0
    @Published private(set) var muted = false
    @Published private(set) var volumeSettable = true
    @Published private(set) var inputVolume: Double = 0
    @Published private(set) var inputMuted = false
    @Published private(set) var apps: [AppAudio] = []
    /// Set when a per-app tap could not be created — almost always the
    /// "System Audio Recording" permission.
    @Published private(set) var tapProblem: String?

    private var taps: [String: AppVolumeTap] = [:]
    private var tappedOutputUID: String?
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    /// Apps stay listed for a while after they fall silent, so a pause does
    /// not make the row jump away under the pointer.
    private var lastHeard: [String: Date] = [:]
    private let linger: TimeInterval = 45

    private let defaults: UserDefaults
    private let gainsKey = "sound.appGains"
    private let mutedKey = "sound.appMuted"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Lifecycle

    func start() {
        refresh()
        let system = AudioObjectID(kAudioObjectSystemObject)
        for selector in [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyProcessObjectList,
        ] {
            let address = AudioHAL.address(selector)
            if let block = AudioHAL.addListener(system, address, { [weak self] in
                MainActor.assumeIsolated { self?.refresh() }
            }) {
                listeners.append((system, address, block))
            }
        }
    }

    func stop() {
        for (object, address, block) in listeners {
            AudioHAL.removeListener(object, address, block)
        }
        listeners.removeAll()
        taps.removeAll()
    }

    /// Re-reads everything; cheap enough to call every second while the
    /// Sound tab is on screen, which also catches the volume keys.
    func refresh() {
        let outs = AudioHAL.devices(.output)
        let ins = AudioHAL.devices(.input)
        if outs != outputs { outputs = outs }
        if ins != inputs { inputs = ins }

        let outID = AudioHAL.defaultDevice(.output)
        let newOutput = outs.first { $0.id == outID }
        if newOutput != output { output = newOutput }
        if let device = newOutput {
            let current = Double(AudioHAL.volume(device.id, .output) ?? 0)
            if abs(current - volume) > 0.001 { volume = current }
            let isMuted = AudioHAL.isMuted(device.id, .output) ?? false
            if isMuted != muted { muted = isMuted }
            let settable = AudioHAL.canSetVolume(device.id, .output)
            if settable != volumeSettable { volumeSettable = settable }
        }

        let inID = AudioHAL.defaultDevice(.input)
        let newInput = ins.first { $0.id == inID }
        if newInput != input { input = newInput }
        if let device = newInput {
            let current = Double(AudioHAL.volume(device.id, .input) ?? 0)
            if abs(current - inputVolume) > 0.001 { inputVolume = current }
            let isMuted = AudioHAL.isMuted(device.id, .input) ?? false
            if isMuted != inputMuted { inputMuted = isMuted }
        }

        refreshApps()
        reconcileTaps()
    }

    // MARK: - System controls

    func setVolume(_ value: Double) {
        guard let output else { return }
        if muted, value > 0 { setMuted(false) }
        AudioHAL.setVolume(output.id, .output, Float(value))
        volume = value
    }

    func setMuted(_ value: Bool) {
        guard let output else { return }
        AudioHAL.setMuted(output.id, .output, value)
        muted = value
    }

    func select(output device: AudioHAL.Device) {
        AudioHAL.setDefaultDevice(device.id, .output)
        refresh()
    }

    func select(input device: AudioHAL.Device) {
        AudioHAL.setDefaultDevice(device.id, .input)
        refresh()
    }

    func setInputVolume(_ value: Double) {
        guard let input else { return }
        AudioHAL.setVolume(input.id, .input, Float(value))
        inputVolume = value
    }

    func setInputMuted(_ value: Bool) {
        guard let input else { return }
        AudioHAL.setMuted(input.id, .input, value)
        inputMuted = value
    }

    // MARK: - Apps

    func setGain(_ value: Double, for app: AppAudio) {
        var gains = savedGains
        gains[app.id] = abs(value - 1) < 0.01 ? nil : value
        defaults.set(gains, forKey: gainsKey)
        update(app.id) { $0.gain = abs(value - 1) < 0.01 ? 1 : value }
        reconcileTaps()
    }

    func setMuted(_ value: Bool, for app: AppAudio) {
        var mutedApps = Set(defaults.stringArray(forKey: mutedKey) ?? [])
        if value { mutedApps.insert(app.id) } else { mutedApps.remove(app.id) }
        defaults.set(Array(mutedApps), forKey: mutedKey)
        update(app.id) { $0.muted = value }
        reconcileTaps()
    }

    /// Back to 100% and unmuted: the tap goes away entirely.
    func reset(_ app: AppAudio) {
        setMuted(false, for: app)
        setGain(1, for: app)
    }

    private var savedGains: [String: Double] {
        (defaults.dictionary(forKey: gainsKey) as? [String: Double]) ?? [:]
    }

    private func update(_ id: String, _ change: (inout AppAudio) -> Void) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        change(&apps[index])
    }

    private func refreshApps() {
        let gains = savedGains
        let mutedApps = Set(defaults.stringArray(forKey: mutedKey) ?? [])
        let now = Date()
        let own = Bundle.main.bundleIdentifier

        var groups: [String: AppAudio] = [:]
        for process in AudioHAL.processes() {
            guard let owner = Self.owner(of: process), owner.id != own else { continue }
            if process.isPlaying { lastHeard[owner.id] = now }
            var group = groups[owner.id] ?? AppAudio(
                id: owner.id, name: owner.name, icon: owner.icon, isPlaying: false, processObjects: [],
                gain: gains[owner.id] ?? 1, muted: mutedApps.contains(owner.id)
            )
            group.isPlaying = group.isPlaying || process.isPlaying
            group.processObjects.append(process.object)
            groups[owner.id] = group
        }

        let shown = groups.values.filter { app in
            app.isPlaying || app.gain != 1 || app.muted
                || now.timeIntervalSince(lastHeard[app.id] ?? .distantPast) < linger
        }
        let sorted = shown.sorted { a, b in
            if a.isPlaying != b.isPlaying { return a.isPlaying }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        if sorted != apps { apps = sorted }
    }

    /// The app a sound-producing process belongs to. Browsers and Electron
    /// apps play sound from helper processes; those fold into the app whose
    /// bundle ID prefixes theirs, and WebKit's into Safari.
    static func owner(of process: AudioHAL.AudioProcess) -> (id: String, name: String, icon: NSImage?)? {
        let regular = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        if let app = NSRunningApplication(processIdentifier: process.pid),
           app.activationPolicy == .regular, let id = app.bundleIdentifier {
            return (id, app.localizedName ?? id, app.icon)
        }
        guard let bundle = process.bundleID, !bundle.isEmpty else { return nil }
        if let parent = parentApp(for: bundle, among: regular.compactMap { app in
            app.bundleIdentifier.map { (id: $0, name: app.localizedName ?? $0, icon: app.icon) }
        }) {
            return parent
        }
        // Background system processes (alerts, Siri, …) are left out: they
        // are not something one turns down per app.
        return nil
    }

    /// Pure part of `owner(of:)`, for tests.
    static func parentApp(
        for bundle: String,
        among apps: [(id: String, name: String, icon: NSImage?)]
    ) -> (id: String, name: String, icon: NSImage?)? {
        if let exact = apps.first(where: { $0.id == bundle }) { return exact }
        if let parent = apps
            .filter({ bundle.hasPrefix($0.id + ".") })
            .max(by: { $0.id.count < $1.id.count }) {
            return parent
        }
        if bundle.hasPrefix("com.apple.WebKit"), let safari = apps.first(where: { $0.id == "com.apple.Safari" }) {
            return safari
        }
        return nil
    }

    // MARK: - Taps

    private func reconcileTaps() {
        guard let outputUID = output?.uid else {
            taps.removeAll()
            return
        }
        // A new output device means every tap must play somewhere else.
        if tappedOutputUID != outputUID {
            taps.removeAll()
            tappedOutputUID = outputUID
        }

        var wanted = Set<String>()
        for app in apps where (app.gain != 1 || app.muted) && !app.processObjects.isEmpty {
            wanted.insert(app.id)
            let effective = Float(app.muted ? 0 : app.gain)
            if let tap = taps[app.id], Set(tap.processObjects) == Set(app.processObjects) {
                tap.setGain(effective)
                continue
            }
            taps[app.id] = nil
            do {
                let tap = try AppVolumeTap(processObjects: app.processObjects, outputUID: outputUID, name: app.name)
                tap.setGain(effective)
                taps[app.id] = tap
                if tapProblem != nil { tapProblem = nil }
            } catch {
                tapProblem = localized("Allow VoidBar under System Audio Recording to change app volumes.")
            }
        }
        for id in taps.keys where !wanted.contains(id) {
            taps[id] = nil
        }
    }

    static func openAudioCapturePrivacy() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")
            ?? URL(string: "x-apple.systempreferences:com.apple.preference.security")!
        NSWorkspace.shared.open(url)
    }
}
