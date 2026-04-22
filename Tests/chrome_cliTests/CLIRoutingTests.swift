import ArgumentParser
import XCTest
@testable import chrome_cli

final class CLIRoutingTests: XCTestCase {
    override func tearDown() {
        RuntimeEnvironment.reset()
        super.tearDown()
    }

    func testTabsListRoutesToListOperationAndResolvesBrowserOption() throws {
        let service = RecordingTabService()
        var capturedOptions: BrowserOptions?

        RuntimeEnvironment.makeTabService = { options in
            capturedOptions = options
            return service
        }

        var command = try ChromeCLI.parseAsRoot(["--browser", "chrome", "tabs", "list"])
        try command.run()

        XCTAssertEqual(capturedOptions?.browser, .chrome)
        XCTAssertFalse(service.didListTabs)
        XCTAssertTrue(service.streamedTabs)
    }

    func testTabsActivateRoutesToActivateOperation() throws {
        let service = RecordingTabService()

        RuntimeEnvironment.makeTabService = { _ in service }

        var command = try ChromeCLI.parseAsRoot([
            "--bundle-id", "org.chromium.Chromium",
            "tabs", "activate",
            "--window-id", "500",
            "--tab-id", "700"
        ])
        try command.run()

        XCTAssertEqual(service.activated, TabIdentifier(windowId: 500, tabId: 700))
    }

    func testTabsCloseRoutesToCloseOperation() throws {
        let service = RecordingTabService()

        RuntimeEnvironment.makeTabService = { _ in service }

        var command = try ChromeCLI.parseAsRoot([
            "tabs", "close",
            "--window-id", "12",
            "--tab-id", "13"
        ])
        try command.run()

        XCTAssertEqual(service.closed, TabIdentifier(windowId: 12, tabId: 13))
    }

    func testInvalidArgumentsThrowParserError() {
        XCTAssertThrowsError(try ChromeCLI.parseAsRoot(["tabs", "activate", "--window-id", "1"]))
    }

    func testMissingRootSubcommandReturnsHelpRequest() throws {
        var command = try ChromeCLI.parseAsRoot([])
        XCTAssertThrowsError(try command.run()) { error in
            XCTAssertTrue(error is CleanExit)
        }
    }

    func testMissingTabsSubcommandReturnsHelpRequest() throws {
        var command = try ChromeCLI.parseAsRoot(["tabs"])
        XCTAssertThrowsError(try command.run()) { error in
            XCTAssertTrue(error is CleanExit)
        }
    }

    func testVersionCommandRoutesAtRoot() throws {
        var command = try ChromeCLI.parseAsRoot(["version"])
        try command.run()
    }

    func testTabsSwitchRoutesToSwitchRunner() throws {
        let service = RecordingTabService()
        var capturedOptions: BrowserOptions?
        var switchInvoked = false

        RuntimeEnvironment.makeTabService = { options in
            capturedOptions = options
            return service
        }
        RuntimeEnvironment.isInteractiveTerminal = { true }

        RuntimeEnvironment.runTabsSwitch = { incomingService in
            switchInvoked = true
            XCTAssertEqual(incomingService.browserMetadata.bundleId, "com.brave.Browser")
        }

        var command = try ChromeCLI.parseAsRoot(["--browser", "brave", "tabs", "switch"])
        try command.run()

        XCTAssertEqual(capturedOptions?.browser, .brave)
        XCTAssertTrue(switchInvoked)
    }

    func testHelpCommandReturnsCleanExitHelpRequest() throws {
        var command = try ChromeCLI.parseAsRoot(["help"])
        XCTAssertThrowsError(try command.run()) { error in
            XCTAssertTrue(error is CleanExit)
        }
    }

    func testTabsHelpFlagParsesSuccessfully() {
        XCTAssertNoThrow(try ChromeCLI.parseAsRoot(["tabs", "--help"]))
    }

    func testNestedCommandHelpFlagParsesSuccessfully() {
        XCTAssertNoThrow(try ChromeCLI.parseAsRoot(["tabs", "list", "--help"]))
    }
}

private final class RecordingTabService: TabServicing {
    private(set) var didListTabs = false
    private(set) var activated: TabIdentifier?
    private(set) var closed: TabIdentifier?
    private(set) var streamedTabs = false

    var browserMetadata: BrowserMetadata {
        BrowserMetadata(bundleId: "com.brave.Browser")
    }

    func listTabs() throws -> ListTabsResponse {
        didListTabs = true
        return ListTabsResponse(browser: browserMetadata, tabs: [])
    }

    func streamTabs(_ emit: (TabRecord) throws -> Void) throws {
        streamedTabs = true
    }

    func activateTab(windowId: Int, tabId: Int) throws -> ActivateTabResponse {
        let id = TabIdentifier(windowId: windowId, tabId: tabId)
        activated = id
        return ActivateTabResponse(browser: browserMetadata, tab: id, focused: true)
    }

    func closeTab(windowId: Int, tabId: Int) throws -> CloseTabResponse {
        let id = TabIdentifier(windowId: windowId, tabId: tabId)
        closed = id
        return CloseTabResponse(browser: browserMetadata, tab: id, closed: true)
    }
}
