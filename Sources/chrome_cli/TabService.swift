import Foundation

protocol TabServicing {
    var browserMetadata: BrowserMetadata { get }
    func listTabs() throws -> ListTabsResponse
    func streamTabs(_ emit: (TabRecord) throws -> Void) throws
    func activateTab(windowId: Int, tabId: Int) throws -> ActivateTabResponse
    func closeTab(windowId: Int, tabId: Int) throws -> CloseTabResponse
}

extension TabServicing {
    func streamTabs(_ emit: (TabRecord) throws -> Void) throws {
        let response = try listTabs()
        for tab in response.tabs {
            try emit(tab)
        }
    }
}

protocol TabAutomating {
    func listTabs() throws -> [TabRecord]
    func streamTabs(_ emit: (TabRecord) throws -> Void) throws
    func activateTab(windowId: Int, tabId: Int) throws -> Bool
    func closeTab(windowId: Int, tabId: Int) throws -> Bool
}

final class TabService: TabServicing {
    private let browser: BrowserTarget
    private let automation: TabAutomating

    init(browser: BrowserTarget, automation: TabAutomating) {
        self.browser = browser
        self.automation = automation
    }

    var browserMetadata: BrowserMetadata {
        BrowserMetadata(bundleId: browser.bundleId)
    }

    func listTabs() throws -> ListTabsResponse {
        let tabs = try automation.listTabs()
        return ListTabsResponse(browser: browserMetadata, tabs: tabs)
    }

    func streamTabs(_ emit: (TabRecord) throws -> Void) throws {
        try automation.streamTabs(emit)
    }

    func activateTab(windowId: Int, tabId: Int) throws -> ActivateTabResponse {
        let activated = try automation.activateTab(windowId: windowId, tabId: tabId)
        guard activated else {
            throw CLIError.tabNotFound(windowId: windowId, tabId: tabId)
        }

        return ActivateTabResponse(
            browser: browserMetadata,
            tab: TabIdentifier(windowId: windowId, tabId: tabId),
            focused: true
        )
    }

    func closeTab(windowId: Int, tabId: Int) throws -> CloseTabResponse {
        let closed = try automation.closeTab(windowId: windowId, tabId: tabId)
        guard closed else {
            throw CLIError.tabNotFound(windowId: windowId, tabId: tabId)
        }

        return CloseTabResponse(
            browser: browserMetadata,
            tab: TabIdentifier(windowId: windowId, tabId: tabId),
            closed: true
        )
    }
}
