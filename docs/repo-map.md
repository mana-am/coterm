# Coterm Repo Map

Use this map before moving files or choosing an implementation directory. The
repository still contains upstream lineage, legacy hosted services, current app
code, and the new self-host backend; picking the wrong directory is the main
source of accidental churn.

## Current product paths

| Area | Path | Use for |
| --- | --- | --- |
| macOS app | `Sources/`, `CLI/`, `daemon/`, `Resources/`, `coterm.xcodeproj`, `coterm.xcworkspace` | Coterm desktop app, bundled CLI, helper daemon, resources, app tests. |
| Shared Swift packages | `Packages/Shared/` | Swift packages consumed by more than one app target. |
| macOS-only Swift packages | `Packages/macOS/` | Swift packages used only by the macOS app. |
| iOS-only Swift packages | `Packages/iOS/` | Swift packages used only by iOS targets. |
| iOS app | `ios/` | iOS client, iOS workspace, iOS tests, iOS reload scripts. |
| Website and docs app | `web/` | Public site, docs pages, message catalogs, web services. |
| Embedded webviews | `webviews/` | Webview bundles loaded by the app. |
| Self-host collaboration backend | `coterm/` | Open-source Cloudflare Worker stack, deploy scripts, self-host docs, preview sharing host tooling. |

## Worker directories

There are two worker families. Do not treat them as interchangeable.

| Path | Status | Notes |
| --- | --- | --- |
| `coterm/workers/relay` | Active self-host collaboration relay | New collaboration and preview-sharing transport work belongs here. |
| `coterm/workers/control-plane` | Active self-host control plane | Session creation, grants, auth modes, and relay URL wiring belong here. |
| `coterm/workers/presence` | Active self-host presence worker | Self-hosted presence for the `coterm/` stack belongs here. |
| `workers/presence` | Active root device presence service | Team/device presence used by app integration and dev worker workflows. Do not fold it into the self-host package without an explicit migration task. |
| `workers/collaboration` | Legacy hosted Phase 1 relay | Keep for compatibility and historical hosted-worker CI. New self-host collaboration work should not be added here. |

## Upstream and vendor boundaries

| Path | Boundary |
| --- | --- |
| `ghostty/` | Ghostty submodule. Use the Ghostty submodule workflow before changing it. |
| `vendor/` | Vendored dependencies. Preserve upstream layout unless the task is explicitly vendor maintenance. |
| `homebrew-coterm/` | Tap submodule/history boundary. Release packaging changes need the release workflow. |
| `Native/` | Native support code and generated/native integration boundaries. Keep changes scoped to the caller. |
| `Examples/`, `Prototypes/`, `experiments/`, `plans/`, `dogfood/` | Reference, prototype, or planning material. Do not move product code into these directories. |
| `logs/`, `reports.md`, `TODO.md` | Local/debug/project notes. Do not use as product source of truth. |

## Task routing

- Desktop UI, shortcuts, settings, panels, sidebar, terminal rendering: start in
  `Sources/`, then follow package ownership if the code is already packaged.
- Cross-platform Swift model/protocol code: prefer an existing package under
  `Packages/Shared/`; create or move packages only with the workspace package
  group script.
- iOS UI or mobile pairing: start in `ios/` and shared mobile packages.
- Public docs/site copy: start in `web/` for site pages or `docs/` for repo
  engineering docs.
- User self-host installation, relay, control-plane, preview sharing, and
  self-host auth: start in `coterm/`.
- Root device presence service: use `workers/presence`.
- Legacy hosted collaboration relay: use `workers/collaboration` only when the
  task explicitly targets that legacy worker.
- Upstream cmux sync: read `docs/upstream-cmux-sync.md` and
  `docs/coterm-cmux-compat.md` before editing.

## Cleanup rules

- Do not globally rename `cmux`, `CMUX`, `Mosaic`, or legacy domains. Some
  names are compatibility shims, attribution, external project names, or
  submodule history.
- Do not move Swift package directories by hand. Use the package group policy in
  `AGENTS.md`.
- Do not move Xcode project files unless the task is explicitly project
  normalization.
- Do not merge the root workers into `coterm/` or vice versa without a migration
  plan that covers deploy workflows, Durable Object namespaces, secrets, and
  client defaults.
