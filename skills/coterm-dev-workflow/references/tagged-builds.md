# Tagged Builds

Tagged builds isolate app name, bundle ID, socket, and DerivedData path so multiple agents and the user's normal app do not collide.

## Reload

Use:

```bash
./scripts/reload.sh --tag <tag>
```

`reload.sh` builds but does not launch by default. It terminates any running app with the same tag after a successful build, so opening the printed app path launches the fresh binary.

For fast Swift/UI iteration on a tag with warmed DerivedData, use:

```bash
COTERM_DEV_FAST_RELOAD=1 ./scripts/reload.sh --tag <tag>
```

This keeps the same Xcode compile graph but skips slow dev packaging work: the Ghostty CLI helper Zig rebuild is skipped, an existing `cotermd` binary is reused when available, and the Xcode-built app is retagged in place instead of copying the full `.app` bundle. Use the normal reload path when changing Ghostty, `cotermd`, helper binaries, signing/bundle packaging, or tag/socket isolation behavior.

Use:

```bash
./scripts/reload.sh --tag <tag> --launch
```

only when the task requires launching.

## App path links

`reload.sh` prints:

```text
App path:
  /absolute/path/to/Coterm DEV <tag>.app
```

Build chat links from that exact path. Prepend `file://` and URL-encode spaces as `%20`. Do not hardcode DerivedData paths and never use `/tmp/coterm-<tag>/...` app links in chat output.

## Tagged CLI and socket

For CLI or socket dogfood against a tagged Debug app, use:

```bash
COTERM_TAG=<tag> scripts/coterm-debug-cli.sh list-workspaces
COTERM_TAG=<tag> scripts/coterm-debug-cli.sh send --workspace workspace:1 --surface surface:1 "echo ok"
```

Do not use `/tmp/coterm-cli` for tagged dogfood. That symlink points at the most recently reloaded build and can target the user's main app socket.

The helper:

- refuses to run without `COTERM_TAG`
- targets `/tmp/coterm-debug-<tag>.sock`
- uses the matching tagged CLI from DerivedData
- scrubs ambient coterm terminal context
- sets `COTERM_SOCKET_PATH`, `COTERM_BUNDLE_ID`, and `COTERM_BUNDLED_CLI_PATH`

## Cleanup

Before launching a new tagged run, clean up older tags started in the same session:

- quit old tagged app
- remove its `/tmp` socket if stale
- remove derived data only when you are sure no active task needs it

Do not open an untagged `Coterm DEV.app` from DerivedData. It shares the default debug socket and bundle ID with other agents.
