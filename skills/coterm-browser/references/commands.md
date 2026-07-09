# Command Reference (coterm Browser)

This maps common `agent-browser` usage to `Coterm browser` usage.

## Direct Equivalents

- `agent-browser open <url>` -> `Coterm browser open <url>`
- `agent-browser goto|navigate <url>` -> `Coterm browser <surface> goto|navigate <url>`
- `agent-browser snapshot -i` -> `Coterm browser <surface> snapshot --interactive`
- `agent-browser click <ref>` -> `Coterm browser <surface> click <ref>`
- `agent-browser fill <ref> <text>` -> `Coterm browser <surface> fill <ref> <text>`
- `agent-browser type <ref> <text>` -> `Coterm browser <surface> type <ref> <text>`
- `agent-browser select <ref> <value>` -> `Coterm browser <surface> select <ref> <value>`
- `agent-browser get text <ref>` -> `Coterm browser <surface> get text <ref-or-selector>`
- `agent-browser get url` -> `Coterm browser <surface> get url`
- `agent-browser get title` -> `Coterm browser <surface> get title`

## Core Command Groups

### Navigation

```bash
Coterm browser open <url>                        # opens in caller's workspace (uses COTERM_WORKSPACE_ID)
Coterm browser open <url> --workspace <id|ref>   # opens in a specific workspace
Coterm browser <surface> goto <url>
Coterm browser <surface> back|forward|reload
Coterm browser <surface> get url|title
```

> **Workspace context:** `browser open` targets the workspace of the terminal where the command is run (via `COTERM_WORKSPACE_ID`), even if a different workspace is currently focused. Use `--workspace` to override.

### Snapshot and Inspection

```bash
Coterm browser <surface> snapshot --interactive
Coterm browser <surface> snapshot --interactive --compact --max-depth 3
Coterm browser <surface> get text body
Coterm browser <surface> get html body
Coterm browser <surface> get value "#email"
Coterm browser <surface> get attr "#email" --attr placeholder
Coterm browser <surface> get count ".row"
Coterm browser <surface> get box "#submit"
Coterm browser <surface> get styles "#submit" --property color
Coterm browser <surface> eval '<js>'
```

### Interaction

```bash
Coterm browser <surface> click|dblclick|hover|focus <selector-or-ref>
Coterm browser <surface> fill <selector-or-ref> [text]   # empty text clears
Coterm browser <surface> type <selector-or-ref> <text>
Coterm browser <surface> press|keydown|keyup <key>
Coterm browser <surface> select <selector-or-ref> <value>
Coterm browser <surface> check|uncheck <selector-or-ref>
Coterm browser <surface> scroll [--selector <css>] [--dx <n>] [--dy <n>]
```

### Wait

```bash
Coterm browser <surface> wait --selector "#ready" --timeout-ms 10000
Coterm browser <surface> wait --text "Done" --timeout-ms 10000
Coterm browser <surface> wait --url-contains "/dashboard" --timeout-ms 10000
Coterm browser <surface> wait --load-state complete --timeout-ms 15000
Coterm browser <surface> wait --function "document.readyState === 'complete'" --timeout-ms 10000
```

### Session/State

```bash
Coterm browser <surface> cookies get|set|clear ...
Coterm browser <surface> storage local|session get|set|clear ...
Coterm browser <surface> tab list|new|switch|close ...
Coterm browser <surface> state save|load <path>
```

### Diagnostics

```bash
Coterm browser <surface> console list|clear
Coterm browser <surface> errors list|clear
Coterm browser <surface> highlight <selector>
Coterm browser <surface> screenshot
Coterm browser <surface> download wait --timeout-ms 10000
```

## Agent Reliability Tips

- Use `--snapshot-after` on mutating actions to return a fresh post-action snapshot.
- Re-snapshot after navigation, modal open/close, or major DOM changes.
- Prefer short handles in outputs by default (`surface:N`, `pane:N`, `workspace:N`, `window:N`).
- Use `--id-format both` only when a UUID must be logged/exported.

## Known WKWebView Gaps (`not_supported`)

- `browser.viewport.set`
- `browser.geolocation.set`
- `browser.offline.set`
- `browser.trace.start|stop`
- `browser.network.route|unroute|requests`
- `browser.screencast.start|stop`
- `browser.input_mouse|input_keyboard|input_touch`

See also:
- [snapshot-refs.md](snapshot-refs.md)
- [authentication.md](authentication.md)
- [session-management.md](session-management.md)
