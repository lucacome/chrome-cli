import XCTest
@testable import chrome_cli

final class TabServiceTests: XCTestCase {
    func testListTabsReturnsRowsFromAutomation() throws {
        let automation = MockTabAutomation(
            listedTabs: [
                TabRecord(windowId: 101, windowName: "Window A", tabId: 1001, title: "First", url: "https://example.com"),
                TabRecord(windowId: 102, windowName: "Window B", tabId: 1002, title: "Second", url: "https://example.org"),
            ]
        )

        let service = TabService(
            browser: BrowserTarget(bundleId: "com.brave.Browser"),
            automation: automation
        )

        let response = try service.listTabs()

        XCTAssertEqual(response.browser.bundleId, "com.brave.Browser")
        XCTAssertEqual(response.tabs.count, 2)
        XCTAssertEqual(response.tabs[0].windowId, 101)
        XCTAssertEqual(response.tabs[0].tabId, 1001)
        XCTAssertEqual(response.tabs[0].title, "First")
        XCTAssertEqual(automation.listCalls, 1)
    }

    func testActivateTabReturnsFocusedTrue() throws {
        let automation = MockTabAutomation(activateResult: true)
        let service = TabService(
            browser: BrowserTarget(bundleId: "com.brave.Browser"),
            automation: automation
        )

        let response = try service.activateTab(windowId: 9, tabId: 10)

        XCTAssertEqual(response.tab, TabIdentifier(windowId: 9, tabId: 10))
        XCTAssertTrue(response.focused)
        XCTAssertEqual(automation.lastActivated, TabIdentifier(windowId: 9, tabId: 10))
    }

    func testActivateTabThrowsNotFoundWhenAutomationReturnsFalse() {
        let automation = MockTabAutomation(activateResult: false)
        let service = TabService(
            browser: BrowserTarget(bundleId: "com.brave.Browser"),
            automation: automation
        )

        XCTAssertThrowsError(try service.activateTab(windowId: 1, tabId: 2)) { error in
            XCTAssertEqual(error as? CLIError, CLIError.tabNotFound(windowId: 1, tabId: 2))
        }
    }

    func testCloseTabReturnsClosedTrue() throws {
        let automation = MockTabAutomation(closeResult: true)
        let service = TabService(
            browser: BrowserTarget(bundleId: "com.brave.Browser"),
            automation: automation
        )

        let response = try service.closeTab(windowId: 33, tabId: 44)

        XCTAssertEqual(response.tab, TabIdentifier(windowId: 33, tabId: 44))
        XCTAssertTrue(response.closed)
        XCTAssertEqual(automation.lastClosed, TabIdentifier(windowId: 33, tabId: 44))
    }

    func testStreamTabsUsesAutomationStream() throws {
        let automation = MockTabAutomation(
            listedTabs: [
                TabRecord(windowId: 7, windowName: "Window", tabId: 9, title: "Title", url: "https://example.com"),
            ]
        )
        let service = TabService(
            browser: BrowserTarget(bundleId: "com.brave.Browser"),
            automation: automation
        )

        var streamed: [TabRecord] = []
        try service.streamTabs { tab in
            streamed.append(tab)
        }

        XCTAssertEqual(streamed.count, 1)
        XCTAssertEqual(streamed[0].windowId, 7)
        XCTAssertEqual(streamed[0].tabId, 9)
        XCTAssertEqual(streamed[0].title, "Title")
        XCTAssertEqual(automation.listCalls, 0)
        XCTAssertEqual(automation.streamCalls, 1)
    }
}

private final class MockTabAutomation: TabAutomating {
    private let listedTabs: [TabRecord]
    private let activateResult: Bool
    private let closeResult: Bool

    private(set) var listCalls = 0
    private(set) var streamCalls = 0
    private(set) var lastActivated: TabIdentifier?
    private(set) var lastClosed: TabIdentifier?

    init(
        listedTabs: [TabRecord] = [],
        activateResult: Bool = true,
        closeResult: Bool = true
    ) {
        self.listedTabs = listedTabs
        self.activateResult = activateResult
        self.closeResult = closeResult
    }

    func listTabs() throws -> [TabRecord] {
        listCalls += 1
        return listedTabs
    }

    func streamTabs(_ emit: (TabRecord) throws -> Void) throws {
        streamCalls += 1
        for tab in listedTabs {
            try emit(tab)
        }
    }

    func activateTab(windowId: Int, tabId: Int) throws -> Bool {
        lastActivated = TabIdentifier(windowId: windowId, tabId: tabId)
        return activateResult
    }

    func closeTab(windowId: Int, tabId: Int) throws -> Bool {
        lastClosed = TabIdentifier(windowId: windowId, tabId: tabId)
        return closeResult
    }
}
