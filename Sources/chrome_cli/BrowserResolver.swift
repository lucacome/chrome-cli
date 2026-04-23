import AppKit
import ArgumentParser
import Foundation

enum BrowserSelection: String, CaseIterable, ExpressibleByArgument {
    case auto
    case brave
    case chrome
}

struct BrowserOptions: Equatable {
    var browser: BrowserSelection
    var bundleId: String?

    static let `default` = BrowserOptions(browser: .auto, bundleId: nil)
}

struct BrowserTarget: Equatable {
    let bundleId: String
}

protocol ApplicationLocating {
    func isInstalled(bundleIdentifier: String) -> Bool
}

struct WorkspaceApplicationLocator: ApplicationLocating {
    func isInstalled(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
}

struct BrowserResolver {
    private let locator: ApplicationLocating

    private let braveBundleID = "com.brave.Browser"
    private let chromeBundleID = "com.google.Chrome"

    init(locator: ApplicationLocating) {
        self.locator = locator
    }

    func resolve(options: BrowserOptions) throws -> BrowserTarget {
        if let overrideBundleId = normalize(bundleId: options.bundleId) {
            guard locator.isInstalled(bundleIdentifier: overrideBundleId) else {
                throw CLIError.browserUnavailable("No installed browser matches bundle id '\(overrideBundleId)'.")
            }
            return BrowserTarget(bundleId: overrideBundleId)
        }

        switch options.browser {
        case .auto:
            if locator.isInstalled(bundleIdentifier: braveBundleID) {
                return BrowserTarget(bundleId: braveBundleID)
            }
            if locator.isInstalled(bundleIdentifier: chromeBundleID) {
                return BrowserTarget(bundleId: chromeBundleID)
            }
            throw CLIError.browserUnavailable("Unable to locate Brave or Chrome on this machine.")

        case .brave:
            guard locator.isInstalled(bundleIdentifier: braveBundleID) else {
                throw CLIError.browserUnavailable("Brave is not installed.")
            }
            return BrowserTarget(bundleId: braveBundleID)

        case .chrome:
            guard locator.isInstalled(bundleIdentifier: chromeBundleID) else {
                throw CLIError.browserUnavailable("Chrome is not installed.")
            }
            return BrowserTarget(bundleId: chromeBundleID)
        }
    }

    private func normalize(bundleId: String?) -> String? {
        guard let bundleId else {
            return nil
        }

        let trimmed = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
