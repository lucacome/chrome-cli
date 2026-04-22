import ArgumentParser
import Darwin
import Foundation

enum RuntimeEnvironment {
    nonisolated(unsafe) static var makeTabService: (BrowserOptions) throws -> TabServicing = defaultTabServiceFactory
    nonisolated(unsafe) static var runTabsSwitch: (_ service: TabServicing) throws -> Void = defaultTabsSwitchRunner
    nonisolated(unsafe) static var isInteractiveTerminal: () -> Bool = defaultIsInteractiveTerminal
    nonisolated(unsafe) static var outputFormat: () -> OutputFormat = defaultOutputFormat

    static func reset() {
        makeTabService = defaultTabServiceFactory
        runTabsSwitch = defaultTabsSwitchRunner
        isInteractiveTerminal = defaultIsInteractiveTerminal
        outputFormat = defaultOutputFormat
    }

    private static func defaultTabServiceFactory(options: BrowserOptions) throws -> TabServicing {
        let resolver = BrowserResolver(locator: WorkspaceApplicationLocator())
        let browser = try resolver.resolve(options: options)
        return TabService(
            browser: browser,
            automation: ScriptingBridgeTabAutomation(bundleId: browser.bundleId)
        )
    }

    private static func defaultTabsSwitchRunner(service: TabServicing) throws {
        DebugLog.write("tabs switch: resolving tools bundleId=\(service.browserMetadata.bundleId)")
        let locator = ToolLocator()
        let fzfPath = try locator.require(tool: "fzf", hint: "Install it to use tabs switch.")
        let pbcopyPath = try locator.require(tool: "pbcopy", hint: "Install it to copy selected values from tabs switch.")
        DebugLog.write("tabs switch: using fzfPath=\(fzfPath) pbcopyPath=\(pbcopyPath)")

        let runner = TabSwitchFZFRunner(fzfPath: fzfPath, pbcopyPath: pbcopyPath)
        let binaryCommand = CommandLine.arguments.first ?? "chrome-cli"
        DebugLog.write("tabs switch: commandLineBinary=\(binaryCommand)")
        try runner.run(binaryCommand: binaryCommand, bundleId: service.browserMetadata.bundleId)
        DebugLog.write("tabs switch: runner completed")
    }

    private static func defaultIsInteractiveTerminal() -> Bool {
        isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    }

    private static func defaultOutputFormat() -> OutputFormat {
        OutputFormat.from(environment: ProcessInfo.processInfo.environment)
    }
}

@main
struct ChromeCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chrome-cli",
        abstract: "Control Chromium browsers from the command line.",
        subcommands: [
            TabsCommand.self,
            VersionCommand.self,
            HelpCommand.self
        ]
    )

    @Option(name: .long, help: "Browser selection strategy: auto, brave, chrome.")
    var browser: BrowserSelection = .auto

    @Option(name: .long, help: "Override browser bundle id (takes precedence over --browser).")
    var bundleId: String?

    nonisolated(unsafe) private static var invocationOptions: BrowserOptions = .default

    static var currentBrowserOptions: BrowserOptions {
        invocationOptions
    }

    mutating func validate() throws {
        Self.invocationOptions = BrowserOptions(browser: browser, bundleId: bundleId)
    }

    func run() throws {
        throw CleanExit.helpRequest(Self.self)
    }

    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch let cleanExit as CleanExit {
            ChromeCLI.exit(withError: cleanExit)
        } catch {
            if shouldRenderUsage(error) {
                ChromeCLI.exit(withError: CleanExit.helpRequest(ChromeCLI.self))
            }

            let cliError = CLIError.from(error)
            JSONOutput.printError(cliError)
            Foundation.exit(cliError.exitCode)
        }
    }

    private static func shouldRenderUsage(_ error: Error) -> Bool {
        if error is ValidationError {
            return true
        }

        let errorType = String(reflecting: type(of: error))
        return errorType.contains("ArgumentParser")
    }
}

struct TabsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tabs",
        abstract: "Tab operations.",
        subcommands: [
            TabsListCommand.self,
            TabsActivateCommand.self,
            TabsCloseCommand.self,
            TabsSwitchCommand.self,
            TabsSwitchSourceCommand.self,
            TabsSwitchSourceLiveCommand.self,
            TabsSwitchHeaderCommand.self,
            TabsSwitchRefreshCommand.self
        ]
    )

    func run() throws {
        throw CleanExit.helpRequest(Self.self)
    }
}

struct TabsListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List tabs across all windows."
    )

    func run() throws {
        let service = try RuntimeEnvironment.makeTabService(ChromeCLI.currentBrowserOptions)

        switch RuntimeEnvironment.outputFormat() {
        case .json:
            try JSONOutput.printListTabsStreaming(browser: service.browserMetadata) { emit in
                try service.streamTabs(emit)
            }
        case .text:
            try TextOutput.printListTabsStreaming(browser: service.browserMetadata) { emit in
                try service.streamTabs(emit)
            }
        }
    }
}

struct TabsActivateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "activate",
        abstract: "Activate and focus a tab by composite id."
    )

    @Option(name: .long, help: "Window identifier.")
    var windowId: Int

    @Option(name: .long, help: "Tab identifier.")
    var tabId: Int

    func run() throws {
        let service = try RuntimeEnvironment.makeTabService(ChromeCLI.currentBrowserOptions)
        let response = try service.activateTab(windowId: windowId, tabId: tabId)

        switch RuntimeEnvironment.outputFormat() {
        case .json:
            try JSONOutput.printSuccess(response)
        case .text:
            TextOutput.printActivateTab(response)
        }
    }
}

struct TabsCloseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "close",
        abstract: "Close a tab by composite id."
    )

    @Option(name: .long, help: "Window identifier.")
    var windowId: Int

    @Option(name: .long, help: "Tab identifier.")
    var tabId: Int

    func run() throws {
        let service = try RuntimeEnvironment.makeTabService(ChromeCLI.currentBrowserOptions)
        let response = try service.closeTab(windowId: windowId, tabId: tabId)

        switch RuntimeEnvironment.outputFormat() {
        case .json:
            try JSONOutput.printSuccess(response)
        case .text:
            TextOutput.printCloseTab(response)
        }
    }
}

struct TabsSwitchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "switch",
        abstract: "Interactively fuzzy-search tabs and activate them."
    )

    func run() throws {
        guard RuntimeEnvironment.isInteractiveTerminal() else {
            DebugLog.write("tabs switch command: non-interactive terminal detected")
            throw CLIError.scriptFailure("tabs switch requires an interactive terminal.")
        }

        let service = try RuntimeEnvironment.makeTabService(ChromeCLI.currentBrowserOptions)
        DebugLog.write("tabs switch command: resolved bundleId=\(service.browserMetadata.bundleId)")
        try RuntimeEnvironment.runTabsSwitch(service)
    }
}

struct TabsSwitchSourceCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "_switch-source",
        abstract: "Internal helper command for tabs switch.",
        shouldDisplay: false
    )

    @Option(
        name: .customLong("resolved-bundle-id"),
        help: ArgumentHelp("Resolved browser bundle id.", visibility: .private)
    )
    var resolvedBundleId: String

    func run() throws {
        DebugLog.write("tabs switch source command: begin resolvedBundleId=\(resolvedBundleId)")
        let service = try RuntimeEnvironment.makeTabService(BrowserOptions(browser: .auto, bundleId: resolvedBundleId))
        let cache = TabSwitchCache(bundleId: service.browserMetadata.bundleId)
        let source = TabSwitchSource(service: service, cache: cache)
        try source.emitRowsToStdout()
        DebugLog.write("tabs switch source command: completed")
    }
}

struct TabsSwitchRefreshCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "_switch-refresh",
        abstract: "Internal helper command to refresh tabs switch cache.",
        shouldDisplay: false
    )

    @Option(
        name: .customLong("resolved-bundle-id"),
        help: ArgumentHelp("Resolved browser bundle id.", visibility: .private)
    )
    var resolvedBundleId: String

    func run() throws {
        DebugLog.write("tabs switch refresh command: begin resolvedBundleId=\(resolvedBundleId)")
        let service = try RuntimeEnvironment.makeTabService(BrowserOptions(browser: .auto, bundleId: resolvedBundleId))
        let cache = TabSwitchCache(bundleId: service.browserMetadata.bundleId)
        let source = TabSwitchSource(service: service, cache: cache)
        try source.refreshCache()
        DebugLog.write("tabs switch refresh command: completed")
    }
}

struct TabsSwitchSourceLiveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "_switch-source-live",
        abstract: "Internal helper command for live tabs switch source.",
        shouldDisplay: false
    )

    @Option(
        name: .customLong("resolved-bundle-id"),
        help: ArgumentHelp("Resolved browser bundle id.", visibility: .private)
    )
    var resolvedBundleId: String

    func run() throws {
        DebugLog.write("tabs switch source live command: begin resolvedBundleId=\(resolvedBundleId)")
        let service = try RuntimeEnvironment.makeTabService(BrowserOptions(browser: .auto, bundleId: resolvedBundleId))
        let cache = TabSwitchCache(bundleId: service.browserMetadata.bundleId)
        let source = TabSwitchSource(service: service, cache: cache)
        try source.emitRowsToStdoutLive()
        DebugLog.write("tabs switch source live command: completed")
    }
}

struct TabsSwitchHeaderCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "_switch-header",
        abstract: "Internal helper command for tabs switch header.",
        shouldDisplay: false
    )

    @Option(
        name: .customLong("resolved-bundle-id"),
        help: ArgumentHelp("Resolved browser bundle id.", visibility: .private)
    )
    var resolvedBundleId: String

    func run() throws {
        let text = TabSwitchHeader.text(bundleId: resolvedBundleId)
        FileHandle.standardOutput.write(Data(text.utf8))
        FileHandle.standardOutput.write(Data("\n".utf8))
        fflush(stdout)
    }
}

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print the chrome-cli version."
    )

    func run() throws {
        let response = VersionResponse(version: BuildInfo.version)
        switch RuntimeEnvironment.outputFormat() {
        case .json:
            try JSONOutput.printSuccess(response)
        case .text:
            TextOutput.printVersion(response)
        }
    }
}

struct HelpCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "help",
        abstract: "Show all available commands."
    )

    func run() throws {
        throw CleanExit.helpRequest(ChromeCLI.self)
    }
}
