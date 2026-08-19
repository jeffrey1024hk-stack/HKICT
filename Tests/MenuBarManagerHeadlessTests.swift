import AppKit
import XCTest
@testable import PostureAICore

/// Exercises MenuBarManager's update paths without a window server by
/// building the menu via makeMenu() instead of setup().
@MainActor
final class MenuBarManagerHeadlessTests: XCTestCase {
    private enum ItemIndex {
        static let about = 0
        static let settings = 2
        static let analytics = 3
        static let checkForUpdates = 5
        static let help = 6
        static let quit = 8
    }

    func testUpdatesBeforeMenuExistsAreSafeNoOps() {
        let manager = MenuBarManager()
        manager.updateStatus(text: "ignored", icon: .good)
        manager.updateEnabledState(false)
        manager.updateRecalibrateEnabled(false)
        manager.updateShortcut(enabled: true, shortcut: .defaultShortcut)
    }

    func testMenuStructureMatchesSpec() {
        let manager = MenuBarManager()
        let menu = manager.makeMenu()

        XCTAssertEqual(menu.items[ItemIndex.about].title, "About PostureAI")
        XCTAssertTrue(menu.items[1].isSeparatorItem)

        XCTAssertEqual(menu.items[ItemIndex.settings].title, "Settings...")
        XCTAssertEqual(menu.items[ItemIndex.settings].keyEquivalent, ",")
        XCTAssertEqual(menu.items[ItemIndex.settings].keyEquivalentModifierMask, .command)

        XCTAssertEqual(menu.items[ItemIndex.analytics].title, "Analytics...")
        XCTAssertEqual(menu.items[ItemIndex.analytics].keyEquivalent, "")

        XCTAssertTrue(menu.items[4].isSeparatorItem)

        XCTAssertEqual(menu.items[ItemIndex.checkForUpdates].title, "Check for Updates...")
        XCTAssertEqual(menu.items[ItemIndex.help].title, "Help...")

        XCTAssertTrue(menu.items[7].isSeparatorItem)

        XCTAssertEqual(menu.items[ItemIndex.quit].title, "Quit")
        XCTAssertEqual(menu.items[ItemIndex.quit].keyEquivalent, "q")
    }

    func testEveryMenuBarIconResolvesToAnImage() {
        for icon in MenuBarIcon.allCases {
            XCTAssertNotNil(icon.image, "No image for \(icon)")
        }
    }

    func testEveryMenuBarIconTypeMapsToMatchingMenuBarIcon() {
        XCTAssertEqual(MenuBarIconType.good.menuBarIcon, .good)
        XCTAssertEqual(MenuBarIconType.bad.menuBarIcon, .bad)
        XCTAssertEqual(MenuBarIconType.away.menuBarIcon, .away)
        XCTAssertEqual(MenuBarIconType.paused.menuBarIcon, .paused)
        XCTAssertEqual(MenuBarIconType.calibrating.menuBarIcon, .calibrating)
    }
}