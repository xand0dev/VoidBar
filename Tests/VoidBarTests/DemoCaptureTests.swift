#if DEBUG
import XCTest
@testable import VoidBar

@MainActor
final class DemoCaptureTests: XCTestCase {
    func testCaptureIsOptIn() {
        XCTAssertNil(DemoCapture.requestedDirectory(in: [:]))
        XCTAssertNil(DemoCapture.requestedDirectory(in: [DemoCapture.environmentKey: ""]))
        XCTAssertEqual(
            DemoCapture.requestedDirectory(in: [DemoCapture.environmentKey: "/tmp/capture"])?.path,
            "/tmp/capture"
        )
    }

    func testWalkthroughTellsTheREADMEStory() {
        XCTAssertEqual(DemoScript.chapters, [.media, .timer, .translate, .clipboard])
    }

    func testWalkthroughStepsAreOrderedAndFitTheLoop() {
        let times = DemoScript.walkthrough.map(\.at)
        XCTAssertEqual(times, times.sorted())
        XCTAssertLessThan(times.last ?? .infinity, DemoScript.length)
        XCTAssertLessThanOrEqual(DemoScript.length, 12)
        XCTAssertEqual(DemoScript.walkthrough.first?.action, .open)
        XCTAssertEqual(DemoScript.walkthrough.last?.action, .close)
    }

    func testDemoTranslationRunsEnglishToUkrainian() {
        let route = Translator.route(for: DemoScript.translationInput)
        XCTAssertEqual(route.source.languageCode?.identifier, "en")
        XCTAssertEqual(route.target.languageCode?.identifier, "uk")
        XCTAssertEqual(Translator.route(for: DemoScript.translationOutput).source.languageCode?.identifier, "uk")
    }

    func testDemoTranslationIsNotOverwrittenBySession() {
        let translator = Translator()
        XCTAssertFalse(translator.showsDemo)
        translator.showDemo(input: "Hello", output: "Привіт")
        XCTAssertTrue(translator.showsDemo)
        XCTAssertEqual(translator.output, "Привіт")
    }

    func testDemoMediaShowsInventedTrack() {
        let media = MediaController()
        media.showDemo(
            title: DemoScript.track.title,
            artist: DemoScript.track.artist,
            album: DemoScript.track.album,
            source: DemoScript.source,
            artwork: DemoArtwork.make(side: 64),
            duration: DemoScript.trackDuration,
            position: DemoScript.trackDuration + 30,
            isPlaying: true
        )
        XCTAssertEqual(media.track?.title, "Graphite Hours")
        XCTAssertNotNil(media.artwork)
        XCTAssertEqual(media.position, DemoScript.trackDuration, "position is clamped to the track")
    }
}
#endif
