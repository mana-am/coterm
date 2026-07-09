# coterm Workspace Command Reference

Use these commands from a coterm terminal. Most commands infer the caller workspace from `COTERM_WORKSPACE_ID`, but explicit flags are safer for automation.

## Context

```bash
coterm identify --json
coterm current-workspace --json
coterm capabilities --json
coterm ping
```

## Windows and Workspaces

```bash
coterm list-windows
coterm current-window
coterm new-window
coterm focus-window --window window:2
coterm close-window --window window:2

coterm list-workspaces
coterm list-workspaces --json
coterm new-workspace --name "task" --cwd "$PWD"
coterm new-workspace --command "npm run dev"
coterm new-workspace --layout '{"root":{"type":"terminal"}}'
coterm current-workspace
coterm select-workspace --workspace workspace:2
coterm rename-workspace --workspace workspace:2 -- "new name"
coterm close-workspace --workspace workspace:2
coterm reorder-workspace --workspace workspace:4 --before workspace:2
coterm move-workspace-to-window --workspace workspace:4 --window window:1
```

## Panes and Surfaces

```bash
coterm list-panes --workspace "$COTERM_WORKSPACE_ID"
coterm list-pane-surfaces --workspace "$COTERM_WORKSPACE_ID" --pane pane:1
coterm list-panels --workspace "$COTERM_WORKSPACE_ID"
coterm tree --workspace "$COTERM_WORKSPACE_ID"

coterm new-split right --workspace "$COTERM_WORKSPACE_ID"
coterm new-split down --workspace "$COTERM_WORKSPACE_ID" --surface "$COTERM_SURFACE_ID"
coterm new-pane --workspace "$COTERM_WORKSPACE_ID" --type terminal --direction right
coterm new-pane --workspace "$COTERM_WORKSPACE_ID" --type browser --url http://localhost:3000
coterm new-surface --workspace "$COTERM_WORKSPACE_ID" --type terminal --pane pane:1
coterm new-surface --workspace "$COTERM_WORKSPACE_ID" --type browser --pane pane:1 --url http://localhost:3000

coterm focus-pane --workspace "$COTERM_WORKSPACE_ID" --pane pane:2
coterm focus-panel --workspace "$COTERM_WORKSPACE_ID" --panel surface:3
coterm close-surface --workspace "$COTERM_WORKSPACE_ID" --surface surface:3
coterm move-surface --surface surface:7 --pane pane:2 --focus true
coterm reorder-surface --surface surface:7 --before surface:3
coterm move-tab-to-new-workspace --surface surface:7 --title "browser"
```

## Input

```bash
coterm send "echo hello\n"
coterm send-key enter
coterm send --surface "$COTERM_SURFACE_ID" "git status\n"
coterm send-key --surface "$COTERM_SURFACE_ID" enter
coterm read-screen --surface "$COTERM_SURFACE_ID"
```

## Sidebar Metadata

```bash
coterm set-status build "running" --workspace "$COTERM_WORKSPACE_ID" --icon hammer --color "#ff9500"
coterm clear-status build --workspace "$COTERM_WORKSPACE_ID"
coterm list-status --workspace "$COTERM_WORKSPACE_ID"
coterm set-progress 0.5 --workspace "$COTERM_WORKSPACE_ID" --label "Building"
coterm clear-progress --workspace "$COTERM_WORKSPACE_ID"
coterm log --workspace "$COTERM_WORKSPACE_ID" --level info -- "Build started"
coterm list-log --workspace "$COTERM_WORKSPACE_ID" --limit 20
coterm clear-log --workspace "$COTERM_WORKSPACE_ID"
coterm sidebar-state --workspace "$COTERM_WORKSPACE_ID" --json
```

## Notifications and Attention

```bash
coterm notify --title "Done" --body "Task complete"
coterm list-notifications --json
coterm clear-notifications
coterm trigger-flash --workspace "$COTERM_WORKSPACE_ID" --surface "$COTERM_SURFACE_ID"
coterm surface-health --workspace "$COTERM_WORKSPACE_ID" --json
```

## Config and Docs

```bash
coterm docs api
coterm docs browser
coterm docs settings
coterm settings path
coterm settings coterm-json
coterm settings shortcuts
coterm reload-config
```

## Tagged Reloads

```bash
./scripts/reload.sh --tag <short-tag>
COTERM_SOCKET_PATH=/tmp/coterm-debug-<short-tag>.sock coterm identify --json
```
