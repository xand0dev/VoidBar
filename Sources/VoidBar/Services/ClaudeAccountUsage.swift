import Foundation
import Security

/// Claude plan limits read from the account itself — the numbers `/usage`
/// shows in Claude Code — fetched only when the user presses refresh.
///
/// The status line bridge only knows what the last response *in one terminal
/// session* said, so an idle session keeps reporting old numbers. The account
/// is the source of truth. Reaching it takes Claude Code's own sign-in, which
/// Claude Code keeps in the login Keychain; macOS asks the user before VoidBar
/// may read it. VoidBar never refreshes or rewrites that sign-in, so it cannot
/// get in Claude Code's way — an expired one is reported, and running `claude`
/// once renews it.
///
/// The usage endpoint is the one Claude Code itself calls and is not a
/// documented public API, so parsing accepts the field names it has used and
/// fails politely on anything else.
enum ClaudeAccountUsage {
    enum Failure: LocalizedError, Equatable {
        case notSignedIn
        case keychainDenied
        case expired
        case service(Int)
        case unreadable
        case offline

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return localized("Sign in to Claude Code in the terminal first (run claude).")
            case .keychainDenied: return localized("Keychain access was not allowed.")
            case .expired: return localized("Claude Code's sign-in has expired. Run claude once, then refresh.")
            case .service(let code): return localized("Claude's usage service answered %d.", code)
            case .unreadable: return localized("Claude's usage service sent something VoidBar could not read.")
            case .offline: return localized("Could not reach Claude's usage service.")
            }
        }
    }

    static let keychainService = "Claude Code-credentials"
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    struct Credentials: Equatable {
        var accessToken: String
        var expiresAt: Date?
        var plan: String?
    }

    /// Reads the sign-in and asks the account. Call off the main thread: the
    /// Keychain read can show a system dialog and blocks until it is answered.
    static func fetch(now: Date = Date()) async throws -> AgentUsage {
        let credentials = try readCredentials()
        if let expiresAt = credentials.expiresAt, expiresAt <= now { throw Failure.expired }

        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // No cookies, no cache: the request carries nothing but the header.
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Failure.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw Failure.expired }
        guard status == 200 else { throw Failure.service(status) }
        guard var usage = parse(data, now: now) else { throw Failure.unreadable }
        usage.plan = credentials.plan
        return usage
    }

    // MARK: - Keychain

    private static func readCredentials() throws -> Credentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess: break
        case errSecItemNotFound: throw Failure.notSignedIn
        default: throw Failure.keychainDenied
        }
        guard let data = item as? Data, let credentials = parseCredentials(data) else {
            throw Failure.notSignedIn
        }
        return credentials
    }

    /// Claude Code stores `{"claudeAiOauth": {"accessToken", "expiresAt", …}}`.
    static func parseCredentials(_ data: Data) -> Credentials? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let oauth = (object["claudeAiOauth"] as? [String: Any]) ?? object
        guard let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        let plan = (oauth["subscriptionType"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return Credentials(accessToken: token, expiresAt: date(oauth["expiresAt"]), plan: plan)
    }

    // MARK: - Parsing

    /// `five_hour` and `seven_day`, each with a percentage used and when it
    /// resets. Missing windows are left out; no window at all is a failure.
    static func parse(_ data: Data, now: Date) -> AgentUsage? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let session = window(object["five_hour"], minutes: 5 * 60)
        let weekly = window(object["seven_day"], minutes: 7 * 24 * 60)
        guard session != nil || weekly != nil else { return nil }
        return AgentUsage(session: session, weekly: weekly, plan: nil, recordedAt: now)
    }

    private static func window(_ value: Any?, minutes: Int) -> UsageWindow? {
        guard let dict = value as? [String: Any] else { return nil }
        let percent = ["utilization", "used_percentage", "usedPercent", "used_percent"]
            .lazy.compactMap { (dict[$0] as? NSNumber)?.doubleValue }.first
        guard let percent else { return nil }
        return UsageWindow(
            usedPercent: min(max(percent, 0), 100),
            resetsAt: date(dict["resets_at"] ?? dict["resetsAt"]),
            minutes: minutes
        )
    }

    /// ISO 8601 text, or Unix time in seconds or milliseconds.
    private static func date(_ value: Any?) -> Date? {
        if let number = value as? NSNumber {
            let raw = number.doubleValue
            return Date(timeIntervalSince1970: raw > 1e12 ? raw / 1000 : raw)
        }
        guard let text = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}
