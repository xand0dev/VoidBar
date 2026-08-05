import XCTest
@testable import VoidBar

@MainActor
final class CalendarStoreTests: XCTestCase {
    
    func testSafeURLs() {
        let store = CalendarStore()
        
        let validURLs = [
            "https://zoom.us/j/123456789",
            "HTTPS://zoom.us/j/123456789",
            "http://example.com/meet",
            "zoommtg://zoom.us/join?confno=123456789",
            "msteams://teams.microsoft.com/l/meetup-join/19:meeting_123@thread.v2/0",
            "webex://meet" // webex scheme often used without standard host
        ]
        
        for urlString in validURLs {
            guard let url = URL(string: urlString) else {
                XCTFail("Failed to create URL from \(urlString)")
                continue
            }
            XCTAssertTrue(store.isSafeURL(url), "Expected \(urlString) to be safe")
        }
        
        let invalidURLs = [
            "file:///etc/passwd",
            "javascript:alert(1)",
            "data:text/html,<script>alert(1)</script>",
            "x-apple.systempreferences://",
            "ssh://user@host",
            "smb://server/share",
            "ftp://server/file",
            "https://", // No host
            "http://", // No host
            "unknownscheme://example.com",
            "HTTPS://" // Uppercase scheme, no host
        ]
        
        for urlString in invalidURLs {
            guard let url = URL(string: urlString) else {
                continue
            }
            XCTAssertFalse(store.isSafeURL(url), "Expected \(urlString) to be unsafe")
        }
    }
}
