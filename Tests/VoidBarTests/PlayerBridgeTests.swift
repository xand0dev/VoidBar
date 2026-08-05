import XCTest
@testable import VoidBar

final class PlayerBridgeTests: XCTestCase {
    
    func testAppleScriptEscaping() {
        // F-02 regression test payloads from the audit specification
        let payloads = [
            "\"",
            "\\",
            "\\\"",
            "newline\nend tell",
            "do shell script \"touch /tmp/voidbar-injected\"",
            "\r",
            "\0"
        ]
        
        let expectedEscaped = [
            "\\\"",
            "\\\\",
            "\\\\\\\"",
            "newline\\nend tell",
            "do shell script \\\"touch /tmp/voidbar-injected\\\"",
            "\\r",
            ""
        ]
        
        for (index, payload) in payloads.enumerated() {
            let escaped = PlayerBridge.escapeForAppleScript(payload)
            XCTAssertEqual(escaped, expectedEscaped[index])
            
            // Further verification: Ensure constructing a string literal doesn't break syntax
            // A properly escaped string inserted between quotes should not allow breaking out of the quotes.
            let scriptSource = """
            set testVar to "\(escaped)"
            """
            // If the escaping was insufficient, the AppleScript parser might fail or execute something.
            // We can just verify it compiles without executing side effects.
            let script = NSAppleScript(source: scriptSource)
            XCTAssertNotNil(script, "Script failed to compile with payload: \(payload)")
        }
    }
}
