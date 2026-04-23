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
                let stateHome = environment["XDG_STATE_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !stateHome.isEmpty {
                    let expandedStateHome = (stateHome as NSString).expandingTildeInPath
                    filePath = (expandedStateHome as NSString).appendingPathComponent("chrome-cli/chrome-cli.debug.log")
                } else {
                    let home = environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !home.isEmpty {
                        let expandedHome = (home as NSString).expandingTildeInPath
                        filePath = (expandedHome as NSString).appendingPathComponent("Library/Logs/chrome-cli/chrome-cli.debug.log")
                    } else {
                        filePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("chrome-cli.debug.log")
                    }
                }
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

        guard ensureLogFileExists(atPath: configuration.filePath) else {
            FileHandle.standardError.write(data)
            return
        }

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

    private static func ensureLogFileExists(atPath path: String) -> Bool {
        let directory = (path as NSString).deletingLastPathComponent
        if !ensureLogDirectory(atPath: directory) {
            return false
        }

        if fileManager.fileExists(atPath: path) {
            guard !isSymbolicLink(atPath: path) else {
                return false
            }
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            return true
        }

        let attributes: [FileAttributeKey: Any] = [
            .posixPermissions: 0o600
        ]
        return fileManager.createFile(atPath: path, contents: nil, attributes: attributes)
    }

    private static func ensureLogDirectory(atPath directory: String) -> Bool {
        guard !directory.isEmpty else {
            return true
        }

        var isDirectory = ObjCBool(false)
        if fileManager.fileExists(atPath: directory, isDirectory: &isDirectory) {
            guard isDirectory.boolValue, !isSymbolicLink(atPath: directory) else {
                return false
            }
            return true
        }

        do {
            try fileManager.createDirectory(
                atPath: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            return true
        } catch {
            return false
        }
    }

    private static func isSymbolicLink(atPath path: String) -> Bool {
        guard
            let attributes = try? fileManager.attributesOfItem(atPath: path),
            let fileType = attributes[.type] as? FileAttributeType
        else {
            return false
        }
        return fileType == .typeSymbolicLink
    }
}
