import AppKit
import Combine

@MainActor
final class TeleprompterStore: ObservableObject {
    @Published var text: String = ""
    @Published var isPlaying: Bool = false
    @Published var speed: Double = 1.0 // Lines per second roughly, or offset per frame
    
    init() {
        let saved = UserDefaults.standard.string(forKey: "teleprompterText") ?? ""
        self.text = saved.isEmpty ? "Paste your script here..." : saved
    }
    
    func flush() {
        UserDefaults.standard.set(text, forKey: "teleprompterText")
    }
}
