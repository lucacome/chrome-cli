import XCTest
@testable import chrome_cli

final class OutputFormatTests: XCTestCase {
    func testDefaultOutputFormatIsText() {
        XCTAssertEqual(OutputFormat.from(environment: [:]), .text)
    }

    func testOutputFormatParsesJSONCaseInsensitive() {
        XCTAssertEqual(OutputFormat.from(environment: ["OUTPUT_FORMAT": "json"]), .json)
        XCTAssertEqual(OutputFormat.from(environment: ["OUTPUT_FORMAT": "JSON"]), .json)
    }

    func testOutputFormatTrimsWhitespaceAndFallsBackToText() {
        XCTAssertEqual(OutputFormat.from(environment: ["OUTPUT_FORMAT": "  json\n"]), .json)
        XCTAssertEqual(OutputFormat.from(environment: ["OUTPUT_FORMAT": "yaml"]), .text)
    }
}
