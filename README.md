# chrome-cli

## Overview

`chrome-cli` is a native Swift command line tool for controlling Chromium-based browsers on macOS.
This release is a strict Swift rewrite (SwiftPM only) and uses native Apple Events via ScriptingBridge.

## Requirements

- macOS 13.0+
- Swift 5.10+

## Build

```bash
swift build -c release
```

Binary path:

```bash
.build/release/chrome-cli
```

## Browser Resolution

`chrome-cli` resolves the target browser using the following order:

1. `--bundle-id` (explicit override)
2. `--browser brave|chrome`
3. `--browser auto` (default): Brave first, Chrome fallback

Examples:

```bash
chrome-cli --browser auto tabs list
chrome-cli --browser chrome tabs list
chrome-cli --bundle-id org.chromium.Chromium tabs list
```

## Command Surface (v1)

```bash
chrome-cli help
chrome-cli [--browser <auto|brave|chrome>] [--bundle-id <id>] tabs list
chrome-cli [--browser <auto|brave|chrome>] [--bundle-id <id>] tabs activate --window-id <id> --tab-id <id>
chrome-cli [--browser <auto|brave|chrome>] [--bundle-id <id>] tabs close --window-id <id> --tab-id <id>
chrome-cli [--browser <auto|brave|chrome>] [--bundle-id <id>] tabs switch
chrome-cli version
```

## Output

Default output is human-readable text.
Set `OUTPUT_FORMAT=json` to get JSON output.

### `tabs list` (default text)

```text
[101:1001] README - https://github.com
```

`tabs list` streams rows and flushes stdout as tabs are discovered.

### `tabs activate` (default text)

```text
Activated [101:1001]
```

### `tabs close` (default text)

```text
Closed [101:1001]
```

### `tabs switch`

Interactive fuzzy picker powered by `fzf`.

- `Enter`: activate selected tab and keep picker open
- `Ctrl-X`: close selected tab and reload rows
- `Ctrl-R`: refresh rows from live tabs (keeps current list until refresh completes)
- `Ctrl-Y`: copy `<windowId>:<tabId>` to clipboard
- `Ctrl-U`: copy selected tab URL to clipboard
- `Esc`, `Ctrl-C`, `Ctrl-D`: quit

`tabs switch` prints no success payload and is intended for TTY usage.

### `version`

```text
2.0.0
```

## Error Contract

Runtime errors are emitted as JSON on stderr:

```json
{
  "error": {
    "code": 4,
    "message": "Could not find tab 1001 in window 101."
  }
}
```

Exit codes:

- `2`: invalid CLI input
- `3`: browser unavailable
- `4`: tab/window not found
- `5`: scripting or automation failure

Parser/usage errors (unknown command, missing required args, invalid flags) show usage/help text instead of JSON error payloads.

## Interactive Dependencies

`tabs switch` requires:

- `fzf`
- `pbcopy`

## Debug Logging

Set `CHROME_CLI_DEBUG=1` to enable debug logs.

- default log file: `/tmp/chrome-cli.debug.log`
- override path: `CHROME_CLI_DEBUG_LOG=/path/to/log.txt`

Example:

```bash
CHROME_CLI_DEBUG=1 ./.build/debug/chrome-cli tabs switch
tail -f /tmp/chrome-cli.debug.log
```

## Wrapper Scripts

Wrapper scripts in [scripts](scripts) continue to work and now use flags instead of environment variables:

- `brave-cli`
- `chrome-canary-cli`
- `chromium-cli`
- `edge-cli`
- `vivaldi-cli`
- `arc-cli`

Each wrapper calls:

```bash
chrome-cli --bundle-id <target-bundle-id> "$@"
```

## Homebrew Tap Release Pipeline

This repository includes a GitHub Actions workflow that:

1. runs `swift test`
2. builds a release binary
3. creates a GitHub Release for a tag (`vX.Y.Z`)
4. updates a Homebrew tap formula (`Formula/chrome-cli.rb`) in your tap repo

Workflow file:

- `.github/workflows/release-homebrew-tap.yml`

### Required GitHub Configuration

Set these in your repository settings:

1. Repository variable `HOMEBREW_TAP_REPO`:
`<owner>/<homebrew-tap-repo>` (for example: `lucacome/homebrew-tap`)
2. Repository secret `HOMEBREW_TAP_GITHUB_TOKEN`:
a token with `contents:write` access to the tap repository

### Triggering a Release

Push a version tag:

```bash
git tag v2.0.1
git push origin v2.0.1
```

The workflow will publish/update `Formula/chrome-cli.rb` in your tap repo.
