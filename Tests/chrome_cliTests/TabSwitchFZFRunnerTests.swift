import XCTest
@testable import chrome_cli

final class TabSwitchFZFRunnerTests: XCTestCase {
    func testArgumentsIncludeExpectedBindingsAndFieldMappings() {
        let runner = TabSwitchFZFRunner(
            fzfPath: "/usr/local/bin/fzf",
            pbcopyPath: "/usr/bin/pbcopy"
        )

        let args = runner.arguments(binaryCommand: "chrome-cli", bundleId: "com.brave.Browser")

        XCTAssertTrue(args.contains("--delimiter"))
        XCTAssertTrue(args.contains("--ansi"))
        XCTAssertFalse(args.contains("--listen"))
        XCTAssertTrue(args.contains("\t"))
        XCTAssertFalse(args.contains("--nth"))
        XCTAssertTrue(args.contains("--with-nth"))
        XCTAssertTrue(args.contains("4"))
        XCTAssertEqual(optionValue(args: args, option: "--header")?.contains("cache:"), true)

        let binds = extractBindValues(args: args)

        XCTAssertTrue(binds.contains {
            $0.contains("start:reload(") &&
            $0.contains("tabs _switch-source --resolved-bundle-id")
        })
        XCTAssertTrue(binds.contains {
            $0.contains("load:reload-sync(") &&
            $0.contains("tabs _switch-source-live") &&
            $0.contains("+transform-header(") &&
            $0.contains("tabs _switch-header") &&
            $0.contains("+unbind(load)")
        })
        XCTAssertTrue(binds.contains {
            $0.contains("ctrl-r:reload-sync(") &&
            $0.contains("tabs _switch-source-live") &&
            $0.contains("+transform-header(") &&
            $0.contains("tabs _switch-header")
        })

        XCTAssertTrue(binds.contains {
            $0.contains("enter:execute-silent(") &&
            $0.contains("tabs activate") &&
            $0.contains("--window-id {2}") &&
            $0.contains("--tab-id {3}")
        })

        XCTAssertTrue(binds.contains {
            $0.contains("ctrl-x:execute-silent(") &&
            $0.contains("tabs close") &&
            $0.contains("--window-id {2}") &&
            $0.contains("--tab-id {3}") &&
            $0.contains("tabs _switch-source-live") &&
            $0.contains("+reload-sync(") &&
            $0.contains("+transform-header(") &&
            $0.contains("tabs _switch-header")
        })

        XCTAssertTrue(binds.contains {
            $0.contains("ctrl-y:execute-silent(") &&
            $0.contains("printf %s {1}") &&
            $0.contains("pbcopy")
        })

        XCTAssertTrue(binds.contains {
            $0.contains("ctrl-u:execute-silent(") &&
            $0.contains("printf %s {5}") &&
            $0.contains("pbcopy")
        })
    }

    func testSourceCommandUsesHiddenSwitchSourceSubcommand() {
        let runner = TabSwitchFZFRunner(
            fzfPath: "/usr/local/bin/fzf",
            pbcopyPath: "/usr/bin/pbcopy"
        )

        let command = runner.sourceCommand(binaryCommand: "chrome-cli", bundleId: "com.brave.Browser")
        XCTAssertTrue(command.contains("tabs _switch-source --resolved-bundle-id"))
        XCTAssertTrue(command.contains("com.brave.Browser"))
    }

    func testRelativeAgeLabelFormatsExpectedUnits() {
        XCTAssertEqual(TabSwitchFZFRunner.relativeAgeLabel(seconds: -3), "just now")
        XCTAssertEqual(TabSwitchFZFRunner.relativeAgeLabel(seconds: 4), "just now")
        XCTAssertEqual(TabSwitchFZFRunner.relativeAgeLabel(seconds: 42), "42s ago")
        XCTAssertEqual(TabSwitchFZFRunner.relativeAgeLabel(seconds: 60), "1m ago")
        XCTAssertEqual(TabSwitchFZFRunner.relativeAgeLabel(seconds: 3_599), "59m ago")
        XCTAssertEqual(TabSwitchFZFRunner.relativeAgeLabel(seconds: 3_600), "1h ago")
        XCTAssertEqual(TabSwitchFZFRunner.relativeAgeLabel(seconds: 86_400), "1d ago")
        XCTAssertEqual(TabSwitchFZFRunner.relativeAgeLabel(seconds: 2_592_000), "1mo ago")
        XCTAssertEqual(TabSwitchFZFRunner.relativeAgeLabel(seconds: 31_536_000), "1y ago")
    }

    private func extractBindValues(args: [String]) -> [String] {
        var values: [String] = []
        var index = 0

        while index < args.count {
            if args[index] == "--bind", index + 1 < args.count {
                values.append(args[index + 1])
                index += 2
            } else {
                index += 1
            }
        }

        return values
    }

    private func optionValue(args: [String], option: String) -> String? {
        guard let index = args.firstIndex(of: option), index + 1 < args.count else {
            return nil
        }
        return args[index + 1]
    }
}
