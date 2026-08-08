import XCTest
@testable import VoidBar

@MainActor
final class TranslatorTests: XCTestCase {
    func testEnglishRoutesToUkrainian() {
        let route = Translator.route(for: "Hello, world")

        XCTAssertEqual(route.source.languageCode?.identifier, "en")
        XCTAssertEqual(route.target.languageCode?.identifier, "uk")
    }

    func testUkrainianRoutesToEnglish() {
        let route = Translator.route(for: "Привіт, світе")

        XCTAssertEqual(route.source.languageCode?.identifier, "uk")
        XCTAssertEqual(route.target.languageCode?.identifier, "en")
    }
}
