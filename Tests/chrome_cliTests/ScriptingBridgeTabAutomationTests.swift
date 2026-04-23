import XCTest
@testable import chrome_cli

final class ScriptingBridgeTabAutomationTests: XCTestCase {
    func testActivateTabRequiresExactWindowAndTabPair() throws {
        let leftWindow = FakeWindow(
            identifier: 1,
            name: "Left",
            tabs: [FakeTab(identifier: 10, title: "Tab 10", url: "https://left")]
        )
        let rightWindow = FakeWindow(
            identifier: 2,
            name: "Right",
            tabs: [FakeTab(identifier: 20, title: "Tab 20", url: "https://right")]
        )
        let browser = FakeBrowser(
            isRunning: true,
            windowsResult: [leftWindow, rightWindow]
        )

        let automation = ScriptingBridgeTabAutomation(bundleId: "com.brave.Browser", browser: browser)
        let service = TabService(
            browser: BrowserTarget(bundleId: "com.brave.Browser"),
            automation: automation
        )

        XCTAssertThrowsError(try service.activateTab(windowId: 2, tabId: 10)) { error in
            XCTAssertEqual(error as? CLIError, CLIError.tabNotFound(windowId: 2, tabId: 10))
        }

        XCTAssertEqual(browser.activateCalls, 0)
        XCTAssertTrue(leftWindow.selectedTabIDs.isEmpty)
        XCTAssertTrue(rightWindow.selectedTabIDs.isEmpty)
        XCTAssertTrue(leftWindow.setActiveTabIndices.isEmpty)
        XCTAssertTrue(rightWindow.setActiveTabIndices.isEmpty)
    }

    func testActivateTabUsesConservativeFocusBehavior() throws {
        let tab = FakeTab(identifier: 10, title: "Brave Tab", url: "https://example.com")
        let window = FakeWindow(
            identifier: 7,
            name: "Brave Window",
            tabs: [tab]
        )
        let browser = FakeBrowser(
            isRunning: true,
            windowsResult: [window]
        )
        let automation = ScriptingBridgeTabAutomation(bundleId: "com.brave.Browser", browser: browser)
        let service = TabService(
            browser: BrowserTarget(bundleId: "com.brave.Browser"),
            automation: automation
        )

        let response = try service.activateTab(windowId: 7, tabId: 10)

        XCTAssertTrue(response.focused)
        XCTAssertEqual(browser.activateCalls, 1)
        XCTAssertEqual(window.selectedTabIDs, [10])
        XCTAssertEqual(window.setActiveTabIndices, [1])
        XCTAssertEqual(window.bringToFrontCalls, 1)
    }

    func testActivateTabReturnsFalseWhenFocusCannotBeConfirmed() throws {
        let tab = FakeTab(identifier: 10, title: "Brave Tab", url: "https://example.com")
        let window = NonFocusingWindow(
            identifier: 7,
            name: "Brave Window",
            tabs: [tab]
        )
        let browser = FakeBrowser(
            isRunning: true,
            windowsResult: [window]
        )

        let automation = ScriptingBridgeTabAutomation(bundleId: "com.brave.Browser", browser: browser)
        let activated = try automation.activateTab(windowId: 7, tabId: 10)

        XCTAssertFalse(activated)
    }

    func testActivateTabThrowsBrowserUnavailableWhenBrowserIsNotRunning() {
        let browser = FakeBrowser(isRunning: false, windowsResult: [])
        let automation = ScriptingBridgeTabAutomation(bundleId: "com.brave.Browser", browser: browser)
        let service = TabService(
            browser: BrowserTarget(bundleId: "com.brave.Browser"),
            automation: automation
        )

        XCTAssertThrowsError(try service.activateTab(windowId: 7, tabId: 10)) { error in
            guard case let .browserUnavailable(message) = (error as? CLIError) else {
                XCTFail("Expected browserUnavailable")
                return
            }
            XCTAssertTrue(message.contains("com.brave.Browser"))
            XCTAssertTrue(message.contains("not running"))
        }
    }

    func testCloseTabThrowsBrowserUnavailableWhenBrowserIsNotRunning() {
        let browser = FakeBrowser(isRunning: false, windowsResult: [])
        let automation = ScriptingBridgeTabAutomation(bundleId: "com.brave.Browser", browser: browser)
        let service = TabService(
            browser: BrowserTarget(bundleId: "com.brave.Browser"),
            automation: automation
        )

        XCTAssertThrowsError(try service.closeTab(windowId: 7, tabId: 10)) { error in
            guard case let .browserUnavailable(message) = (error as? CLIError) else {
                XCTFail("Expected browserUnavailable")
                return
            }
            XCTAssertTrue(message.contains("com.brave.Browser"))
            XCTAssertTrue(message.contains("not running"))
        }
    }
}

private final class FakeBrowser: BrowserScripting {
    let isRunning: Bool
    let windowsResult: [BrowserWindowScripting]

    private(set) var activateCalls = 0

    init(isRunning: Bool, windowsResult: [BrowserWindowScripting]) {
        self.isRunning = isRunning
        self.windowsResult = windowsResult
    }

    func windows() throws -> [BrowserWindowScripting] {
        windowsResult
    }

    func activateApplication() throws {
        activateCalls += 1
    }
}

private final class FakeWindow: BrowserWindowScripting {
    let identifier: Int?
    let name: String
    var tabs: [BrowserTabScripting]
    var activeTabIdentifier: Int? {
        guard let index = activeTabIndex, index > 0, index <= tabs.count else {
            return nil
        }
        return tabs[index - 1].identifier
    }

    private(set) var selectedTabIDs: [Int] = []
    private(set) var setActiveTabIndices: [Int] = []
    private(set) var bringToFrontCalls = 0
    private var activeTabIndex: Int?

    init(identifier: Int?, name: String, tabs: [BrowserTabScripting]) {
        self.identifier = identifier
        self.name = name
        self.tabs = tabs
    }

    func selectTab(tabId: Int, tabIndex: Int) throws {
        selectedTabIDs.append(tabId)
        setActiveTabIndices.append(tabIndex)
        activeTabIndex = tabIndex
    }

    func bringToFront() {
        bringToFrontCalls += 1
    }
}

private final class NonFocusingWindow: BrowserWindowScripting {
    let identifier: Int?
    let name: String
    var tabs: [BrowserTabScripting]
    var activeTabIdentifier: Int? {
        nil
    }

    init(identifier: Int?, name: String, tabs: [BrowserTabScripting]) {
        self.identifier = identifier
        self.name = name
        self.tabs = tabs
    }

    func selectTab(tabId: Int, tabIndex: Int) throws {}

    func bringToFront() {}
}

private final class FakeTab: BrowserTabScripting {
    let identifier: Int?
    let title: String
    let url: String

    init(identifier: Int?, title: String, url: String) {
        self.identifier = identifier
        self.title = title
        self.url = url
    }

    func close() throws {}
}
