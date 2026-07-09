---
name: coterm-workspace
description: "Work inside the current coterm workspace and terminal. Use for coterm workspace, current workspace, caller surface, panes, surfaces, socket targeting, and non-interfering coterm automation."
---

# coterm Workspace

Use this skill when a task should be scoped to the coterm workspace that invoked the agent. A workspace is the sidebar tab-like unit in coterm. It contains split panes, and each pane contains one or more surfaces. A surface is the terminal or browser session the user interacts with.

## Default Rule

Scope actions to the current caller workspace unless the user explicitly asks for another workspace, another window, or global state.

Do not assume the visually focused coterm workspace is the right target. An agent can be running in one workspace while the user is looking at another. Prefer the caller environment first:

```bash
printf 'workspace=%s\nsurface=%s\nsocket=%s\n' \
  "${COTERM_WORKSPACE_ID:-}" \
  "${COTERM_SURFACE_ID:-}" \
  "${COTERM_SOCKET_PATH:-}"
coterm identify --json
```

Use `COTERM_WORKSPACE_ID` as the default workspace anchor and `COTERM_SURFACE_ID` as the default caller terminal/surface anchor. If those are missing, use `coterm identify --json` and be explicit that you are using the currently focused coterm context.

## Non-Disruptive Automation

The user may be visually focused on a different workspace, window, or app while an agent works in the caller workspace. Treat layout and focus as separate concerns. Never call focus-changing verbs speculatively.

Never call these without an explicit user ask:

- `select-workspace` switches the visible sidebar tab.
- `focus-pane` / `focus-panel` yanks pane or surface focus.
- `tab-action` with focus-changing actions.

These are user-affecting actions, like clicks. The rule applies even inside the caller's own workspace, since the user may be looking elsewhere.

Build layout additively, in one shot. Prefer commands that create a new pane already populated with the right surface:

```bash
# pane and content in one call, no follow-up needed
coterm new-pane --workspace "${COTERM_WORKSPACE_ID}" --type browser --direction right --url "http://127.0.0.1:8765"
coterm new-pane --workspace "${COTERM_WORKSPACE_ID}" --type terminal --direction down
```

Avoid create-then-move-then-focus chains. If a layout command rejects a valid `surface:` or `pane:` ref, do not work around it by focusing. Report the bug to the user and stop.

Pass `--focus false` whenever the verb supports it. `move-surface --focus false` preserves the user's current attention. Other commands may grow the same flag over time (https://github.com/emergent-inc/coterm/issues/1418, https://github.com/emergent-inc/coterm/issues/2820).

## Right-Side Helper Pane

When opening auxiliary output for the current task (preview apps, TUIs, logs, one-off shells, browser checks), keep the workspace organized by reusing a helper pane to the right of the caller terminal.

First inspect the caller context and panes:

```bash
coterm identify --json
coterm list-panes --workspace "${COTERM_WORKSPACE_ID:-}" --json
coterm list-pane-surfaces --workspace "${COTERM_WORKSPACE_ID:-}" --json
```

Use this policy:

- If the caller workspace already has a non-caller helper pane, add a new surface to that pane instead of creating another pane:
  ```bash
  coterm new-surface --workspace "${COTERM_WORKSPACE_ID:-}" --pane pane:<helper> --type terminal --focus false
  ```
- If there is no helper pane, create exactly one right-side pane:
  ```bash
  coterm new-pane --workspace "${COTERM_WORKSPACE_ID:-}" --type terminal --direction right --focus false
  ```
- If there are multiple obvious stale helper panes from this same automation and the user asked to tidy or reuse, keep one right helper pane and clean up the duplicates. Do not close panes you cannot confidently identify as stale helper output.
- Send commands to the new or reused helper surface by explicit surface ref. Do not focus it unless the user asks.

This means repeated "open it" requests should normally create tabs inside the existing right helper pane, not more splits.

## Hierarchy

- Window: a macOS coterm window.
- Workspace: a sidebar entry. The UI may call it a tab, but CLI/socket APIs call it a workspace.
- Pane: a split region inside a workspace.
- Surface: a tab inside a pane. Surfaces can be terminals or browser panels.
- Panel: internal content type inside a surface. Prefer CLI surface commands instead of panel internals.

## Inspect Current Context

```bash
coterm identify --json
coterm current-workspace --json
coterm list-workspaces --json
coterm list-panes --workspace "${COTERM_WORKSPACE_ID:-}" --json
coterm list-pane-surfaces --workspace "${COTERM_WORKSPACE_ID:-}" --json
coterm list-panels --workspace "${COTERM_WORKSPACE_ID:-}" --json
```

Use `--id-format both` when logs or handoffs need stable UUIDs plus human refs:

```bash
coterm --json --id-format both identify
```

## Workspace-Scoped Actions

Prefer explicit workspace flags even when env vars are set. It makes automation auditable and avoids affecting a focused workspace in another window.

```bash
# create a new workspace when the user asks for a new task area
coterm new-workspace --name "debug auth" --cwd "$PWD"

# rename / close (only when explicitly requested)
coterm rename-workspace --workspace "${COTERM_WORKSPACE_ID:-}" -- "build fix"
coterm close-workspace --workspace workspace:4
coterm close-surface --workspace "${COTERM_WORKSPACE_ID:-}" --surface surface:3

# additive layout (safe, no focus side effects beyond the command's own defaults)
coterm new-pane --workspace "${COTERM_WORKSPACE_ID:-}" --type terminal --direction right
coterm new-surface --workspace "${COTERM_WORKSPACE_ID:-}" --type terminal

# focus-changing (USER-AFFECTING, only on explicit ask, see Non-Disruptive Automation above)
coterm select-workspace --workspace workspace:2
coterm focus-pane --workspace "${COTERM_WORKSPACE_ID:-}" --pane pane:2
coterm focus-panel --workspace "${COTERM_WORKSPACE_ID:-}" --panel surface:3
```

## Caller Terminal

The current terminal is the surface that invoked the agent. Treat it as the safest anchor for relative operations.

```bash
# send to the focused terminal in the caller workspace
coterm send "npm test\n"

# send to the exact caller surface
coterm send --surface "${COTERM_SURFACE_ID:-}" "git status\n"
coterm send-key --surface "${COTERM_SURFACE_ID:-}" enter
```

Do not send keystrokes, close surfaces, or change focus in other workspaces unless the user asked for that target.

## Moving Surfaces

Reorder a surface within its pane:

```bash
coterm move-surface --surface "${COTERM_SURFACE_ID}" --before surface:3
coterm move-surface --surface "${COTERM_SURFACE_ID}" --after surface:3
coterm move-surface --surface "${COTERM_SURFACE_ID}" --index 0
```

Move a surface to another existing pane. Pass `--focus false` to keep the user's current attention put:

```bash
coterm move-surface --surface surface:240 --pane pane:172 --focus false
```

Split a surface off into a new pane:

```bash
coterm drag-surface-to-split --surface surface:240 down
```

Known papercut: `drag-surface-to-split` currently routes through V1 and resolves the workspace via UI focus, so it can fail with `ERROR: Surface not found` when the caller's workspace is not the visually focused one. Tracked at https://github.com/emergent-inc/coterm/issues/1901, related to https://github.com/emergent-inc/coterm/issues/3189. Until that lands, prefer building the layout additively (see Non-Disruptive Automation above) over create-then-split.

Do not call `focus-pane` or `focus-panel` to recover from a failed move. Report the failure and stop.

## Sidebar State

Status, progress, and logs should usually be attached to the current workspace so the sidebar reflects this task.

```bash
coterm set-status build "running" --workspace "${COTERM_WORKSPACE_ID:-}" --color "#ff9500"
coterm set-progress 0.4 --label "Building" --workspace "${COTERM_WORKSPACE_ID:-}"
coterm log --workspace "${COTERM_WORKSPACE_ID:-}" --level info -- "Started build"
coterm sidebar-state --workspace "${COTERM_WORKSPACE_ID:-}" --json
coterm clear-status build --workspace "${COTERM_WORKSPACE_ID:-}"
coterm clear-progress --workspace "${COTERM_WORKSPACE_ID:-}"
```

## Contributor Reloads

For coterm app/runtime changes in a coterm source checkout, use tagged reloads from the active worktree. A tagged reload creates an isolated app name, bundle ID, debug socket, and DerivedData path.

```bash
./scripts/reload.sh --tag <short-tag>
```

Never build or launch untagged `Coterm DEV`. If tests or tools need a socket, use the tag-specific socket:

```bash
COTERM_SOCKET_PATH=/tmp/coterm-debug-<short-tag>.sock coterm identify --json
```

## Socket and Access

Use the socket path provided by coterm before falling back to defaults:

```bash
SOCK="${COTERM_SOCKET_PATH:-/tmp/coterm.sock}"
```

Socket access can be off, restricted to coterm-spawned processes, or allow all local processes. If a command cannot connect, inspect capabilities before changing settings:

```bash
coterm capabilities --json
coterm ping
```

## References

- [references/commands.md](references/commands.md) enumerates workspace, pane, surface, notification, and utility commands.
- [../coterm-browser/SKILL.md](../coterm-browser/SKILL.md) covers browser surfaces with the same current-workspace rule.

## Rules

- Work in the current caller workspace by default.
- Use `COTERM_WORKSPACE_ID`, `COTERM_SURFACE_ID`, and `COTERM_SOCKET_PATH` before focused-window fallbacks.
- Prefer explicit `--workspace` and `--surface` flags for mutating actions.
- Never call `focus-pane`, `focus-panel`, `select-workspace`, or focus-changing `tab-action` verbs unless the user explicitly asked. The user may be visually on a different workspace, window, or app.
- Pass `--focus false` on `move-surface` and any creation verb that supports it.
- For auxiliary output, reuse the right-side helper pane; create one only if it does not exist.
- Build layout additively with `new-pane --type ... --url ...` rather than create-then-move-then-focus chains.
- If a CLI command rejects a valid surface or pane ref, report it to the user. Do not work around by focusing.
- Do not close, focus, move, or send input to another workspace unless the user names that target.
- Use short refs for chat and command examples. Use UUIDs only for logs, persistence, or debugging.
- For app/runtime changes in a coterm source checkout, reload with `./scripts/reload.sh --tag <tag>` from the worktree before dogfood handoff.
