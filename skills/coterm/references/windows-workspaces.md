# Windows and Workspaces

Window/workspace lifecycle and ordering operations.

## Inspect

```bash
coterm list-windows
coterm current-window
coterm list-workspaces
coterm current-workspace
```

## Create/Focus/Close

```bash
coterm new-window
coterm focus-window --window window:2
coterm close-window --window window:2

coterm new-workspace
coterm select-workspace --workspace workspace:4
coterm close-workspace --workspace workspace:4
```

## Reorder and Move

```bash
coterm reorder-workspace --workspace workspace:4 --before workspace:2
coterm move-workspace-to-window --workspace workspace:4 --window window:1
```
