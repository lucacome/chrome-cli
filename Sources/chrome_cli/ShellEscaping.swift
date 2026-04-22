import Foundation

func shellEscape(_ value: String) -> String {
    if value.isEmpty {
        return "''"
    }

    return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
}
