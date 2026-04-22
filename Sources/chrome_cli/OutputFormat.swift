import Foundation

enum OutputFormat: Equatable {
    case text
    case json

    static func from(environment: [String: String]) -> OutputFormat {
        let raw = environment["OUTPUT_FORMAT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if raw == "json" {
            return .json
        }

        return .text
    }
}
