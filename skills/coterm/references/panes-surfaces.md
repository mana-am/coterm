# Panes and Surfaces

Split layout, surface creation, focus, move, and reorder.

## Inspect

```bash
coterm list-panes
coterm list-pane-surfaces --pane pane:1
```

## Create Splits/Surfaces

```bash
coterm new-split right --panel pane:1
coterm new-surface --type terminal --pane pane:1
coterm new-surface --type browser --pane pane:1 --url https://example.com
```

## Focus and Close

```bash
coterm focus-pane --pane pane:2
coterm focus-panel --panel surface:7
coterm close-surface --surface surface:7
```

## Move/Reorder Surfaces

```bash
coterm move-surface --surface surface:7 --pane pane:2 --focus true
coterm move-surface --surface surface:7 --workspace workspace:2 --window window:1 --after surface:4
coterm split-off --surface surface:7 right
coterm reorder-surface --surface surface:7 --before surface:3
```

Surface identity is stable across move/reorder/split-off operations. Layout commands are focus-neutral by default; pass `--focus true` only when you want the moved or created surface selected.
