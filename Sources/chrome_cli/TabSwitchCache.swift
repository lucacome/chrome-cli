import Foundation

struct TabSwitchCache {
    private static let cacheSchemaVersion = "v3"
    private let fileManager: FileManager
    private let cacheFileURL: URL

    init(
        bundleId: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        let rootPath: String
        if let xdg = environment["XDG_CACHE_HOME"], !xdg.isEmpty {
            rootPath = xdg
        } else if let home = environment["HOME"], !home.isEmpty {
            rootPath = (home as NSString).appendingPathComponent(".cache")
        } else {
            rootPath = NSTemporaryDirectory()
        }

        let cacheDirectory = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent("chrome-cli", isDirectory: true)

        let safeBundleId = Self.safePathComponent(bundleId)
        self.cacheFileURL = cacheDirectory.appendingPathComponent("tabs-switch-\(Self.cacheSchemaVersion)-\(safeBundleId).tsv")
    }

    var fileURL: URL {
        cacheFileURL
    }

    func readRows() throws -> [TabSwitchRow] {
        guard fileManager.fileExists(atPath: cacheFileURL.path) else {
            return []
        }

        let content = try String(contentsOf: cacheFileURL, encoding: .utf8)
        return content
            .split(whereSeparator: \ .isNewline)
            .compactMap { TabSwitchRow.parse(tsvLine: String($0)) }
    }

    func writeRows(_ rows: [TabSwitchRow]) throws {
        let directory = cacheFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let payload = rows.map(\ .tsvLine).joined(separator: "\n") + (rows.isEmpty ? "" : "\n")
        try payload.write(to: cacheFileURL, atomically: true, encoding: .utf8)
    }

    private static func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.map(String.init).joined()
    }
}
