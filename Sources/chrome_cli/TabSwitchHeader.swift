import Foundation

enum TabSwitchHeader {
    static let controls = "enter: activate | ctrl-x: close | ctrl-r: refresh | ctrl-y: copy id | ctrl-u: copy url | esc/ctrl-c/ctrl-d: quit"

    static func text(bundleId: String) -> String {
        "\(controls) | cache: \(TabSwitchCacheAge.cacheAgeLabel(bundleId: bundleId))"
    }
}
