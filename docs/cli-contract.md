# coterm CLI Contract

This document is the compatibility contract for migrating `CLI/coterm.swift` to
Swift ArgumentParser. The migration should preserve command names, aliases,
global flags, exit behavior, socket routing, and no-socket help behavior unless
a PR explicitly calls out an intentional contract change.

The current implementation is a hand-rolled parser. This spec is deliberately
written around user-visible behavior so the implementation can change behind it.

## Migration Rules

- Keep `coterm --help`, `coterm -h`, `coterm --version`, and `coterm -v` working without
  connecting to the coterm socket.
- Keep documented `coterm <command> --help` probes working without a socket where
  they already do.
- Keep `--socket`, `--password`, and `--window` as global options before the
  command. Keep presentation options `--json` and `--id-format` accepted either
  before or after the command.
- Keep UUIDs, refs such as `workspace:2`, and indexes accepted wherever the
  command accepts a window, workspace, pane, surface, or tab handle.
- Keep text output stable for scripting commands unless a command already
  documents JSON as the scripting interface.
- Keep hidden/internal commands available until their callers have migrated.

## Global Invocation

| Form | Contract |
| --- | --- |
| `coterm <path>` | Open a directory or file parent in coterm through the app's file-open path, without requiring control-socket access. Relative paths resolve from the current working directory. |
| `coterm [global-options] <command> [options]` | Run a named command. Presentation options may appear before or after the command. |
| `coterm --help`, `coterm -h` | Print top-level usage without a socket. |
| `coterm help` | Print top-level usage without a socket. |
| `coterm --version`, `coterm -v`, `coterm version` | Print version summary without a socket. |

Global options:

| Option | Contract |
| --- | --- |
| `--socket <path>` | Override the socket path for this invocation. |
| `--password <value>` | Use an explicit socket password. Takes precedence over `COTERM_SOCKET_PASSWORD`. |
| `--json` | Prefer machine-readable JSON output for commands that support it. |
| `--id-format <refs\|uuids\|both>` | Select handle format in JSON and supported text output. |
| `--window <id\|ref\|index>` | Route the command through a specific window when supported. |

Environment:

| Variable | Contract |
| --- | --- |
| `COTERM_SOCKET_PATH` | Canonical socket path override. |
| `COTERM_SOCKET` | Deprecated compatibility alias for `COTERM_SOCKET_PATH`. New scripts should use `COTERM_SOCKET_PATH`; if both variables are set and differ, the CLI fails before socket commands. |
| `COTERM_SOCKET_PASSWORD` | Socket password fallback when `--password` is absent. |
| `COTERM_WORKSPACE_ID` | Default workspace context inside coterm terminals. |
| `COTERM_SURFACE_ID` | Default surface context inside coterm terminals. |
| `COTERM_TAB_ID` | Default tab context for tab commands. |

## Top-Level Commands

| Command | Contract |
| --- | --- |
| `welcome` | Print the welcome screen. |
| `docs` | Print canonical docs URLs, raw GitHub resources, and useful commands for a topic. |
| `settings` | Open Settings, print coterm.json paths, or print settings docs. |
| `config` | Validate coterm.json syntax, print config references, or reload config. |
| `shortcuts` | Open Settings to Keyboard Shortcuts. |
| `disable-browser` | Disable Coterm browser creation and link interception until re-enabled. |
| `enable-browser` | Re-enable Coterm browser creation and link interception. |
| `browser-status` | Print whether Coterm browser creation and link interception are enabled. |
| `agent-hibernation` | Enable or disable Agent Hibernation. |
| `restore-session` | Restore the previously saved coterm session. |
| `open` | Open files, directories, or URLs in coterm. |
| `feedback` | Open feedback UI or submit feedback with `--email`, `--body`, and repeated `--image`. |
| `feed` | Open the keyboard-first Feed TUI or manage persisted Feed workstream history. |
| `themes` | List, set, clear, or interactively pick Ghostty themes. |
| `claude-teams` | Launch Claude Code with coterm/tmux-style agent team integration. |
| `codex-teams` | Launch Codex with coterm-managed subagent panes. |
| `omo` | Launch OpenCode with oh-my-openagent integration. |
| `omx` | Launch Oh My Codex with coterm pane integration. |
| `omc` | Launch Oh My Claude Code with coterm pane integration. |
| `hooks` | Install, uninstall, and run agent hook integrations under one namespace. |
| `codex` | Compatibility alias for installing or uninstalling Codex hooks. |
| `ping` | Check socket connectivity. |
| `capabilities` | Print server capabilities as JSON. |
| `events` | Stream reconnectable coterm events as newline-delimited JSON. |
| `auth` | Manage auth status, login, and logout through the app. |
| `vm`, `cloud` | Manage cloud VMs. `cloud` is an alias for `vm`. |
| `remotes`, `remote` | Manage remote Macs in the team device registry so they appear in the iOS app's device list. `remote` is an alias for `remotes`. |
| `rpc` | Call a raw v2 socket method with optional JSON params. |
| `identify` | Print server identity and caller context. |
| `list-windows` | List windows. |
| `current-window` | Print the selected window ID. |
| `new-window` | Create a new window. |
| `focus-window` | Focus a window by handle. |
| `close-window` | Close a window by handle. |
| `window displays` | List connected displays (name, index, main flag). |
| `window display <name\|index>` | Move the instance's window(s) onto a display by name (exact, substring) or index, preserving size. Does not steal focus. With `--window`, targets that window; otherwise moves all main windows. `--list` aliases `window displays`. |
| `window default-display [<name>\|--clear]` | Set, show (no arg), or clear (`--clear`) the shared, cross-tag default display that DEBUG dev builds open new windows on, stored in `~/.config/coterm/coterm.json` under `app.devWindowDisplay`. No running app required; applied at window creation. Also settable in Debug > Debug Windows > Dev Window Display. |
| `move-workspace-to-window` | Move a workspace into a target window. |
| `reorder-workspace` | Reorder a workspace inside a window. |
| `reorder-workspaces` | Atomically reorder workspaces inside pinned and unpinned groups. |
| `workspace-action` | Run workspace context-menu actions from the CLI. |
| `workspace` | Namespace for workspace verbs: `list`, `create`, `env`, `close`, `rename`, `select`, `reconnect`, `disconnect`, `group`. `workspace env` prints a workspace's configured environment variables (see [Workspace environment variables](#workspace-environment-variables)); pass `--mask` to redact the values. `workspace reconnect` manually reconnects a remote (SSH) workspace — including one whose automatic reconnect suspended because the host was unreachable — and `workspace disconnect` stops its remote connection. `env`, `reconnect`, and `disconnect` accept a positional workspace handle or `--workspace <id\|ref\|index>`, defaulting to the caller's workspace, then the selected one. |
| `move-tab-to-new-workspace` | Move a tab or surface into a newly created workspace. |
| `list-workspaces` | List workspaces. |
| `new-workspace` | Create a workspace, optionally with cwd, command, description, layout, and per-workspace environment variables (`--env KEY=VALUE` repeatable, `--env-file <path>`). See [Workspace environment variables](#workspace-environment-variables). |
| `ssh` | Open an SSH-backed workspace. Preserves the caller's live `SSH_AUTH_SOCK` for app-launched OpenSSH processes so `ForwardAgent yes` from ssh_config works normally. Supports `-A` / `--forward-agent` to request forwarding and `-a` / `--no-forward-agent` to disable forwarding for a workspace. Agent forwarding remains opt-in because forwarded agents can be used by processes on the remote host while the SSH session is active. |
| `remote-daemon-status` | Print bundled remote daemon version, asset, checksum, and cache status. |
| `ssh-session-list` | List persisted SSH PTY sessions for one remote workspace or all remote workspaces. Supports `--json`. |
| `ssh-session-attach` | Create a local terminal surface that reattaches to an existing persisted SSH PTY session. |
| `ssh-session-cleanup` | Close one or all persisted SSH PTY sessions. Supports `--json`. |
| `new-split` | Split from a surface in a direction. |
| `list-panes` | List panes in a workspace. |
| `list-pane-surfaces` | List surfaces in a pane. |
| `tree` | Print a window, workspace, pane, and surface tree. |
| `top` | Print process/resource usage for coterm windows, workspaces, panes, and surfaces. |
| `focus-pane` | Focus a pane. |
| `new-pane` | Create a pane with terminal or browser content. |
| `new-surface` | Create a surface inside a pane. |
| `close-surface` | Close a surface. |
| `move-surface` | Move a surface to another pane, workspace, window, or index. |
| `split-off` | Move a surface into a new split without changing focus by default. |
| `reorder-surface` | Reorder a surface within its pane. |
| `tab-action` | Run horizontal tab context-menu actions. |
| `rename-tab` | Rename a tab. Compatibility wrapper for `tab-action rename`. |
| `drag-surface-to-split` | Move a surface into a split direction. |
| `refresh-surfaces` | Ask the app to refresh terminal surfaces. |
| `reload-config` | Ask coterm to reload configuration. |
| `surface-health` | Print terminal surface health information. |
| `debug-terminals` | Print debug terminal state. |
| `trigger-flash` | Trigger a visual flash on a workspace or surface. |
| `list-panels` | List panels. Compatibility alias over pane/surface data. |
| `focus-panel` | Focus a panel. Compatibility alias over surface focus. |
| `close-workspace` | Close a workspace. |
| `select-workspace` | Select a workspace. |
| `rename-workspace`, `rename-window` | Rename a workspace. `rename-window` is a compatibility alias. |
| `current-workspace` | Print current workspace information. |
| `read-screen` | Read terminal text from a surface. |
| `send` | Send text to a terminal surface. |
| `send-key` | Send one key to a terminal surface. |
| `send-panel` | Send text to a panel/surface. |
| `send-key-panel` | Send one key to a panel/surface. |
| `notify` | Send a notification to a workspace/surface. |
| `list-notifications` | List queued notifications, including `created_at` and `tab_title`. |
| `dismiss-notification` | Remove one notification, or remove already-read notifications with `--all-read`. |
| `mark-notification-read` | Mark one notification, a workspace/surface scope, or all notifications read. |
| `open-notification` | Focus the notification's workspace/surface and mark it read. |
| `jump-to-unread` | Focus the latest unread notification. |
| `clear-notifications` | Clear queued notifications. |
| `right-sidebar` | Control right sidebar visibility, mode, focus, and state reads. |
| `set-status` | Set a sidebar status pill. |
| `clear-status` | Remove a sidebar status pill. |
| `list-status` | List sidebar status pills. |
| `set-progress` | Set sidebar progress. |
| `clear-progress` | Clear sidebar progress. |
| `log` | Append a sidebar log entry. |
| `clear-log` | Clear sidebar log entries. |
| `list-log` | List sidebar log entries. |
| `sidebar-state` | Dump sidebar metadata state. |
| `claude-hook` | Compatibility alias for Claude Code hook events from stdin JSON. |
| `set-app-focus` | Override app focus state for tests. |
| `simulate-app-active` | Trigger app-active handling for tests. |
| `browser` | Run browser automation commands. |
| `open-browser` | Legacy alias for `browser open`. |
| `navigate` | Legacy alias for `browser navigate`. |
| `browser-back` | Legacy alias for `browser back`. |
| `browser-forward` | Legacy alias for `browser forward`. |
| `browser-reload` | Legacy alias for `browser reload`. |
| `get-url` | Legacy alias for `browser get-url`. |
| `focus-webview` | Legacy alias for `browser focus-webview`. |
| `is-webview-focused` | Legacy alias for `browser is-webview-focused`. |
| `markdown` | Open a markdown file in a formatted viewer panel with live reload. |
| `vm-pty-attach` | Internal VM PTY attach command. |
| `vm-ssh-attach` | Hidden compatibility alias for older VM workspaces. |
| `vm-pty-connect` | Internal helper that connects to a VM PTY from a config file. |
| `ssh-pty-attach` | Internal helper used by SSH terminal startup scripts to bridge a local terminal surface to a remote PTY session. |
| `ssh-session-end` | Internal helper that clears remote SSH session state. |
| `__tmux-compat` | Internal tmux compatibility dispatcher. |

## Command Families

Auth subcommands:

| Command | Contract |
| --- | --- |
| `auth status` | Print signed-in state. Supports `--json`. |
| `auth login` | Begin sign-in through the app and wait for completion. |
| `auth logout` | Clear the current session. |

VM subcommands:

| Command | Contract |
| --- | --- |
| `vm ls`, `vm list` | List VMs. |
| `vm new`, `vm create` | Create a VM. Supports `--image`, `--provider`, `--detach`, and `-d`. |
| `vm shell`, `vm attach` | Open an interactive shell for an existing VM. |
| `vm rm`, `vm destroy`, `vm delete` | Destroy a VM. |
| `vm ssh` | Open a coterm-managed SSH workspace for an existing VM. |
| `vm ssh-info` | Print SSH connection info. |
| `vm ssh-attach` | Internal attach helper. |
| `vm exec` | Run a shell command inside a VM. |

Remotes subcommands:

| Command | Contract |
| --- | --- |
| `remotes list`, `remotes ls` | List the team's registered remotes (name, deviceId, routes, tag, last seen). Supports `--json`. |
| `remotes add <name>` | Register or update a remote with one or more `--route <host:port>`. Supports `--tag` and `--json`. Idempotent on `<name>` (re-adding updates routes). The host must be a Tailscale address the phone can authenticate to (CGNAT `100.64.x.x`-`100.127.x.x` or `*.ts.net`); loopback, plain LAN IPs, and bare hostnames are rejected. |
| `remotes remove <name-or-deviceId>` | Remove a remote you registered. Aliases `rm`, `delete`. Supports `--json`. |

Theme subcommands:

| Command | Contract |
| --- | --- |
| `themes` | List available themes and report the managed current theme. |
| `themes list` | List available themes and mark `Anysphere Dark` as the managed terminal theme. |
| `themes set <theme>` | Disabled; terminal colors are fixed to `Anysphere Dark`. |
| `themes set --light <theme>` | Disabled; terminal colors are fixed to `Anysphere Dark`. |
| `themes set --dark <theme>` | Disabled; terminal colors are fixed to `Anysphere Dark`. |
| `themes clear` | Disabled; terminal colors are fixed to `Anysphere Dark`. |

Workspace and tab action names:

| Command | Actions |
| --- | --- |
| `workspace-action` | `pin`, `unpin`, `rename`, `clear-name`, `set-description`, `clear-description`, `move-up`, `move-down`, `move-top`, `close-others`, `close-above`, `close-below`, `mark-read`, `mark-unread`, `set-color`, `clear-color` |
| `tab-action` | `rename`, `clear-name`, `close-left`, `close-right`, `close-others`, `new-terminal-right`, `new-browser-right`, `reload`, `duplicate`, `pin`, `unpin`, `mark-unread` |

### Workspace environment variables

A workspace can carry a set of user-defined environment variables that every
shell spawned in it inherits.

Setting them:

- CLI: `coterm new-workspace --env KEY=VALUE [--env ...] [--env-file <path>]`
  (and the same flags on `coterm workspace create`). `--env` is repeatable;
  `--env-file` reads `KEY=VALUE` lines (blank lines and `#` comments ignored, an
  optional leading `export ` stripped). When both are given, `--env` overrides a
  value from a file.
- Project config (`coterm.json`): an `env` object on a workspace definition, e.g.
  `{ "name": "Build", "cwd": ".", "env": { "AWS_PROFILE": "prod" } }`.
- Socket: the `workspace_env` param on `workspace.create`.

Inspecting them: `coterm workspace env [<handle>] [--mask] [--json]` prints the
configured set. `--mask` redacts the values so secrets are not echoed in full.
The env set is intentionally omitted from `workspace list` output so a plain
listing never leaks secrets.

Semantics:

- **Inheritance.** The variables apply to the workspace's initial shell and to
  every pane, surface, and split created later in that workspace — no per-pane
  re-export. They are also re-applied to every shell recreated on session
  restore.
- **Persistence.** They are stored on the workspace in the session manifest, so
  they survive app restart, daemon restart, and session restore.
- **Precedence.** Workspace env overlays the inherited process environment. It is
  applied as the shell's startup environment, so it is visible to login-shell
  init files (`~/.zprofile`, `~/.zshrc`) as they run, but any `export` those
  files perform for the same key wins for the interactive session (they run after
  the variable is seeded). An explicit per-surface environment (a layout
  `surfaces[].env`, SSH startup env) overrides the workspace value for that
  surface.
- **Protected `COTERM_*` variables.** Workspace env can never override the managed
  variables coterm injects (e.g. `COTERM_WORKSPACE_ID`, `COTERM_SURFACE_ID`,
  `COTERM_SOCKET_PATH`, `COTERM_SOCKET_PASSWORD`) or the terminal identity variables
  (`TERM`, `COLORTERM`, `TERM_PROGRAM`); those keys are protected at spawn time
  and silently win.
- **Secrets.** Values may be secrets. They are never logged, are masked by
  `--mask`, and are kept out of `workspace list`. Prefer `--env-file` so secrets
  do not land in shell history. Note that values stored in the session manifest
  live on disk in plaintext.

tmux compatibility commands:

| Command | Contract |
| --- | --- |
| `capture-pane` | Read pane text. |
| `resize-pane` | Resize a pane with direction flags. |
| `pipe-pane` | Pipe pane text to a shell command. |
| `wait-for` | Signal or wait on a named synchronization point. |
| `swap-pane` | Swap two panes. |
| `break-pane` | Move a pane into a new workspace. |
| `join-pane` | Join a pane into another pane. |
| `next-window`, `previous-window`, `last-window` | Move workspace selection. |
| `last-pane` | Focus the last pane. |
| `find-window` | Find a workspace by title or content. |
| `clear-history` | Clear terminal scrollback. |
| `set-hook` | Manage tmux-compat hook definitions. |
| `popup` | Placeholder, currently unsupported. |
| `bind-key`, `unbind-key`, `copy-mode` | Placeholders, currently unsupported. |
| `set-buffer` | Set a tmux-compat buffer. |
| `paste-buffer` | Paste a tmux-compat buffer. |
| `list-buffers` | List tmux-compat buffers. |
| `respawn-pane` | Send a restart command to a surface. |
| `display-message` | Print or display a message. |

Browser subcommands:

| Command | Contract |
| --- | --- |
| `browser open`, `browser open-split`, `browser new` | Create or open a browser surface. |
| `browser goto`, `browser navigate` | Navigate to a URL. |
| `browser back`, `browser forward`, `browser reload` | Navigate browser history or reload. |
| `browser url`, `browser get-url` | Print current URL. |
| `browser focus-webview`, `browser is-webview-focused` | Focus or query webview focus. |
| `browser snapshot` | Print a DOM snapshot. |
| `browser eval` | Evaluate JavaScript. |
| `browser wait` | Wait for selector, text, URL, load state, or JS predicate. |
| `browser click`, `browser dblclick`, `browser hover`, `browser focus`, `browser check`, `browser uncheck`, `browser scroll-into-view` | Run element interaction. |
| `browser type`, `browser fill` | Type into or set an input. |
| `browser press`, `browser key`, `browser keydown`, `browser keyup` | Send keyboard input. |
| `browser select` | Select an option. |
| `browser scroll` | Scroll page or element. |
| `browser screenshot` | Save a screenshot. |
| `browser get` | Read URL, title, text, HTML, value, attr, count, box, or styles. |
| `browser is` | Check visible, enabled, or checked state. |
| `browser find` | Find by role, text, label, placeholder, alt, title, testid, first, last, or nth. |
| `browser frame` | Select frame context. |
| `browser dialog` | Accept or dismiss dialogs. |
| `browser download` | Wait for or save downloads. |
| `browser profiles` | List, add, rename, clear, or delete Coterm browser profiles. `clear` refuses to wipe active profiles unless `--force` is passed. |
| `browser import` | Open the browser import wizard. In detected coding-agent environments, defaults to non-interactive cookie import; pass `--interactive` to force the wizard. Non-interactive import supports `--from`, `--profile`, `--all-profiles`, `--to-profile`, `--create-profile`, and `--domain`. |
| `browser cookies` | Get, set, or clear cookies. |
| `browser storage` | Get, set, or clear local/session storage. |
| `browser tab` | Create, list, switch, or close browser tabs. |
| `browser console`, `browser errors` | List or clear console messages and errors. |
| `browser highlight` | Highlight an element. |
| `browser state` | Save or load browser state. |
| `browser addinitscript`, `browser addscript`, `browser addstyle` | Inject scripts or CSS. |
| `browser viewport` | Set viewport size. |
| `browser geolocation`, `browser geo` | Set geolocation. |
| `browser offline` | Toggle offline state. |
| `browser trace` | Start or stop trace capture. |
| `browser network` | Route, unroute, or list requests. |
| `browser screencast` | Start or stop screencast. |
| `browser input`, `browser input_mouse`, `browser input_keyboard`, `browser input_touch` | Send low-level input. |
| `browser identify` | Identify browser surface context. |

Hook subcommands:

| Command | Contract |
| --- | --- |
| `hooks setup` | Install hooks for all supported agents whose binaries are on `PATH`. Supports `--agent <name>`, positional agent filters such as `coterm hooks setup rovo`, and `--yes`. |
| `hooks uninstall` | Remove hooks for all supported agents. Supports `--agent <name>`, positional agent filters such as `coterm hooks uninstall rovo`, and `--yes`. |
| `hooks <agent> install` | Install hooks for one supported agent. `opencode` also supports `--project` for the project-local Feed plugin. |
| `hooks <agent> uninstall` | Remove hooks for one supported agent. |
| `hooks claude <event>` | Handle Claude Code hook events. `claude-hook <event>` remains as the main-compatibility alias. |
| `hooks codex <event>` | Handle Codex hook events. `codex install-hooks` remains as the main-compatibility installer alias. |
| `hooks feed --source <agent>` | Convert agent hook events into Feed context. |
| `hooks <agent> <event>` | Generic hook surface for `grok`, `opencode`, `pi`, `amp`, `cursor`, `gemini`, `rovodev`, `copilot`, `codebuddy`, `factory`, and `qoder`. |

Right sidebar commands:

| Command | Contract |
| --- | --- |
| `right-sidebar toggle`, `right-sidebar show`, `right-sidebar hide` | Change right-sidebar visibility without printing on success. |
| `right-sidebar focus` | Focus the current right-sidebar mode. |
| `right-sidebar set <files\|find\|vault\|sessions\|feed\|dock>` | Show the right sidebar, switch mode, and focus it unless `--no-focus` is passed. |
| `right-sidebar files`, `right-sidebar find`, `right-sidebar vault`, `right-sidebar sessions`, `right-sidebar feed`, `right-sidebar dock` | Short aliases for `right-sidebar set <mode>` with focus. |
| `right-sidebar mode` | Print JSON with `visible` and `mode`. |
| `--workspace <id\|ref\|index>` | Target the window containing a workspace. Refs and indexes resolve before the V1 socket command is sent. |
| `--window <id\|ref\|index>` | Target a window. Refs and indexes resolve before the V1 socket command is sent. |
| `--no-focus` | Only valid with `set`; switches mode without moving focus. |

Custom sidebar commands:

| Command | Contract |
| --- | --- |
| `sidebar validate [name]` | Validate all custom sidebars, or one named sidebar, under `~/.config/coterm/sidebars`. |
| `sidebar reload [name]` | Validate all custom sidebars, then request a reload for every valid one. |
| `sidebar select <name>` | Validate and activate one custom sidebar in the sidebar picker. |
| `sidebar open <name>` | Validate and open one custom sidebar as a normal Bonsplit pane tab, preferring the right-side split from the focused surface. |

Docs topics:

| Command | Contract |
| --- | --- |
| `docs` | List docs topics without a socket. |
| `docs settings` | Print the configuration docs URL, raw schema URL, coterm.json paths, backup reminder, and reload command. |
| `docs shortcuts` | Print shortcut docs and raw shortcut data resources. |
| `docs api` | Print API docs and raw CLI contract resources. |
| `docs browser` | Print browser automation docs and raw browser skill resources. |
| `docs agents` | Print agent integration docs and raw integration resources. |

Settings subcommands:

| Command | Contract |
| --- | --- |
| `settings` | Open the Settings window, launching coterm if needed. |
| `settings open [target]` | Open Settings to an optional target section. |
| `settings path` | Print coterm.json paths, docs URL, schema URL, backup reminder, and reload command without a socket. |
| `settings docs` | Print the same output as `docs settings` without a socket. |
| `settings <target>` | Open Settings to a target section. Supported aliases include `shortcuts`, `json`, `coterm-json`, `browser`, and `automation`. |

Config subcommands:

| Command | Contract |
| --- | --- |
| `config doctor [--path <file>]`, `config check`, `config validate` | Validate JSONC syntax for config files. When `--path` is absent, default discovery checks the primary config, project-level `.coterm/coterm.json` or `coterm.json`, and legacy config files. `--path <file>` may be repeated to validate multiple explicit files. Exits 0 on success and 1 on any error. Supports `--json`. Works without a socket. |
| `config path`, `config paths` | Print coterm.json paths, docs URL, schema URL, backup reminder, and reload command without a socket. |
| `config docs`, `config documentation` | Print the same output as `docs settings` without a socket. |
| `config reload` | Ask the running coterm app to reload configuration. Requires a socket. |
| `config get sidebar-font-size` | Print the effective sidebar text size. |
| `config set sidebar-font-size <points>` | Write the sidebar text size to coterm's editable Ghostty config and reload the running app when available. |
| `config sidebar-font-size [points]` | Get the sidebar text size, or set it when a point size is provided. |
| `config get surface-tab-bar-font-size` | Print the effective workspace tab bar text size. |
| `config set surface-tab-bar-font-size <points>` | Write the workspace tab bar text size to coterm's editable Ghostty config and reload the running app when available. |
| `config surface-tab-bar-font-size [points]` | Get the workspace tab bar text size, or set it when a point size is provided. |
| `config get <key>`, `config set <key> <points>` | Generic get/set for `sidebar-font-size` and `surface-tab-bar-font-size`. |

`config doctor --json` outputs an object with `ok`, `error_count`,
`findings`, `reload_command`, `docs_url`, and `schema_url`. Each finding includes
`label`, `display_path`, `path`, `status`, `ok`, `keys`, and, when available,
`message` and `bytes`.

Events command:

| Option | Contract |
| --- | --- |
| `--after <seq>`, `--after-seq <seq>` | Subscribe to retained events after a sequence number. |
| `--cursor-file <path>` | Read the starting sequence from a file and update it after every event. |
| `--name <event>` | Filter by event name. Repeatable. |
| `--category <name>` | Filter by category. Repeatable. |
| `--reconnect` | Reconnect and resume from the last received sequence until interrupted. |
| `--limit <n>` | Exit after printing `n` event frames. |
| `--no-ack` | Suppress the initial ack frame in stdout. |
| `--no-heartbeat`, `--no-heartbeats` | Suppress heartbeat frames in stdout. |

`events.stream` is a v2 socket method advertised by `capabilities`. The first
response frame is an `ack`; sequence resume metadata lives under `ack.resume` as
`after_seq`, `oldest_seq`, `latest_seq`, `next_seq`, and `gap`. Event frames
carry a process-local monotonic `seq` and a stable `id` for dedupe. Clients
should persist `seq` after processing each event and reconnect with that value.
See [events.md](events.md) for the full protocol and event catalog. Every emitted event is also appended to
`~/.coterm/events.jsonl`, including model lifecycle events for window
creation, close, focus, key-window state, workspace selection, pane focus, and
surface selection, focus, creation, or closure. The stream is bounded: coterm keeps
4,096 replay events in memory, caps each encoded event frame at 16 KiB, closes
slow subscribers after 1,024 pending events, and rotates `events.jsonl` with one
16 MiB archive at `events.jsonl.1`.

## No-Socket Help Probes

The following probes are executable contract checks. They must exit 0 and print
the expected text without connecting to a coterm socket.

<!-- cli-contract-help-probes:start -->
- `coterm --help` -> `coterm - control coterm via Unix socket`
- `coterm --help` -> `open <path-or-url>...`
- `coterm help` -> `coterm - control coterm via Unix socket`
- `coterm ping --help` -> `Usage: coterm ping`
- `coterm capabilities --help` -> `Usage: coterm capabilities`
- `coterm events --help` -> `Usage: coterm events [options]`
- `coterm auth --help` -> `Usage: coterm auth <status|login|logout>`
- `coterm vm --help` -> `Usage: coterm vm <new|ls|rm|exec|shell|attach|ssh|ssh-info> [args...]`
- `coterm cloud --help` -> `Usage: coterm cloud <new|ls|rm|exec|shell|attach|ssh|ssh-info> [args...]`
- `coterm remotes --help` -> `Usage: coterm remotes <list|add|remove> [options]`
- `coterm remote --help` -> `Usage: coterm remotes <list|add|remove> [options]`
- `coterm rpc --help` -> `Usage: coterm rpc <method> [json-params]`
- `coterm help --help` -> `Usage: coterm help`
- `coterm docs --help` -> `Usage: coterm docs [settings|shortcuts|api|browser|agents|dock]`
- `coterm docs` -> `Topics:`
- `coterm docs settings` -> `Config files:`
- `coterm docs dock` -> `dock: Custom right-sidebar terminal controls`
- `coterm settings --help` -> `Usage: coterm settings [open [target]|path|docs|<target>]`
- `coterm settings path` -> `Config files:`
- `coterm settings docs` -> `Config files:`
- `coterm config --help` -> `Usage: coterm config <doctor|check|validate|path|paths|docs|documentation|reload|get|set|sidebar-font-size|surface-tab-bar-font-size>`
- `coterm config path` -> `Config files:`
- `coterm config docs` -> `Config files:`
- `coterm welcome --help` -> `Usage: coterm welcome`
- `coterm welcome` -> `Toggle Left Sidebar`
- `coterm welcome` -> `Toggle Right Sidebar`
- `coterm shortcuts --help` -> `Usage: coterm shortcuts`
- `coterm disable-browser --help` -> `Usage: coterm disable-browser [--json]`
- `coterm enable-browser --help` -> `Usage: coterm enable-browser [--json]`
- `Coterm browser-status --help` -> `Usage: Coterm browser-status [--json]`
- `coterm agent-hibernation --help` -> `Usage: coterm agent-hibernation <on|off> [--json]`
- `coterm restore-session --help` -> `Usage: coterm restore-session`
- `coterm open --help` -> `Usage: coterm open <path-or-url>...`
- `coterm feedback --help` -> `Usage: coterm feedback`
- `coterm feed --help` -> `Usage: coterm feed tui [--opentui|--legacy]`
- `coterm hooks --help` -> `Usage: coterm hooks setup [agent] [--agent <name>] [--yes|-y]`
- `coterm codex --help` -> `Usage: coterm codex <install-hooks|uninstall-hooks>`
- `coterm themes --help` -> `Usage: coterm themes`
- `coterm omo --help` -> `Usage: coterm omo [opencode-args...]`
- `coterm omx --help` -> `Usage: coterm omx [omx-args...]`
- `coterm omc --help` -> `Usage: coterm omc [omc-args...]`
- `coterm identify --help` -> `Usage: coterm identify`
- `coterm list-windows --help` -> `Usage: coterm list-windows`
- `coterm current-window --help` -> `Usage: coterm current-window`
- `coterm new-window --help` -> `Usage: coterm new-window`
- `coterm focus-window --help` -> `Usage: coterm focus-window --window <id|ref|index>`
- `coterm close-window --help` -> `Usage: coterm close-window --window <id|ref|index>`
- `coterm move-workspace-to-window --help` -> `Usage: coterm move-workspace-to-window`
- `coterm move-surface --help` -> `Usage: coterm move-surface`
- `coterm split-off --help` -> `Usage: coterm split-off`
- `coterm reorder-surface --help` -> `Usage: coterm reorder-surface`
- `coterm reorder-workspace --help` -> `Usage: coterm reorder-workspace`
- `coterm reorder-workspaces --help` -> `Usage: coterm reorder-workspaces`
- `coterm workspace-action --help` -> `Usage: coterm workspace-action --action <name>`
- `coterm move-tab-to-new-workspace --help` -> `Usage: coterm move-tab-to-new-workspace`
- `coterm tab-action --help` -> `Usage: coterm tab-action --action <name>`
- `coterm rename-tab --help` -> `Usage: coterm rename-tab`
- `coterm new-workspace --help` -> `Usage: coterm new-workspace`
- `coterm list-workspaces --help` -> `Usage: coterm list-workspaces`
- `coterm ssh --help` -> `Usage: coterm ssh <destination>`
- `coterm ssh --help` -> `--forward-agent`
- `coterm ssh-session-list --help` -> `Usage: coterm ssh-session-list`
- `coterm ssh-session-attach --help` -> `Usage: coterm ssh-session-attach --session-id <id>`
- `coterm ssh-session-cleanup --help` -> `Usage: coterm ssh-session-cleanup`
- `coterm new-split --help` -> `Usage: coterm new-split`
- `coterm list-panes --help` -> `Usage: coterm list-panes`
- `coterm list-pane-surfaces --help` -> `Usage: coterm list-pane-surfaces`
- `coterm tree --help` -> `Usage: coterm tree`
- `coterm top --help` -> `Usage: coterm top`
- `coterm focus-pane --help` -> `Usage: coterm focus-pane`
- `coterm new-pane --help` -> `Usage: coterm new-pane`
- `coterm new-surface --help` -> `Usage: coterm new-surface`
- `coterm close-surface --help` -> `Usage: coterm close-surface`
- `coterm drag-surface-to-split --help` -> `Usage: coterm drag-surface-to-split`
- `coterm refresh-surfaces --help` -> `Usage: coterm refresh-surfaces`
- `coterm reload-config --help` -> `Usage: coterm reload-config`
- `coterm surface-health --help` -> `Usage: coterm surface-health`
- `coterm debug-terminals --help` -> `Usage: coterm debug-terminals`
- `coterm trigger-flash --help` -> `Usage: coterm trigger-flash`
- `coterm list-panels --help` -> `Usage: coterm list-panels`
- `coterm focus-panel --help` -> `Usage: coterm focus-panel`
- `coterm close-workspace --help` -> `Usage: coterm close-workspace`
- `coterm select-workspace --help` -> `Usage: coterm select-workspace`
- `coterm rename-workspace --help` -> `Usage: coterm rename-workspace`
- `coterm rename-window --help` -> `Usage: coterm rename-workspace`
- `coterm current-workspace --help` -> `Usage: coterm current-workspace`
- `coterm capture-pane --help` -> `Usage: coterm capture-pane`
- `coterm resize-pane --help` -> `Usage: coterm resize-pane`
- `coterm pipe-pane --help` -> `Usage: coterm pipe-pane`
- `coterm wait-for --help` -> `Usage: coterm wait-for`
- `coterm swap-pane --help` -> `Usage: coterm swap-pane`
- `coterm break-pane --help` -> `Usage: coterm break-pane`
- `coterm join-pane --help` -> `Usage: coterm join-pane`
- `coterm next-window --help` -> `Usage: coterm next-window`
- `coterm previous-window --help` -> `Usage: coterm previous-window`
- `coterm last-window --help` -> `Usage: coterm last-window`
- `coterm last-pane --help` -> `Usage: coterm last-pane`
- `coterm find-window --help` -> `Usage: coterm find-window`
- `coterm clear-history --help` -> `Usage: coterm clear-history`
- `coterm set-hook --help` -> `Usage: coterm set-hook`
- `coterm popup --help` -> `Usage: coterm popup`
- `coterm bind-key --help` -> `Usage: coterm bind-key`
- `coterm unbind-key --help` -> `Usage: coterm unbind-key`
- `coterm copy-mode --help` -> `Usage: coterm copy-mode`
- `coterm set-buffer --help` -> `Usage: coterm set-buffer`
- `coterm paste-buffer --help` -> `Usage: coterm paste-buffer`
- `coterm list-buffers --help` -> `Usage: coterm list-buffers`
- `coterm respawn-pane --help` -> `Usage: coterm respawn-pane`
- `coterm display-message --help` -> `Usage: coterm display-message`
- `coterm read-screen --help` -> `Usage: coterm read-screen`
- `coterm send --help` -> `Usage: coterm send`
- `coterm send-key --help` -> `Usage: coterm send-key`
- `coterm send-panel --help` -> `Usage: coterm send-panel`
- `coterm send-key-panel --help` -> `Usage: coterm send-key-panel`
- `coterm notify --help` -> `Usage: coterm notify`
- `coterm list-notifications --help` -> `Usage: coterm list-notifications`
- `coterm dismiss-notification --help` -> `Usage: coterm dismiss-notification`
- `coterm mark-notification-read --help` -> `Usage: coterm mark-notification-read`
- `coterm open-notification --help` -> `Usage: coterm open-notification`
- `coterm jump-to-unread --help` -> `Usage: coterm jump-to-unread`
- `coterm clear-notifications --help` -> `Usage: coterm clear-notifications`
- `coterm right-sidebar --help` -> `Usage: coterm right-sidebar <command> [flags]`
- `coterm set-status --help` -> `Usage: coterm set-status`
- `coterm clear-status --help` -> `Usage: coterm clear-status`
- `coterm list-status --help` -> `Usage: coterm list-status`
- `coterm set-progress --help` -> `Usage: coterm set-progress`
- `coterm clear-progress --help` -> `Usage: coterm clear-progress`
- `coterm log --help` -> `Usage: coterm log`
- `coterm clear-log --help` -> `Usage: coterm clear-log`
- `coterm list-log --help` -> `Usage: coterm list-log`
- `coterm sidebar-state --help` -> `Usage: coterm sidebar-state`
- `coterm set-app-focus --help` -> `Usage: coterm set-app-focus`
- `coterm simulate-app-active --help` -> `Usage: coterm simulate-app-active`
- `coterm claude-hook --help` -> `Usage: coterm claude-hook`
- `Coterm browser --help` -> `Usage: Coterm browser`
- `coterm open-browser --help` -> `Legacy alias for 'Coterm browser open'`
- `coterm navigate --help` -> `Legacy alias for 'Coterm browser navigate'`
- `Coterm browser-back --help` -> `Legacy alias for 'Coterm browser back'`
- `Coterm browser-forward --help` -> `Legacy alias for 'Coterm browser forward'`
- `Coterm browser-reload --help` -> `Legacy alias for 'Coterm browser reload'`
- `coterm get-url --help` -> `Legacy alias for 'Coterm browser get-url'`
- `coterm focus-webview --help` -> `Legacy alias for 'Coterm browser focus-webview'`
- `coterm is-webview-focused --help` -> `Legacy alias for 'Coterm browser is-webview-focused'`
- `coterm markdown --help` -> `Usage: coterm markdown open <path>`
<!-- cli-contract-help-probes:end -->

## No-Socket Negative Help Probes

The following probes must not print help. They protect argument forwarding after
`--`, where a forwarded `--help` token belongs to the command payload.

<!-- cli-contract-negative-help-probes:start -->
- `coterm vm exec demo -- --help` !> `Usage: coterm vm`
<!-- cli-contract-negative-help-probes:end -->

## Current Help Caveats

These are current contracts to preserve until a follow-up PR intentionally
changes them:

- `coterm version --help` currently prints the version summary because `version`
  is handled before subcommand help dispatch.
- `coterm claude-teams --help` is handled by the command launcher, not by the
  pre-socket help dispatcher.
- `coterm codex-teams --help` is handled by the command launcher, not by the
  pre-socket help dispatcher.
- `coterm remote-daemon-status --help` currently prints status because the command
  runs before subcommand help dispatch.

## ArgumentParser Migration Sequence

1. Keep this contract file and `tests/test_cli_contract_help.py` green.
2. Add Swift ArgumentParser as a dependency without changing behavior.
3. Introduce a parse-only facade that maps ArgumentParser command structs onto
   existing `CotermCLI` runner methods.
4. Move one command family at a time into small files, starting with no-socket
   commands (`version`, `themes`, hook installers), then socket commands, then
   browser and tmux compatibility.
5. After each family moves, run the contract probes plus targeted socket tests in
   GitHub Actions.
6. When all command families are migrated, remove the manual global parser and
   legacy helper code that no longer owns behavior.
