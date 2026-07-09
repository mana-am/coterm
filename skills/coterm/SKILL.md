---
name: coterm
description: End-user control of coterm topology and routing (windows, workspaces, panes/surfaces, focus, moves, reorder, identify, trigger flash). Use when automation needs deterministic placement and navigation in a multi-pane coterm layout.
---

# coterm Core Control

Use this skill to control non-browser coterm topology and routing.

## Core Concepts

- Window: top-level macOS coterm window.
- Workspace: tab-like group within a window.
- Pane: split container in a workspace.
- Surface: a tab within a pane (terminal or browser panel).

## Fast Start

```bash
# identify current caller context
coterm identify --json

# list topology
coterm list-windows
coterm list-workspaces
coterm list-panes
coterm list-pane-surfaces --pane pane:1

# create/focus/move
coterm new-workspace
coterm new-split right --panel pane:1
coterm move-surface --surface surface:7 --pane pane:2 --focus true
coterm split-off --surface surface:7 right
coterm reorder-surface --surface surface:7 --before surface:3

# attention cue
coterm trigger-flash --surface surface:7
```

## Settings and Docs

Use `coterm docs settings` before changing coterm-owned settings. It prints the docs URL, schema URL, raw GitHub resources, coterm.json paths, and reload command.

```bash
coterm docs settings
coterm settings path
```

coterm-owned settings live in `~/.config/coterm/coterm.json`. Legacy `~/.config/coterm/settings.json` and `~/Library/Application Support/coterm.com.emergent.app/settings.json` files are read only as fallback for missing keys. Before editing, copy any existing `coterm.json` file to a timestamped `.bak` next to it so the user can revert. Edit the user file, then reload:

```bash
coterm reload-config
```

`coterm reload-config` reloads BOTH `coterm.json` and Ghostty config (`~/.config/ghostty/config`) and refreshes terminals in place. No app restart needed.

Use coterm settings for app behavior, sidebar, notifications, browser behavior, automation, workspace colors, and coterm-owned shortcuts. Terminal rendering settings such as font, cursor style, theme, scrollback, background transparency (`background-opacity`), and blur (`background-blur`) belong in Ghostty config at `~/.config/ghostty/config`.

Open the UI when useful:

```bash
coterm settings
coterm settings coterm-json
coterm settings shortcuts
```

## Handle Model

- Default output uses short refs: `window:N`, `workspace:N`, `pane:N`, `surface:N`.
- UUIDs are still accepted as inputs.
- Request UUID output only when needed: `--id-format uuids|both`.

## Deep-Dive References

| Reference | When to Use |
|-----------|-------------|
| [references/handles-and-identify.md](references/handles-and-identify.md) | Handle syntax, self-identify, caller targeting |
| [references/windows-workspaces.md](references/windows-workspaces.md) | Window/workspace lifecycle and reorder/move |
| [references/panes-surfaces.md](references/panes-surfaces.md) | Splits, surfaces, move/reorder, focus routing |
| [references/trigger-flash-and-health.md](references/trigger-flash-and-health.md) | Flash cue and surface health checks |
| [../coterm-workspace/SKILL.md](../coterm-workspace/SKILL.md) | Current caller workspace rules and non-disruptive automation |
| [../coterm-settings/SKILL.md](../coterm-settings/SKILL.md) | Safe coterm.json settings edits and validation |
| [../coterm-browser/SKILL.md](../coterm-browser/SKILL.md) | Browser automation on surface-backed webviews |
| [../coterm-markdown/SKILL.md](../coterm-markdown/SKILL.md) | Markdown viewer panel with live file watching |
