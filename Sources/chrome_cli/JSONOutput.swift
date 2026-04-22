import Darwin
import Foundation

enum JSONOutput {
    static func render<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        if #available(macOS 13, *) {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CLIError.scriptFailure("Unable to encode JSON output as UTF-8.")
        }
        return text
    }

    static func printSuccess<T: Encodable>(_ value: T) throws {
        let text = try render(value)
        FileHandle.standardOutput.write(Data(text.utf8))
        FileHandle.standardOutput.write(Data("\n".utf8))
        fflush(stdout)
    }

    static func printListTabsStreaming(
        browser: BrowserMetadata,
        produceTabs: (_ emit: (TabRecord) throws -> Void) throws -> Void
    ) throws {
        let browserJSON = try compact(browser)

        writeStdout("{\n")
        writeStdout("  \"browser\" : \(browserJSON),\n")
        writeStdout("  \"tabs\" : [\n")
        fflush(stdout)

        var first = true
        try produceTabs { tab in
            let tabJSON = try compact(tab)
            if first {
                writeStdout("    \(tabJSON)")
                first = false
            } else {
                writeStdout(",\n    \(tabJSON)")
            }
            fflush(stdout)
        }

        if !first {
            writeStdout("\n")
        }
        writeStdout("  ]\n")
        writeStdout("}\n")
        fflush(stdout)
    }

    static func printError(_ error: CLIError) {
        let response = ErrorResponse(error: ErrorPayload(code: Int(error.exitCode), message: error.message))

        let text: String
        do {
            text = try render(response)
        } catch {
            text = "{\"error\":{\"code\":5,\"message\":\"Failed to encode error output.\"}}"
        }

        FileHandle.standardError.write(Data(text.utf8))
        FileHandle.standardError.write(Data("\n".utf8))
        fflush(stderr)
    }

    private static func compact<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        if #available(macOS 13, *) {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }

        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CLIError.scriptFailure("Unable to encode compact JSON output as UTF-8.")
        }
        return text
    }

    private static func writeStdout(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }
}
