<h1 align="center">Coterm</h1>

<p align="center">
  A native macOS terminal and browser workspace for AI coding agents, with self-hosted real-time collaboration.
</p>

<p align="center">
  <a href="https://github.com/mana-am/coterm/releases/latest/download/coterm-macos.dmg">
    <img src="./docs/assets/macos-badge.png" alt="Download Coterm for macOS" width="180" />
  </a>
</p>

<p align="center">
  <a href="https://github.com/mana-am/coterm/releases/latest">Download</a>
  ·
  <a href="./coterm/instruction.md">Self-host Collaboration</a>
  ·
  <a href="./ATTRIBUTION.md">Attribution</a>
</p>

<p align="center">
  <img src="./docs/assets/main-first-image.png" alt="Coterm screenshot" width="900" />
</p>

## What Is Coterm?

Coterm is an open-source macOS app for running coding agents in a terminal-first workflow.

It combines:

- a native macOS terminal powered by libghostty;
- vertical workspaces, tabs, and split panes;
- an in-app browser that agents can inspect and control;
- notification rings and unread state for long-running agent sessions;
- a CLI and socket API for automation;
- self-hosted real-time collaboration for shared agent rooms.

Coterm is designed for developers who run Claude Code, Codex, OpenCode, Gemini CLI, Aider, Amp, Cursor Agent, or other terminal-based coding agents in parallel.

## Download

Download the latest macOS build:

```text
https://github.com/mana-am/coterm/releases/latest/download/coterm-macos.dmg
```

Open the DMG and drag `Coterm.app` into `/Applications`.

The first public build is ad-hoc signed but not Apple Developer ID notarized yet. On first launch, macOS may require right-clicking `Coterm.app`, choosing `Open`, and confirming in System Settings.

## Collaboration Is Self-Hosted

Coterm does not ship with a public hosted collaboration backend.

If you want room sharing, presence, approval flows, or preview sharing, deploy the backend in your own Cloudflare account:

```bash
cd coterm
bun install
bunx wrangler login
bun run deploy:self-host
```

Full guide:

```text
coterm/instruction.md
```

For coding agents:

```bash
curl -fsSL https://raw.githubusercontent.com/mana-am/coterm/refs/heads/main/coterm/instruction.md
```

The self-host backend prints the client URLs you need to configure:

```text
COTERM_API_BASE_URL=...
COTERM_COLLABORATION_RELAY_URL=...
COTERM_PRESENCE_BASE_URL=...
```

## Share Security

Coterm room sharing uses more than a short room code.

When a host shares a room, Coterm creates:

- a short room code for usability;
- a high-entropy share secret for join requests;
- a relay grant for the current host session.

Guests submit the room code plus secret. The room owner must approve the pending request before the guest receives a relay grant. A plain room code is not enough to join.

## Features

### Agent Workspaces

Run multiple coding agents side by side. Coterm keeps workspaces, tabs, panes, directories, and notifications visible without forcing agents into a hidden orchestration layer.

### Notifications

Coterm listens for terminal notification sequences and exposes `coterm notify` for agent hooks. Panes and tabs light up when an agent needs attention.

### Browser Panes

Open a browser next to a terminal. Agents can inspect the accessibility tree, click elements, fill forms, evaluate JavaScript, and work against local development servers.

### CLI Automation

Use the `coterm` CLI and local socket API to create workspaces, split panes, send keystrokes, open URLs, and script workflows.

### Ghostty Rendering

Coterm uses libghostty for terminal rendering and reads Ghostty-style terminal configuration for fonts, themes, and colors.

## Build From Source

Clone the repository with submodules:

```bash
git clone --recursive https://github.com/mana-am/coterm.git
cd coterm
./scripts/setup.sh
```

Build a local tagged debug app:

```bash
./scripts/reload.sh --tag local
```

For a release-style unsigned local build:

```bash
xcodebuild -project coterm.xcodeproj \
  -scheme coterm \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Official signed and notarized releases require Apple Developer credentials and should use the release workflow.

## Documentation

- [Self-host collaboration install guide](./coterm/instruction.md)
- [Self-host backend docs](./coterm/docs/self-hosting.md)
- [Client setup](./coterm/docs/client-setup.md)
- [Preview sharing](./coterm/docs/preview-sharing.md)
- [Repository map](./docs/repo-map.md)

## License And Attribution

Coterm is open source under GPL-3.0-or-later. See [LICENSE](./LICENSE).

See [ATTRIBUTION.md](./ATTRIBUTION.md) for upstream attribution, trademark, and redistribution notes.
