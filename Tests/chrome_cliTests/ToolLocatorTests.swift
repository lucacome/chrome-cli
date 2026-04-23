import Darwin
import XCTest
@testable import chrome_cli

final class ToolLocatorTests: XCTestCase {
    func testFindsExecutableInPATH() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let toolPath = temp.appendingPathComponent("fzf")
        FileManager.default.createFile(atPath: toolPath.path, contents: Data())
        chmod(toolPath.path, 0o755)

        let locator = ToolLocator(environment: ["PATH": temp.path])
        let resolved = try locator.require(tool: "fzf")

        XCTAssertEqual(resolved, toolPath.path)
    }

    func testMissingFZFThrowsScriptFailure() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let locator = ToolLocator(environment: ["PATH": temp.path])

        XCTAssertThrowsError(try locator.require(tool: "fzf")) { error in
            guard case let .scriptFailure(message) = (error as? CLIError) else {
                XCTFail("Expected scriptFailure")
                return
            }

            XCTAssertTrue(message.contains("fzf"))
        }
    }

    func testMissingPBCopyThrowsScriptFailure() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let locator = ToolLocator(environment: ["PATH": temp.path])

        XCTAssertThrowsError(try locator.require(tool: "pbcopy")) { error in
            guard case let .scriptFailure(message) = (error as? CLIError) else {
                XCTFail("Expected scriptFailure")
                return
            }

            XCTAssertTrue(message.contains("pbcopy"))
        }
    }

    private func makeTempDirectory() throws -> URL {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("chrome-cli-tests-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        return temp
    }
}
