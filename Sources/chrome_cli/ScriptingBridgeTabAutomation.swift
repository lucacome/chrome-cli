import AppKit
import ApplicationServices
import Darwin
import Foundation
import ScriptingBridge

protocol WindowFocusing {
    func raiseWindow(bundleId: String, windowName: String, tabTitle: String) -> Bool
}

final class AXWindowFocuser: WindowFocusing {
    func raiseWindow(bundleId: String, windowName: String, tabTitle: String) -> Bool {
        guard isAccessibilityTrusted else {
            return false
        }

        guard let application = runningApplication(bundleId: bundleId) else {
            return false
        }

        let applicationRef = AXUIElementCreateApplication(application.processIdentifier)
        var windowsValue: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(
            applicationRef,
            kAXWindowsAttribute as CFString,
            &windowsValue
        )
        guard windowsResult == .success, let windows = windowsValue as? [AXUIElement], !windows.isEmpty else {
            return false
        }

        let normalizedWindowName = normalize(windowName)
        let normalizedTabTitle = normalize(tabTitle)

        var bestWindow: AXUIElement?
        var bestScore = 0
        for window in windows {
            guard let title = windowTitle(window) else {
                continue
            }

            let score = matchScore(
                candidateTitle: normalize(title),
                targetWindowName: normalizedWindowName,
                targetTabTitle: normalizedTabTitle
            )
            if score > bestScore {
                bestScore = score
                bestWindow = window
            }
        }

        guard let targetWindow = bestWindow, bestScore > 0 else {
            return false
        }

        return AXUIElementPerformAction(targetWindow, kAXRaiseAction as CFString) == .success
    }

    private var isAccessibilityTrusted: Bool {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
    }

    private func runningApplication(bundleId: String) -> NSRunningApplication? {
        let applications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        if let active = applications.first(where: \.isActive) {
            return active
        }
        return applications.first
    }

    private func windowTitle(_ window: AXUIElement) -> String? {
        var titleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &titleValue
        )
        guard result == .success else {
            return nil
        }
        return titleValue as? String
    }

    private func matchScore(candidateTitle: String, targetWindowName: String, targetTabTitle: String) -> Int {
        var score = 0

        if !targetTabTitle.isEmpty {
            if candidateTitle == targetTabTitle {
                score += 6
            } else if candidateTitle.localizedCaseInsensitiveContains(targetTabTitle) {
                score += 3
            }
        }

        if !targetWindowName.isEmpty {
            if candidateTitle == targetWindowName {
                score += 4
            } else if candidateTitle.localizedCaseInsensitiveContains(targetWindowName) {
                score += 2
            }
        }

        return score
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

protocol BrowserScripting {
    var isRunning: Bool { get }
    func windows() throws -> [BrowserWindowScripting]
    func activateApplication() throws
}

protocol BrowserWindowScripting {
    var identifier: Int? { get }
    var name: String { get }
    var activeTabIdentifier: Int? { get }
    var tabs: [BrowserTabScripting] { get }
    func selectTab(tabId: Int, tabIndex: Int) throws
    func bringToFront()
}

protocol BrowserTabScripting {
    var identifier: Int? { get }
    var title: String { get }
    var url: String { get }
    func close() throws
}

final class ScriptingBridgeTabAutomation: TabAutomating {
    private static let focusAttempts = 6
    private static let focusSleepMicroseconds: useconds_t = 120_000

    private let bundleId: String
    private let browser: BrowserScripting
    private let focuser: WindowFocusing

    init(
        bundleId: String,
        browser: BrowserScripting? = nil,
        focuser: WindowFocusing = AXWindowFocuser()
    ) {
        self.bundleId = bundleId
        self.browser = browser ?? ScriptingBridgeBrowser(bundleId: bundleId)
        self.focuser = focuser
    }

    func listTabs() throws -> [TabRecord] {
        var records: [TabRecord] = []
        try streamTabs { records.append($0) }
        return records
    }

    func streamTabs(_ emit: (TabRecord) throws -> Void) throws {
        guard browser.isRunning else {
            DebugLog.write("automation streamTabs: browser not running bundleId=\(bundleId)")
            return
        }

        DebugLog.write("automation streamTabs: begin bundleId=\(bundleId)")
        let windows = try browser.windows()
        DebugLog.write("automation streamTabs: windows=\(windows.count) bundleId=\(bundleId)")
        var emittedTabs = 0

        for (windowIndex, window) in windows.enumerated() {
            guard let windowId = window.identifier else {
                DebugLog.write("automation streamTabs: skipping windowIndex=\(windowIndex) without identifier")
                continue
            }

            let windowName = window.name
            DebugLog.write("automation streamTabs: reading tabs windowIndex=\(windowIndex) windowId=\(windowId)")
            let tabs = window.tabs
            DebugLog.write("automation streamTabs: windowIndex=\(windowIndex) windowId=\(windowId) tabsCount=\(tabs.count)")
            for tab in tabs {
                guard let tabId = tab.identifier else {
                    continue
                }

                try emit(
                    TabRecord(
                        windowId: windowId,
                        windowName: windowName,
                        tabId: tabId,
                        title: tab.title,
                        url: tab.url
                    )
                )
                emittedTabs += 1
            }
        }
        DebugLog.write("automation streamTabs: emittedTabs=\(emittedTabs) bundleId=\(bundleId)")
    }

    func activateTab(windowId: Int, tabId: Int) throws -> Bool {
        guard browser.isRunning else {
            DebugLog.write("automation activateTab: browser not running bundleId=\(bundleId)")
            throw CLIError.browserUnavailable("Browser '\(bundleId)' is not running.")
        }

        DebugLog.write("automation activateTab: begin windowId=\(windowId) tabId=\(tabId) bundleId=\(bundleId)")
        for attempt in 1...Self.focusAttempts {
            let windows = try browser.windows()
            guard let target = findTarget(windowId: windowId, tabId: tabId, windows: windows) else {
                DebugLog.write("automation activateTab: target not found windowId=\(windowId) tabId=\(tabId) bundleId=\(bundleId)")
                return false
            }

            try target.window.selectTab(tabId: tabId, tabIndex: target.tabIndex)
            target.window.bringToFront()
            try browser.activateApplication()

            let latestWindows = try browser.windows()
            let focusedWindowId = latestWindows.first?.identifier
            let targetWindowActiveTabId = latestWindows.first(where: { $0.identifier == windowId })?.activeTabIdentifier
            if targetWindowActiveTabId == tabId && focusedWindowId == windowId {
                DebugLog.write(
                    "automation activateTab: focused windowId=\(windowId) tabId=\(tabId) bundleId=\(bundleId) attempt=\(attempt) targetWindowActiveTabId=\(String(describing: targetWindowActiveTabId))"
                )
                return true
            }

            let didRaiseViaAX = focuser.raiseWindow(
                bundleId: bundleId,
                windowName: target.window.name,
                tabTitle: target.tab.title
            )
            if didRaiseViaAX {
                try target.window.selectTab(tabId: tabId, tabIndex: target.tabIndex)
                let raisedWindows = try browser.windows()
                let raisedFocusedWindowId = raisedWindows.first?.identifier
                let raisedTargetWindowActiveTabId = raisedWindows.first(where: { $0.identifier == windowId })?.activeTabIdentifier
                if raisedTargetWindowActiveTabId == tabId && raisedFocusedWindowId == windowId {
                    DebugLog.write(
                        "automation activateTab: focused-after-ax windowId=\(windowId) tabId=\(tabId) bundleId=\(bundleId) attempt=\(attempt)"
                    )
                    return true
                }
            }

            DebugLog.write(
                "automation activateTab: retry windowId=\(windowId) tabId=\(tabId) bundleId=\(bundleId) attempt=\(attempt) focusedWindowId=\(String(describing: focusedWindowId)) targetWindowActiveTabId=\(String(describing: targetWindowActiveTabId)) didRaiseViaAX=\(didRaiseViaAX)"
            )
            usleep(Self.focusSleepMicroseconds)
        }

        DebugLog.write(
            "automation activateTab: completed without focus confirmation windowId=\(windowId) tabId=\(tabId) bundleId=\(bundleId)"
        )
        return false
    }

    func closeTab(windowId: Int, tabId: Int) throws -> Bool {
        guard browser.isRunning else {
            DebugLog.write("automation closeTab: browser not running bundleId=\(bundleId)")
            throw CLIError.browserUnavailable("Browser '\(bundleId)' is not running.")
        }

        DebugLog.write("automation closeTab: begin windowId=\(windowId) tabId=\(tabId) bundleId=\(bundleId)")
        let windows = try browser.windows()
        guard let target = findTarget(windowId: windowId, tabId: tabId, windows: windows) else {
            DebugLog.write("automation closeTab: target not found windowId=\(windowId) tabId=\(tabId) bundleId=\(bundleId)")
            return false
        }

        try target.tab.close()
        DebugLog.write("automation closeTab: completed windowId=\(windowId) tabId=\(tabId) bundleId=\(bundleId)")
        return true
    }

    private func findTarget(
        windowId: Int,
        tabId: Int,
        windows: [BrowserWindowScripting]
    ) -> (window: BrowserWindowScripting, tab: BrowserTabScripting, tabIndex: Int)? {
        guard let window = windows.first(where: { $0.identifier == windowId }) else {
            return nil
        }

        for (index, tab) in window.tabs.enumerated() where tab.identifier == tabId {
            return (window, tab, index + 1)
        }

        return nil
    }
}

private final class ScriptingBridgeBrowser: BrowserScripting {
    private let bundleId: String
    private lazy var application: SBApplication? = SBApplication(bundleIdentifier: bundleId)

    init(bundleId: String) {
        self.bundleId = bundleId
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    func windows() throws -> [BrowserWindowScripting] {
        guard let application else {
            throw CLIError.scriptFailure(
                "Failed to create ScriptingBridge application for bundle id '\(bundleId)'."
            )
        }

        let windowsValue = application.codex_value(forSelector: "windows")
        return objectArray(from: windowsValue).map(ScriptingBridgeWindow.init(object:))
    }

    func activateApplication() throws {
        guard let application else {
            throw CLIError.scriptFailure(
                "Failed to create ScriptingBridge application for bundle id '\(bundleId)'."
            )
        }

        guard application.codex_invoke(selector: "activate") else {
            throw CLIError.scriptFailure("Failed to activate browser via ScriptingBridge.")
        }
    }
}

private final class ScriptingBridgeWindow: BrowserWindowScripting {
    private let object: NSObject

    init(object: NSObject) {
        self.object = object
    }

    var identifier: Int? {
        parseIdentifier(object.codex_value(forSelector: "id"))
    }

    var name: String {
        (object.codex_value(forSelector: "name") as? String) ?? ""
    }

    var activeTabIdentifier: Int? {
        guard let activeTabObject = object.codex_value(forSelector: "activeTab") as? NSObject else {
            return nil
        }
        return parseIdentifier(activeTabObject.codex_value(forSelector: "id"))
    }

    var tabs: [BrowserTabScripting] {
        objectArray(from: object.codex_value(forSelector: "tabs")).map(ScriptingBridgeTab.init(object:))
    }

    func selectTab(tabId: Int, tabIndex: Int) throws {
        if let tabObject = tabObject(forID: tabId),
           object.codex_set(value: tabObject, selector: "setActiveTab:") {
            DebugLog.write("automation selectTab: used setActiveTab tabId=\(tabId) tabIndex=\(tabIndex)")
            return
        }

        if object.codex_setInt(value: tabIndex, selector: "setActiveTabIndex:") {
            DebugLog.write("automation selectTab: used setActiveTabIndex(oneBased) tabId=\(tabId) tabIndex=\(tabIndex)")
            return
        }

        let zeroBasedIndex = max(0, tabIndex - 1)
        if object.codex_setInt(value: zeroBasedIndex, selector: "setActiveTabIndex:") {
            DebugLog.write("automation selectTab: used setActiveTabIndex(zeroBased) tabId=\(tabId) tabIndex=\(tabIndex)")
            return
        }

        DebugLog.write("automation selectTab: failed tabId=\(tabId) tabIndex=\(tabIndex)")
        throw CLIError.scriptFailure("Failed to set active tab via ScriptingBridge.")
    }

    private func tabObject(forID tabId: Int) -> NSObject? {
        guard let tabsObject = object.codex_value(forSelector: "tabs") as? NSObject else {
            return nil
        }

        let numericID = NSNumber(value: tabId)
        if let tabObject = tabsObject.codex_invokeObject(selector: "objectWithID:", value: numericID) as? NSObject {
            return tabObject
        }

        let stringID = NSString(string: String(tabId))
        if let tabObject = tabsObject.codex_invokeObject(selector: "objectWithID:", value: stringID) as? NSObject {
            return tabObject
        }

        return nil
    }

    func bringToFront() {
        // Conservative legacy-like behavior: only bring target window forward.
        _ = object.codex_setInt(value: 1, selector: "setIndex:")
    }
}

private final class ScriptingBridgeTab: BrowserTabScripting {
    private let object: NSObject

    init(object: NSObject) {
        self.object = object
    }

    var identifier: Int? {
        parseIdentifier(object.codex_value(forSelector: "id"))
    }

    var title: String {
        (object.codex_value(forSelector: "title") as? String) ?? ""
    }

    var url: String {
        parseURL(object.codex_value(forSelector: "URL"))
    }

    func close() throws {
        guard object.codex_invoke(selector: "close") else {
            throw CLIError.scriptFailure("Failed to close tab via ScriptingBridge.")
        }
    }
}

private extension NSObject {
    func codex_value(forSelector selectorName: String) -> Any? {
        let selector = NSSelectorFromString(selectorName)
        guard responds(to: selector) else {
            return nil
        }

        let key = selectorName.hasSuffix(":") ? String(selectorName.dropLast()) : selectorName
        guard !key.isEmpty, !key.contains(":") else {
            return nil
        }

        return value(forKey: key)
    }

    func codex_invoke(selector selectorName: String) -> Bool {
        let selector = NSSelectorFromString(selectorName)
        guard responds(to: selector) else {
            return false
        }
        _ = perform(selector)
        return true
    }

    func codex_set(value: AnyObject, selector selectorName: String) -> Bool {
        let selector = NSSelectorFromString(selectorName)
        guard responds(to: selector) else {
            return false
        }
        _ = perform(selector, with: value)
        return true
    }

    func codex_setInt(value: Int, selector selectorName: String) -> Bool {
        let selector = NSSelectorFromString(selectorName)
        guard responds(to: selector) else {
            return false
        }

        typealias Setter = @convention(c) (AnyObject, Selector, Int) -> Void
        let implementation = method(for: selector)
        let setter = unsafeBitCast(implementation, to: Setter.self)
        setter(self, selector, value)
        return true
    }

    func codex_invokeObject(selector selectorName: String, value: AnyObject) -> AnyObject? {
        let selector = NSSelectorFromString(selectorName)
        guard responds(to: selector) else {
            return nil
        }
        return perform(selector, with: value)?.takeUnretainedValue()
    }
}

private func objectArray(from value: Any?) -> [NSObject] {
    if let array = value as? [AnyObject] {
        return array.compactMap { $0 as? NSObject }
    }

    if let array = value as? NSArray {
        return array.compactMap { $0 as? NSObject }
    }

    return []
}

private func parseIdentifier(_ value: Any?) -> Int? {
    if let number = value as? NSNumber {
        return number.intValue
    }

    if let string = value as? String {
        return Int(string)
    }

    return nil
}

private func parseURL(_ value: Any?) -> String {
    if let string = value as? String {
        return string
    }

    if let url = value as? URL {
        return url.absoluteString
    }

    if let nsURL = value as? NSURL {
        return nsURL.absoluteString ?? ""
    }

    return ""
}
