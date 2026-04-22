import XCTest
@testable import chrome_cli

final class BrowserResolverTests: XCTestCase {
    func testResolveAutoPrefersBrave() throws {
        let locator = FakeLocator(installedBundleIDs: ["com.brave.Browser", "com.google.Chrome"])
        let resolver = BrowserResolver(locator: locator)

        let target = try resolver.resolve(options: BrowserOptions(browser: .auto, bundleId: nil))
        XCTAssertEqual(target.bundleId, "com.brave.Browser")
    }

    func testResolveAutoFallsBackToChrome() throws {
        let locator = FakeLocator(installedBundleIDs: ["com.google.Chrome"])
        let resolver = BrowserResolver(locator: locator)

        let target = try resolver.resolve(options: BrowserOptions(browser: .auto, bundleId: nil))
        XCTAssertEqual(target.bundleId, "com.google.Chrome")
    }

    func testResolveAutoThrowsWhenNoBrowserIsInstalled() {
        let locator = FakeLocator(installedBundleIDs: [])
        let resolver = BrowserResolver(locator: locator)

        XCTAssertThrowsError(try resolver.resolve(options: BrowserOptions(browser: .auto, bundleId: nil))) { error in
            XCTAssertEqual(error as? CLIError, CLIError.browserUnavailable("Unable to locate Brave or Chrome on this machine."))
        }
    }

    func testResolveBundleIdOverrideTakesPrecedence() throws {
        let locator = FakeLocator(installedBundleIDs: ["org.chromium.Chromium"])
        let resolver = BrowserResolver(locator: locator)

        let target = try resolver.resolve(
            options: BrowserOptions(browser: .chrome, bundleId: "org.chromium.Chromium")
        )
        XCTAssertEqual(target.bundleId, "org.chromium.Chromium")
    }

    func testResolveBundleIdOverrideThrowsIfNotInstalled() {
        let locator = FakeLocator(installedBundleIDs: [])
        let resolver = BrowserResolver(locator: locator)

        XCTAssertThrowsError(
            try resolver.resolve(options: BrowserOptions(browser: .auto, bundleId: "com.example.DoesNotExist"))
        ) { error in
            XCTAssertEqual(
                error as? CLIError,
                CLIError.browserUnavailable("No installed browser matches bundle id 'com.example.DoesNotExist'.")
            )
        }
    }
}

private struct FakeLocator: ApplicationLocating {
    let installedBundleIDs: Set<String>

    init(installedBundleIDs: [String]) {
        self.installedBundleIDs = Set(installedBundleIDs)
    }

    func isInstalled(bundleIdentifier: String) -> Bool {
        installedBundleIDs.contains(bundleIdentifier)
    }
}
