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
        let duplicateSourceCommand = "\(shellEscape(binaryCommand)) tabs _switch-source-duplicates --resolved-bundle-id \(shellEscape(bundleId))"
        let duplicateLiveSourceCommand = "\(shellEscape(binaryCommand)) tabs _switch-source-duplicates-live --resolved-bundle-id \(shellEscape(bundleId))"
        let allHeaderCommand = switchHeaderCommand(binaryCommand: binaryCommand, bundleId: bundleId, mode: .all)
        let duplicateHeaderCommand = switchHeaderCommand(binaryCommand: binaryCommand, bundleId: bundleId, mode: .duplicates)
        let modeHeaderCommand = modeHeaderCommand(allHeaderCommand: allHeaderCommand, duplicateHeaderCommand: duplicateHeaderCommand)
        let header = headerText(bundleId: bundleId)
        let prompt = "tabs> "
        let duplicatePrompt = "duplicates> "

        let activateCommand =
            "\(shellEscape(binaryCommand)) --bundle-id \(shellEscape(bundleId)) tabs activate --window-id {2} --tab-id {3} >/dev/null 2>&1"

        let closeCommand =
            "\(shellEscape(binaryCommand)) --bundle-id \(shellEscape(bundleId)) tabs close --window-id {2} --tab-id {3} >/dev/null 2>&1"

        let copyIDCommand = "printf %s {1} | \(shellEscape(pbcopyPath)) >/dev/null 2>&1"
        let copyURLCommand = "printf %s {5} | \(shellEscape(pbcopyPath)) >/dev/null 2>&1"
        let liveRefreshAction = "reload-sync(\(liveSourceCommand))+transform-header(\(allHeaderCommand))"
        let duplicateLiveRefreshAction = "reload-sync(\(duplicateLiveSourceCommand))+transform-header(\(duplicateHeaderCommand))"
        let toggleDuplicateAction = transformCommand(
            duplicatePrompt: duplicatePrompt,
            duplicateModeAction: [
                "change-prompt(\(prompt))",
                "reload-sync(\(sourceCommand))",
                "transform-header(\(allHeaderCommand))",
            ].joined(separator: "+"),
            allModeAction: [
                "change-prompt(\(duplicatePrompt))",
                "reload-sync(\(duplicateSourceCommand))",
                "transform-header(\(duplicateHeaderCommand))",
            ].joined(separator: "+")
        )
        let refreshAction = transformCommand(
            duplicatePrompt: duplicatePrompt,
            duplicateModeAction: duplicateLiveRefreshAction,
            allModeAction: liveRefreshAction
        )
        let afterCloseAction = transformCommand(
            duplicatePrompt: duplicatePrompt,
            duplicateModeAction: duplicateLiveRefreshAction,
            allModeAction: "exclude+transform-header(\(allHeaderCommand))"
        )

        return [
            "--exact",
            "--ansi",
            "--delimiter", "\t",
            "--with-nth", "4",
            "--prompt", prompt,
            "--header", header,
            "--bind", "start:reload(\(sourceCommand))",
            "--bind", "load:reload-sync(\(liveSourceCommand))+transform-header(\(allHeaderCommand))+unbind(load)",
            "--bind", "ctrl-r:transform:\(refreshAction)",
            "--bind", "enter:execute-silent(\(activateCommand))",
            "--bind", "ctrl-x:execute-silent(\(closeCommand))+transform:\(afterCloseAction)",
            "--bind", "ctrl-y:execute-silent(\(copyIDCommand))",
            "--bind", "ctrl-u:execute-silent(\(copyURLCommand))",
            "--bind", "focus:transform-header(\(modeHeaderCommand))",
            "--bind", "result:transform-header(\(modeHeaderCommand))",
            "--bind", "ctrl-d:transform:\(toggleDuplicateAction)",
            "--bind", "ctrl-c:abort",
        ]
    }

    func sourceCommand(binaryCommand: String, bundleId: String) -> String {
        "\(shellEscape(binaryCommand)) tabs _switch-source --resolved-bundle-id \(shellEscape(bundleId))"
    }

    private func headerText(bundleId: String) -> String {
        TabSwitchHeader.text(bundleId: bundleId)
    }

    private func switchHeaderCommand(binaryCommand: String, bundleId: String, mode: TabSwitchHeader.Mode) -> String {
        "\(shellEscape(binaryCommand)) tabs _switch-header --resolved-bundle-id \(shellEscape(bundleId)) --mode \(mode.rawValue)"
    }

    private func modeHeaderCommand(allHeaderCommand: String, duplicateHeaderCommand: String) -> String {
        "[ \"$FZF_PROMPT\" = \"duplicates> \" ] && \(duplicateHeaderCommand) || \(allHeaderCommand)"
    }

    private func transformCommand(
        duplicatePrompt: String,
        duplicateModeAction: String,
        allModeAction: String
    ) -> String {
        let duplicateBranch = "printf %s \(shellEscape(duplicateModeAction))"
        let allBranch = "printf %s \(shellEscape(allModeAction))"
        return "[ \"$FZF_PROMPT\" = \(shellEscape(duplicatePrompt)) ] && \(duplicateBranch) || \(allBranch)"
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
