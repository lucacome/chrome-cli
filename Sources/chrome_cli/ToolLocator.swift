import Foundation

struct ToolLocator {
    private let environment: [String: String]
    private let fileManager: FileManager
    private let fallbackSearchPaths: [String]

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        fallbackSearchPaths: [String] = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin"]
    ) {
        self.environment = environment
        self.fileManager = fileManager
        self.fallbackSearchPaths = fallbackSearchPaths
    }

    func require(tool: String) throws -> String {
        if tool.contains("/") {
            if fileManager.isExecutableFile(atPath: tool) {
                return tool
            }
            throw CLIError.scriptFailure("Required tool '\(tool)' is not executable.")
        }

        for directory in searchPaths() {
            let candidate = (directory as NSString).appendingPathComponent(tool)
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        throw CLIError.scriptFailure(
            "Required tool '\(tool)' was not found in PATH. Install it to use tabs switch."
        )
    }

    private func searchPaths() -> [String] {
        if let pathValue = environment["PATH"], !pathValue.isEmpty {
            return pathValue
                .split(separator: ":")
                .map(String.init)
                .filter { !$0.isEmpty }
        }

        return fallbackSearchPaths
    }
}
