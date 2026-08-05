import AppKit
import Foundation

/// Reads the Now Playing state and turns it into snapshots using MediaRemote directly.
@MainActor
final class NowPlayingFeed {
    struct Snapshot {
        var isPlaying = false
        var title = ""
        var artist = ""
        var album = ""
        var duration: TimeInterval = 0
        var elapsed: TimeInterval = 0
        var rate: Double = 0
        var artwork: Data?
        var source: String?

        var isEmpty: Bool { title.isEmpty }
    }

    enum Command: Int {
        case play = 0, pause = 1, togglePlayPause = 2, next = 4, previous = 5
    }

    var onUpdate: ((Snapshot) -> Void)?
    var onUnavailable: (() -> Void)?

    typealias RegisterType = @convention(c) (DispatchQueue) -> Void
    typealias GetInfoType = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    typealias SendCommandType = @convention(c) (UInt32, [String: Any]?) -> Void
    
    // MRNowPlayingClientGetBundleIdentifier
    // void *client; CFStringRef bundleID = MRNowPlayingClientGetBundleIdentifier(client);
    
    private let getInfo: GetInfoType?
    private let registerFunc: RegisterType?
    private let sendCommandFunc: SendCommandType?

    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        if let handle = handle {
            let symGetInfo = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo")
            getInfo = symGetInfo != nil ? unsafeBitCast(symGetInfo, to: GetInfoType.self) : nil
            
            let symRegister = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications")
            registerFunc = symRegister != nil ? unsafeBitCast(symRegister, to: RegisterType.self) : nil
            
            let symSendCmd = dlsym(handle, "MRMediaRemoteSendCommand")
            sendCommandFunc = symSendCmd != nil ? unsafeBitCast(symSendCmd, to: SendCommandType.self) : nil
        } else {
            getInfo = nil
            registerFunc = nil
            sendCommandFunc = nil
        }
    }

    func start() {
        guard let registerFunc = registerFunc, let _ = getInfo else {
            DispatchQueue.main.async { [weak self] in self?.onUnavailable?() }
            return
        }

        registerFunc(DispatchQueue.main)
        
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        nc.addObserver(forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        nc.addObserver(forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        
        refresh()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
    }

    func refresh() {
        guard let getInfo = getInfo else { return }
        
        getInfo(DispatchQueue.main) { [weak self] info in
            guard let self = self else { return }
            var snap = Snapshot()
            
            snap.title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            snap.artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            snap.album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            snap.duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 0
            snap.elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0
            snap.rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            snap.artwork = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            
            // To be safe, if we have rate > 0, we can consider it playing
            snap.isPlaying = snap.rate > 0
            
            self.onUpdate?(snap)
        }
    }

    func send(_ command: Command) {
        sendCommandFunc?(UInt32(command.rawValue), nil)
    }

    func seek(to seconds: TimeInterval) {
        // 18 is kMRMediaRemoteCommandSeekToPlaybackPosition
        sendCommandFunc?(18, ["kMRMediaRemoteOptionPlaybackPosition": seconds])
    }
}
