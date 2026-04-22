import Foundation

struct TabSwitchRow: Equatable {
    let compositeId: String
    let windowId: Int
    let tabId: Int
    let display: String
    let url: String
    let searchText: String

    init(tab: TabRecord) {
        self.windowId = tab.windowId
        self.tabId = tab.tabId
        self.compositeId = "\(tab.windowId):\(tab.tabId)"
        self.url = Self.normalize(tab.url)
        let title = Self.normalize(tab.title)
        let tabPrefix = Self.colorize("[•]", colorCode: "38;5;39")
        let urlPrefix = Self.colorize("[↗]", colorCode: "38;5;214")
        let styledURL = url.isEmpty ? "" : Self.colorize(url, colorCode: "38;5;81")
        self.searchText = Self.normalize([title, url].filter { !$0.isEmpty }.joined(separator: " "))
        if title.isEmpty {
            self.display = url.isEmpty ? "" : "\(urlPrefix) \(styledURL)"
        } else if url.isEmpty {
            self.display = "\(tabPrefix) \(title)"
        } else {
            self.display = "\(tabPrefix) \(title)  \(urlPrefix) \(styledURL)"
        }
    }

    init(
        compositeId: String,
        windowId: Int,
        tabId: Int,
        display: String,
        url: String,
        searchText: String? = nil
    ) {
        self.compositeId = Self.normalize(compositeId)
        self.windowId = windowId
        self.tabId = tabId
        self.display = Self.normalize(display)
        self.url = Self.normalize(url)
        let defaultSearchText = [Self.stripANSI(self.display), self.url]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        self.searchText = Self.normalize(searchText ?? defaultSearchText)
    }

    var tsvLine: String {
        [
            compositeId,
            String(windowId),
            String(tabId),
            display,
            url,
            searchText,
        ].joined(separator: "\t")
    }

    static func parse(tsvLine: String) -> TabSwitchRow? {
        let fields = tsvLine.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count >= 5 else {
            return nil
        }

        let compositeId = String(fields[0])
        let windowId = Int(fields[1])
        let tabId = Int(fields[2])
        let display = String(fields[3])
        let url = String(fields[4])
        let searchText = fields.count >= 6 ? String(fields[5]) : nil

        guard let windowId, let tabId else {
            return nil
        }

        return TabSwitchRow(
            compositeId: compositeId,
            windowId: windowId,
            tabId: tabId,
            display: display,
            url: url,
            searchText: searchText
        )
    }

    private static func normalize(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func colorize(_ text: String, colorCode: String) -> String {
        "\u{001B}[\(colorCode)m\(text)\u{001B}[0m"
    }

    private static func stripANSI(_ input: String) -> String {
        let ansiPattern = #"\u{001B}\[[0-9;]*m"#
        return input.replacingOccurrences(of: ansiPattern, with: "", options: .regularExpression)
    }
}
