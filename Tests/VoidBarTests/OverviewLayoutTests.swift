import XCTest
@testable import VoidBar

@MainActor
final class OverviewLayoutTests: XCTestCase {
    private func configs(_ widgets: [OverviewWidget], off: Set<OverviewWidget> = []) -> [TabManager.WidgetConfig] {
        widgets.map { TabManager.WidgetConfig(id: $0, isEnabled: !off.contains($0)) }
    }

    private let everything = NotchViewModel.Tab.allCases

    func testPlayerTakesTheHeroAndFourTilesFollowInOrder() {
        let plan = OverviewLayout.plan(order: configs(OverviewWidget.allCases), activeTabs: everything) { _ in true }
        XCTAssertEqual(plan.hero, .nowPlaying)
        XCTAssertEqual(plan.tiles, [.limits, .clipboard, .focus, .notes])
    }

    func testWithoutMusicTheGridHasSixTiles() {
        let plan = OverviewLayout.plan(order: configs(OverviewWidget.allCases), activeTabs: everything) { $0 != .nowPlaying }
        XCTAssertNil(plan.hero)
        XCTAssertEqual(plan.tiles.count, 6)
        XCTAssertEqual(plan.tiles.first, .limits)
    }

    func testWidgetsOfSwitchedOffTabsNeverAppear() {
        let tabs: [NotchViewModel.Tab] = [.home, .media, .clipboard, .timer]
        let plan = OverviewLayout.plan(order: configs(OverviewWidget.allCases), activeTabs: tabs) { _ in true }
        XCTAssertFalse(plan.tiles.contains(.weather))
        XCTAssertFalse(plan.tiles.contains(.calendar))
        XCTAssertEqual(plan.tiles, [.clipboard, .focus])
    }

    func testDisabledAndEmptyWidgetsAreSkipped() {
        let plan = OverviewLayout.plan(
            order: configs(OverviewWidget.allCases, off: [.limits]),
            activeTabs: everything
        ) { $0 != .clipboard }
        XCTAssertEqual(plan.tiles.prefix(2), [.focus, .notes])
    }

    func testUserOrderIsKept() {
        let order = configs([.monitor, .nowPlaying, .snippets, .focus])
        let plan = OverviewLayout.plan(order: order, activeTabs: everything) { _ in true }
        XCTAssertEqual(plan.hero, .nowPlaying)
        XCTAssertEqual(plan.tiles, [.monitor, .snippets, .focus])
    }

    func testNewWidgetsJoinASavedOrder() {
        let suite = "dev.xand0.VoidBar.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let saved = [TabManager.WidgetConfig(id: .focus, isEnabled: false)]
        defaults.set(try! JSONEncoder().encode(saved), forKey: "voidbar.overview.widgets")

        let manager = TabManager(defaults: defaults)
        XCTAssertEqual(manager.widgets.first, saved.first)
        XCTAssertEqual(Set(manager.widgets.map(\.id)), Set(OverviewWidget.allCases))
    }
}
