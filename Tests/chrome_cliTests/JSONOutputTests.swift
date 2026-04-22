import XCTest
@testable import chrome_cli

final class JSONOutputTests: XCTestCase {
    func testRendersListTabsResponseAsStructuredJSON() throws {
        let response = ListTabsResponse(
            browser: BrowserMetadata(bundleId: "com.brave.Browser"),
            tabs: [
                TabRecord(
                    windowId: 1,
                    windowName: "Window",
                    tabId: 99,
                    title: "Example",
                    url: "https://example.com"
                )
            ]
        )

        let rendered = try JSONOutput.render(response)
        XCTAssertTrue(rendered.hasPrefix("{\n"))

        let decoded = try JSONDecoder().decode(ListTabsResponse.self, from: Data(rendered.utf8))
        XCTAssertEqual(decoded.browser.bundleId, "com.brave.Browser")
        XCTAssertEqual(decoded.tabs.count, 1)
        XCTAssertEqual(decoded.tabs[0].windowId, 1)
        XCTAssertEqual(decoded.tabs[0].windowName, "Window")
        XCTAssertEqual(decoded.tabs[0].tabId, 99)
        XCTAssertEqual(decoded.tabs[0].title, "Example")
        XCTAssertEqual(decoded.tabs[0].url, "https://example.com")
    }

    func testRendersErrorResponseAsStructuredJSON() throws {
        let response = ErrorResponse(error: ErrorPayload(code: 4, message: "Could not find tab 10 in window 9."))

        let rendered = try JSONOutput.render(response)
        XCTAssertTrue(rendered.hasPrefix("{\n"))

        let decoded = try JSONDecoder().decode(ErrorResponse.self, from: Data(rendered.utf8))
        XCTAssertEqual(decoded.error.code, 4)
        XCTAssertEqual(decoded.error.message, "Could not find tab 10 in window 9.")
    }
}
