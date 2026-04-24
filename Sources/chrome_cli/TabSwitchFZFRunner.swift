import Darwin
import Foundation

struct TabSwitchFZFRunner {
    let fzfPath: String
    let pbcopyPath: String

    func run(binaryCommand: String, bundleId: String) throws {
        let executableCommand = resolvedBinaryCommand(binaryCommand)
        DebugLog.write("tabs switch runner: start bundleId=\(bundleId) binary=\(binaryCommand) resolvedBinary=\(executableCommand)")

        let args = arguments(binaryCommand: executableCommand, bundleId: bundleId)
        DebugLog.write("tabs switch runner: fzfPath=\(fzfPath)")
        DebugLog.write("tabs switch runner: fzfArgs=\(args)")
        DebugLog.write("tabs switch runner: launching via execv")

        var argv: [UnsafeMutablePointer<CChar>?] = []
        argv.reserveCapacity(args.count + 2)
        argv.append(strdup(fzfPath))
        for arg in args {
            argv.append(strdup(arg))
        }
        argv.append(nil)

        defer {
            for pointer in argv where pointer != nil {
                free(pointer)
            }
        }

        execv(fzfPath, argv)
        let launchError = errno
        let launchErrorMessage = String(cString: strerror(launchError))
        DebugLog.write("tabs switch runner: execv failed errno=\(launchError) message=\(launchErrorMessage)")
        throw CLIError.scriptFailure("Failed to launch fzf: \(launchErrorMessage)")
    }

    func arguments(binaryCommand: String, bundleId: String) -> [String] {
        let sourceCommand = "\(shellEscape(binaryCommand)) tabs _switch-source --resolved-bundle-id \(shellEscape(bundleId))"
        let liveSourceCommand = "\(shellEscape(binaryCommand)) tabs _switch-source-live --resolved-bundle-id \(shellEscape(bundleId))"
        let headerCommand = "\(shellEscape(binaryCommand)) tabs _switch-header --resolved-bundle-id \(shellEscape(bundleId))"
        let header = headerText(bundleId: bundleId)

        let activateCommand =
            "\(shellEscape(binaryCommand)) --bundle-id \(shellEscape(bundleId)) tabs activate --window-id {2} --tab-id {3} >/dev/null 2>&1"

        let closeCommand =
            "\(shellEscape(binaryCommand)) --bundle-id \(shellEscape(bundleId)) tabs close --window-id {2} --tab-id {3} >/dev/null 2>&1"

        let copyIDCommand = "printf %s {1} | \(shellEscape(pbcopyPath)) >/dev/null 2>&1"
        let copyURLCommand = "printf %s {5} | \(shellEscape(pbcopyPath)) >/dev/null 2>&1"

        return [
            "--exact",
            "--ansi",
            "--delimiter", "\t",
            "--with-nth", "4",
            "--header", header,
            "--bind", "start:reload(\(sourceCommand))",
            "--bind", "load:reload-sync(\(liveSourceCommand))+transform-header(\(headerCommand))+unbind(load)",
            "--bind", "ctrl-r:reload-sync(\(liveSourceCommand))+transform-header(\(headerCommand))",
            "--bind", "enter:execute-silent(\(activateCommand))",
            "--bind", "ctrl-x:execute-silent(\(closeCommand))+exclude+transform-header(\(headerCommand))",
            "--bind", "ctrl-y:execute-silent(\(copyIDCommand))",
            "--bind", "ctrl-u:execute-silent(\(copyURLCommand))",
            "--bind", "focus:transform-header(\(headerCommand))",
            "--bind", "result:transform-header(\(headerCommand))",
            "--bind", "ctrl-d:abort",
            "--bind", "ctrl-c:abort",
        ]
    }

    func sourceCommand(binaryCommand: String, bundleId: String) -> String {
        "\(shellEscape(binaryCommand)) tabs _switch-source --resolved-bundle-id \(shellEscape(bundleId))"
    }

    private func headerText(bundleId: String) -> String {
        TabSwitchHeader.text(bundleId: bundleId)
    }

    private func cacheLastRefreshedLabel(bundleId: String) -> String {
        TabSwitchCacheAge.cacheAgeLabel(bundleId: bundleId)
    }

    static func relativeAgeLabel(seconds: Int) -> String {
        TabSwitchCacheAge.relativeAgeLabel(seconds: seconds)
    }

    private func resolvedBinaryCommand(_ binaryCommand: String) -> String {
        guard binaryCommand.contains("/") else {
            return binaryCommand
        }

        if binaryCommand.hasPrefix("/") {
            return binaryCommand
        }

        let currentDirectory = FileManager.default.currentDirectoryPath
        let absoluteURL = URL(fileURLWithPath: currentDirectory, isDirectory: true)
            .appendingPathComponent(binaryCommand)
            .standardizedFileURL
        return absoluteURL.path
    }
}
