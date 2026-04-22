import XCTest
@testable import chrome_cli

final class JSONOutputTests: XCTestCase {
    func testRendersListTabsResponseAsStableJSON() throws {
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
        let expected = #"{"# + "\n" +
        #"  "browser" : {"# + "\n" +
        #"    "bundleId" : "com.brave.Browser""# + "\n" +
        #"  },"# + "\n" +
        #"  "tabs" : ["# + "\n" +
        #"    {"# + "\n" +
        #"      "tabId" : 99,"# + "\n" +
        #"      "title" : "Example","# + "\n" +
        #"      "url" : "https://example.com","# + "\n" +
        #"      "windowId" : 1,"# + "\n" +
        #"      "windowName" : "Window""# + "\n" +
        #"    }"# + "\n" +
        #"  ]"# + "\n" +
        #"}"#

        XCTAssertEqual(rendered, expected)
    }

    func testRendersErrorResponseAsStableJSON() throws {
        let response = ErrorResponse(error: ErrorPayload(code: 4, message: "Could not find tab 10 in window 9."))

        let rendered = try JSONOutput.render(response)
        let expected = #"{"# + "\n" +
        #"  "error" : {"# + "\n" +
        #"    "code" : 4,"# + "\n" +
        #"    "message" : "Could not find tab 10 in window 9.""# + "\n" +
        #"  }"# + "\n" +
        #"}"#

        XCTAssertEqual(rendered, expected)
    }
}
