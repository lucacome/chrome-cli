import XCTest
@testable import chrome_cli

final class TabSwitchModelsTests: XCTestCase {
    func testSearchTextStripsANSIEscapeSequences() {
        let row = TabSwitchRow(
            compositeId: "1:2",
            windowId: 1,
            tabId: 2,
            display: "\u{1B}[31mTitle\u{1B}[0m",
            url: "https://example.com"
        )

        XCTAssertEqual(row.searchText, "Title https://example.com")
        XCTAssertFalse(row.searchText.contains("\u{1B}"))
    }
}
