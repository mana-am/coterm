# Coterm/cmux Compatibility Register

Coterm is a separate product distribution, but the repo still contains names
from the cmux/Mosaic lineage. This file records which remnants are intentional.
Use it with `docs/upstream-cmux-sync.md` before doing any rename or upstream
sync.

## Allowed remnants

| Remnant | Where | Why it stays |
| --- | --- | --- |
| `CMUX_THEME_PICKER_*` | `CLI/CotermCLI+Themes.swift` | Existing Ghostty theme picker helpers still read these environment variables. Keep until every shipped helper supports `COTERM_THEME_PICKER_*`. |
| `cmux/crash` | GhosttyKit build scripts, crash storage policy, CI build flavor names | Published GhosttyKit artifacts still write breadcrumbs under this crash subdirectory. Coterm also checks `coterm` first. |
| `crashsubdir-cmux-crash-v1` | GhosttyKit CI and checksum metadata | Artifact flavor name for the current prebuilt GhosttyKit line. Rename only when publishing a new artifact flavor. |
| `cmux.render-grid.v1` | Mobile render-grid decoder and tests | Wire compatibility for older peers/mobile clients that may still emit the legacy format tag. |
| `homebrew-cmux` history | `.gitmodules`, `homebrew-coterm/` | Submodule/upstream tap history. Treat it as release packaging maintenance, not ordinary product naming cleanup. |
| External project names containing `cmux` | `web/app/[locale]/community/awesome-coterm-projects.ts` | These are third-party repository names and URLs. Do not rewrite external names. |
| Mosaic attribution | `README.md`, `ATTRIBUTION.md`, `coterm/NOTICE`, `coterm/LICENSE` | Required lineage and license attribution. |
| Upstream-sync documentation | `CONTRIBUTING.md`, `docs/upstream-cmux-sync.md`, this file | Explains how to port selected upstream fixes without overwriting Coterm identity. |

## Not allowed for new work

- New user-visible Coterm UI should not say `cmux` unless it is explicitly
  describing upstream compatibility or a third-party project.
- New protocol names should use Coterm-owned names such as `cotermv1`; only add
  legacy aliases when there is a concrete compatibility target.
- New backend or deployment docs should not point users at hosted cmux services.
  Coterm collaboration is self-host only.
- New package, app, cask, socket, config, URL scheme, or domain names should use
  Coterm identity.

## Removal checklist

Before deleting an allowed remnant:

1. Identify the minimum app/helper/backend version that no longer depends on it.
2. Add or update focused compatibility tests around the migration.
3. Update this register and `docs/upstream-cmux-sync.md`.
4. Run a targeted search:

```bash
rg --hidden -n "cmux|CMUX|Cmux" \
  -g '!.git/**' \
  -g '!ghostty/**' \
  -g '!vendor/**' \
  -g '!**/node_modules/**' \
  -g '!**/.build/**' \
  -g '!**/target/**'
```

5. Confirm every remaining hit is still in this register, attribution, vendor
   history, or an external project name.
