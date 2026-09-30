import Foundation

/// Claude Code status line command: `VoidBar --claude-statusline`.
///
/// Claude Code runs its status line command after each response and passes the
/// session as JSON on stdin; for Pro and Max subscribers that JSON includes the
/// five-hour and seven-day `rate_limits`. This is the only documented place
/// those numbers appear, so VoidBar offers itself as the command: it keeps the
/// limits — and nothing else from the session — in its own support folder for
/// the Usage tab, and prints a short line for Claude Code to show.
///
/// Runs before `NSApplication` starts and exits straight away.
enum ClaudeStatusBridge {
    static let argument = "--claude-statusline"

    static func run() -> Int32 {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let usage = AgentUsageParser.claudeStatusLine(input)
        // Absent limits (an API-key session, or before the first response) keep
        // the previous snapshot rather than erasing it.
        if let usage {
            try? AgentUsageFiles.writeClaude(usage)
        }
        print(line(for: input, usage: usage))
        return 0
    }

    /// "Opus 5.5 · 5h 23% · 7d 41%" — the model, then whichever limits exist.
    static func line(for input: Data, usage: AgentUsage?) -> String {
        var parts: [String] = []
        if let object = try? JSONSerialization.jsonObject(with: input) as? [String: Any],
           let model = object["model"] as? [String: Any],
           let name = model["display_name"] as? String, !name.isEmpty {
            parts.append(name)
        }
        if let session = usage?.session {
            parts.append("5h \(Int(session.usedPercent.rounded()))%")
        }
        if let weekly = usage?.weekly {
            parts.append("7d \(Int(weekly.usedPercent.rounded()))%")
        }
        return parts.isEmpty ? "VoidBar" : parts.joined(separator: " · ")
    }
}
