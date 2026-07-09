# Upstream cmux Sync Policy

Coterm is not just "cmux plus realtime collaboration." It is an independent
Coterm distribution built from the cmux/Mosaic lineage. Coterm keeps the
terminal/workspace/browser foundation, then changes product identity,
deployment, update feeds, protocol names, self-hostable collaboration backend,
mobile pairing, and Coterm-specific packaging.

That means upstream cmux improvements can be valuable, but they cannot be pulled
as a blind overwrite.

## Product boundary

Think of Coterm as three layers:

1. **Upstream terminal/workspace base**: terminal surfaces, panes, workspaces,
   browser surface, command palette, settings, Ghostty integration, and general
   app ergonomics inherited from the cmux/Mosaic code line.
2. **Coterm-owned product identity**: app name, icon, bundle identifiers, URL
   schemes, socket paths, config paths, domains, update feeds, docs, release
   packaging, and user-visible brand.
3. **Coterm-owned collaboration/deployment**: `cotermv1` protocol naming,
   self-hostable Cloudflare Workers backend, relay/control-plane/presence
   deployment, auth modes, mobile pairing, and Coterm compatibility layers.

Layer 1 is the main place where upstream cmux changes should be evaluated.
Layers 2 and 3 are Coterm-owned and should not be overwritten by upstream
branding, hosted-service defaults, or incompatible protocol assumptions.

## Compatibility rule

Keep compatibility shims when users or bundled helper binaries still depend on
old names.

The current compatibility allow-list lives in
`docs/coterm-cmux-compat.md`. Update that register whenever adding, removing,
or intentionally preserving a cmux/Mosaic remnant.

Current examples:

- `CMUX_THEME_PICKER_*` environment variables are still set for the Ghostty theme
  picker helper until every shipped helper reads `COTERM_THEME_PICKER_*`.
- `cmux/crash` remains accepted as a GhosttyKit crash breadcrumb subdirectory
  while prebuilt artifacts still use that path.
- Legacy render-grid tags such as `cmux.render-grid.v1` remain accepted while
  mobile clients or older peers may still emit them.

When removing a compatibility shim, document the minimum version that no longer
needs it and add focused tests for the migration.

## Sync workflow

Use a dedicated upstream remote and branch. Do not merge directly into the main
Coterm branch.

```bash
git remote add cmux https://github.com/manaflow-ai/cmux.git
git fetch cmux
git switch -c sync-cmux-YYYY-MM-DD
```

Then choose one of these strategies:

- **Cherry-pick small fixes** when the upstream change is narrow and does not
  depend on broad project renames.
- **Range-diff/rebase a patch stack** when pulling a batch of upstream changes.
- **Manual port** when the upstream change crosses Coterm-owned identity,
  protocol, signing, release, or backend boundaries.

For every sync, record:

- Upstream repository and commit range.
- Why the changes are useful for Coterm.
- Files intentionally skipped.
- Conflicts and how they were resolved.
- Any compatibility shims added or removed.
- Validation performed.

## Change classification

Pull candidates:

- Terminal rendering fixes that do not require Ghostty fork changes.
- Workspace, pane, tab, browser, command palette, settings, and CLI improvements.
- Performance fixes and crash fixes.
- Tests that still apply to Coterm behavior.
- Documentation ideas that do not create brand or deployment confusion.

Manual-port candidates:

- Changes touching app identity, bundle IDs, entitlements, URL schemes, socket
  names, config paths, update feeds, release scripts, or signing.
- Changes touching collaboration protocol names, auth, relay URLs, backend
  deployment, mobile pairing, or hosted-service assumptions.
- Changes touching GhosttyKit build flags or prebuilt artifact naming.
- Changes that assume cmux-owned domains, package names, casks, or npm package
  names.

Usually skip:

- Pure cmux brand/assets/marketing changes.
- Hosted-service-only features that conflict with Coterm self-hosting.
- Changes that remove compatibility with existing Coterm installs.

## Validation

At minimum after a sync:

```bash
rg --hidden -n "cmux|CMUX|Cmux" \
  -g '!.git/**' \
  -g '!ghostty/**' \
  -g '!vendor/**' \
  -g '!**/node_modules/**' \
  -g '!**/target/**' \
  -g '!**/.build/**' \
  -g '!web/.next/**' \
  -g '!**/build/**'
```

Every remaining hit must be one of:

- A documented compatibility shim.
- A historical upstream reference.
- A third-party/community project name.
- A generated or vendored artifact that is intentionally not edited.

Then run focused checks for the touched area. For broad Swift/app syncs, use the
tagged reload path:

```bash
COTERM_DEV_FAST_RELOAD=1 ./scripts/reload.sh --tag sync-cmux
```

Use the normal non-fast reload when the sync touches Ghostty, helper binaries,
packaging, signing, bundle IDs, socket isolation, update feeds, or release
assets.

## Release note

Do not describe upstream syncs as "upgraded to cmux" in user-facing release
notes. Prefer:

```text
Pulled selected upstream terminal/workspace fixes from the cmux code line and
ported them to Coterm.
```

This keeps attribution clear without implying Coterm is an official cmux build
or that Coterm can be replaced by upstream cmux.
