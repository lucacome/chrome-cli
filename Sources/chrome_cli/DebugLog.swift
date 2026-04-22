import Darwin
import Foundation

enum DebugLog {
    private struct Configuration {
        let enabled: Bool
        let filePath: String

        init(environment: [String: String]) {
            let rawFlag = environment["CHROME_CLI_DEBUG"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            enabled = Self.parseEnabled(rawFlag)

            let rawPath = environment["CHROME_CLI_DEBUG_LOG"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if rawPath.isEmpty {
                filePath = "/tmp/chrome-cli.debug.log"
            } else {
                filePath = (rawPath as NSString).expandingTildeInPath
            }
        }

        private static func parseEnabled(_ value: String) -> Bool {
            switch value {
            case "1", "true", "yes", "on":
                return true
            default:
                return false
            }
        }
    }

    private static let lock = NSLock()
    private static let configuration = Configuration(environment: ProcessInfo.processInfo.environment)
    private static let fileManager = FileManager.default

    static var isEnabled: Bool {
        configuration.enabled
    }

    static func write(_ message: @autoclosure () -> String) {
        guard configuration.enabled else {
            return
        }

        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        let line = "[\(timestamp)] pid=\(getpid()) \(message())\n"
        let data = Data(line.utf8)

        lock.lock()
        defer { lock.unlock() }

        ensureLogFileExists(atPath: configuration.filePath)

        if let handle = FileHandle(forWritingAtPath: configuration.filePath) {
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
                return
            } catch {
                try? handle.close()
            }
        }

        FileHandle.standardError.write(data)
    }

    private static func ensureLogFileExists(atPath path: String) {
        let directory = (path as NSString).deletingLastPathComponent
        if !directory.isEmpty {
            try? fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        }

        if !fileManager.fileExists(atPath: path) {
            _ = fileManager.createFile(atPath: path, contents: nil)
        }
    }
}
