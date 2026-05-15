import Foundation

enum TabSwitchHeader {
    enum Mode: String {
        case all
        case duplicates
    }

    static let controls = "enter: activate | ctrl-x: close | ctrl-r: refresh | ctrl-d: duplicates | ctrl-y: copy id | ctrl-u: copy url | esc/ctrl-c: quit"

    static func text(bundleId: String, mode: Mode = .all) -> String {
        let modeText = mode == .duplicates ? "duplicates" : "all"
        return "\(controls) | mode: \(modeText) | cache: \(TabSwitchCacheAge.cacheAgeLabel(bundleId: bundleId))"
    }
}
