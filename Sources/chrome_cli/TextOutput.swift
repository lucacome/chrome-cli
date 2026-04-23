import Darwin
import Foundation

enum TextOutput {
    static func printListTabsStreaming(
        browser _: BrowserMetadata,
        produceTabs: (_ emit: (TabRecord) throws -> Void) throws -> Void
    ) throws {
        try produceTabs { tab in
            writeStdout(format(tab: tab))
        }
    }

    static func printActivateTab(_ response: ActivateTabResponse) {
        writeStdout("Activated [\(response.tab.windowId):\(response.tab.tabId)]")
    }

    static func printCloseTab(_ response: CloseTabResponse) {
        writeStdout("Closed [\(response.tab.windowId):\(response.tab.tabId)]")
    }

    static func printVersion(_ response: VersionResponse) {
        writeStdout(response.version)
    }

    private static func format(tab: TabRecord) -> String {
        let title = sanitize(tab.title)
        let url = sanitize(tab.url)
        let base = "[\(tab.windowId):\(tab.tabId)]"

        if title.isEmpty && url.isEmpty {
            return base
        }
        if title.isEmpty {
            return "\(base) \(url)"
        }
        if url.isEmpty {
            return "\(base) \(title)"
        }
        return "\(base) \(title) - \(url)"
    }

    private static func sanitize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func writeStdout(_ line: String) {
        FileHandle.standardOutput.write(Data(line.utf8))
        FileHandle.standardOutput.write(Data("\n".utf8))
        fflush(stdout)
    }
}
