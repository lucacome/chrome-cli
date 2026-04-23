import XCTest
@testable import chrome_cli

final class TabSwitchSourceTests: XCTestCase {
    func testEmitsCachedRowsOnlyWhenCacheExists() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let cache = TabSwitchCache(
            bundleId: "com.brave.Browser",
            environment: ["XDG_CACHE_HOME": temp.path]
        )

        let cachedRows = [
            TabSwitchRow(
                compositeId: "1:10",
                windowId: 1,
                tabId: 10,
                display: "[1:10] Cached One — https://one",
                url: "https://one"
            ),
            TabSwitchRow(
                compositeId: "1:11",
                windowId: 1,
                tabId: 11,
                display: "[1:11] Cached Two — https://two",
                url: "https://two"
            ),
        ]
        try cache.writeRows(cachedRows)

        let service = SwitchSourceService(
            streamedTabs: [
                TabRecord(windowId: 1, windowName: "W", tabId: 10, title: "Fresh One", url: "https://one-fresh"),
                TabRecord(windowId: 2, windowName: "W", tabId: 20, title: "Fresh Three", url: "https://three"),
            ]
        )

        var emitted: [String] = []
        let source = TabSwitchSource(service: service, cache: cache) { line in
            emitted.append(line)
        }

        try source.emitRowsToStdout()

        XCTAssertEqual(emitted.count, 2)
        XCTAssertEqual(TabSwitchRow.parse(tsvLine: emitted[0])?.compositeId, "1:10")
        XCTAssertEqual(TabSwitchRow.parse(tsvLine: emitted[1])?.compositeId, "1:11")
    }

    func testWritesFreshCacheInStableStreamOrder() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let cache = TabSwitchCache(
            bundleId: "com.brave.Browser",
            environment: ["XDG_CACHE_HOME": temp.path]
        )

        let service = SwitchSourceService(
            streamedTabs: [
                TabRecord(windowId: 9, windowName: "W", tabId: 1, title: "A", url: "https://a"),
                TabRecord(windowId: 9, windowName: "W", tabId: 2, title: "B", url: "https://b"),
            ]
        )

        let source = TabSwitchSource(service: service, cache: cache) { _ in }
        try source.emitRowsToStdout()

        let persisted = try cache.readRows()
        XCTAssertEqual(persisted.map(\ .compositeId), ["9:1", "9:2"])
    }

    func testRefreshCacheWritesFreshRows() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let cache = TabSwitchCache(
            bundleId: "com.brave.Browser",
            environment: ["XDG_CACHE_HOME": temp.path]
        )

        try cache.writeRows([
            TabSwitchRow(compositeId: "1:1", windowId: 1, tabId: 1, display: "old", url: "https://old")
        ])

        let service = SwitchSourceService(
            streamedTabs: [
                TabRecord(windowId: 7, windowName: "W", tabId: 3, title: "C", url: "https://c"),
                TabRecord(windowId: 7, windowName: "W", tabId: 4, title: "D", url: "https://d"),
            ]
        )

        let source = TabSwitchSource(service: service, cache: cache) { _ in }
        try source.refreshCache()

        let persisted = try cache.readRows()
        XCTAssertEqual(persisted.map(\ .compositeId), ["7:3", "7:4"])
    }

    func testLiveSourceEmitsLiveRowsOnlyWithoutCachedPrelude() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let cache = TabSwitchCache(
            bundleId: "com.brave.Browser",
            environment: ["XDG_CACHE_HOME": temp.path]
        )

        try cache.writeRows([
            TabSwitchRow(compositeId: "1:1", windowId: 1, tabId: 1, display: "old", url: "https://old")
        ])

        let service = SwitchSourceService(
            streamedTabs: [
                TabRecord(windowId: 2, windowName: "W", tabId: 2, title: "Fresh", url: "https://fresh")
            ]
        )

        var emitted: [String] = []
        let source = TabSwitchSource(service: service, cache: cache) { line in
            emitted.append(line)
        }

        try source.emitRowsToStdoutLive()

        XCTAssertEqual(emitted.count, 1)
        XCTAssertEqual(TabSwitchRow.parse(tsvLine: emitted[0])?.compositeId, "2:2")

        let persisted = try cache.readRows()
        XCTAssertEqual(persisted.map(\ .compositeId), ["2:2"])
    }

    func testCacheWriteReplacesPreviousRows() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let cache = TabSwitchCache(
            bundleId: "com.brave.Browser",
            environment: ["XDG_CACHE_HOME": temp.path]
        )

        try cache.writeRows([
            TabSwitchRow(compositeId: "1:1", windowId: 1, tabId: 1, display: "old", url: "https://old")
        ])

        try cache.writeRows([
            TabSwitchRow(compositeId: "2:2", windowId: 2, tabId: 2, display: "new", url: "https://new")
        ])

        let finalRows = try cache.readRows()
        XCTAssertEqual(finalRows.map(\ .compositeId), ["2:2"])
    }

    func testEmitRowsContinuesWhenFinalCacheWriteFails() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let invalidCacheRoot = temp.appendingPathComponent("xdg-as-file")
        FileManager.default.createFile(atPath: invalidCacheRoot.path, contents: Data())

        let cache = TabSwitchCache(
            bundleId: "com.brave.Browser",
            environment: ["XDG_CACHE_HOME": invalidCacheRoot.path]
        )

        let service = SwitchSourceService(
            streamedTabs: [
                TabRecord(windowId: 4, windowName: "W", tabId: 9, title: "Title", url: "https://example.com")
            ]
        )

        var emitted: [String] = []
        let source = TabSwitchSource(service: service, cache: cache) { line in
            emitted.append(line)
        }

        XCTAssertNoThrow(try source.emitRowsToStdoutLive())
        XCTAssertEqual(emitted.count, 1)
        XCTAssertEqual(TabSwitchRow.parse(tsvLine: emitted[0])?.compositeId, "4:9")
    }

    private func makeTempDirectory() throws -> URL {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("chrome-cli-tests-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        return temp
    }
}

private final class SwitchSourceService: TabServicing {
    let streamedTabs: [TabRecord]

    init(streamedTabs: [TabRecord]) {
        self.streamedTabs = streamedTabs
    }

    var browserMetadata: BrowserMetadata {
        BrowserMetadata(bundleId: "com.brave.Browser")
    }

    func listTabs() throws -> ListTabsResponse {
        ListTabsResponse(browser: browserMetadata, tabs: streamedTabs)
    }

    func streamTabs(_ emit: (TabRecord) throws -> Void) throws {
        for tab in streamedTabs {
            try emit(tab)
        }
    }

    func activateTab(windowId: Int, tabId: Int) throws -> ActivateTabResponse {
        ActivateTabResponse(
            browser: browserMetadata,
            tab: TabIdentifier(windowId: windowId, tabId: tabId),
            focused: true
        )
    }

    func closeTab(windowId: Int, tabId: Int) throws -> CloseTabResponse {
        CloseTabResponse(
            browser: browserMetadata,
            tab: TabIdentifier(windowId: windowId, tabId: tabId),
            closed: true
        )
    }
}
