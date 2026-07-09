# Trigger Flash and Surface Health

Operational checks useful in automation loops.

## Trigger Flash

Flash a surface or workspace to provide visual confirmation in UI:

```bash
coterm trigger-flash --surface surface:7
coterm trigger-flash --workspace workspace:2
```

## Surface Health

Use health output to detect hidden/detached/non-windowed surfaces:

```bash
coterm surface-health
coterm surface-health --workspace workspace:2
```

Use this before routing focused input if UI state may be stale.
