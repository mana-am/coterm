<div align="center">

# Coterm

**Native macOS terminal and browser workspace for AI coding agents, with self-hosted real-time collaboration.**

[![GitHub Release](https://img.shields.io/github/v/release/mana-am/coterm?color=369eff&labelColor=black&logo=github&style=flat-square)](https://github.com/mana-am/coterm/releases)
[![Platform](https://img.shields.io/badge/platform-macOS-111111?labelColor=black&logo=apple&style=flat-square)](https://github.com/mana-am/coterm/releases/latest)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-white?labelColor=black&style=flat-square)](./LICENSE)
[![Self Host](https://img.shields.io/badge/collaboration-self--hosted-39d353?labelColor=black&style=flat-square)](./coterm/instruction.md)

[English](README.md) | [简体中文](README.zh-cn.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Русский](README.ru.md)

[Download](https://github.com/mana-am/coterm/releases/latest) · [Installation](#installation) · [Self-host Collaboration](./coterm/instruction.md) · [Attribution](./ATTRIBUTION.md)

</div>

---

<div align="center">

<a href="https://youtu.be/13qSk6Fgct0">
  <img src="./docs/assets/coterm-collab-demo-thumb.png" width="900" alt="Демо совместной работы Coterm в реальном времени — смотреть на YouTube" />
</a>

<sub>▶ <a href="https://youtu.be/13qSk6Fgct0">Смотреть демо — двое разработчиков управляют одной сессией Claude Code вживую</a></sub>

</div>

---

Coterm is a macOS app for developers who run Claude Code, Codex, OpenCode, Gemini CLI, Aider, Amp, Cursor Agent, or other terminal-based coding agents in parallel.

## Installation

Coterm has two pieces:

- **Mac app**: the native terminal/browser workspace you run locally.
- **Self-hosted collaboration backend**: Cloudflare Workers you deploy yourself for room sharing, presence, approval flows, and preview sharing.

### TL;DR

| You want | Do this | What you get |
| :--- | :--- | :--- |
| Use Coterm locally | Download the latest DMG | `Coterm.app` for macOS |
| Use collaboration | Deploy the self-host backend | Your own relay, control plane, and presence workers |
| Build from source | Clone with submodules and run setup | A local Debug or Release build |

### For Humans

**We recommend letting an LLM agent install collaboration for you.** The self-host backend involves Cloudflare login, Workers deploy order, Durable Object migrations, worker URLs, and client config.

Paste this prompt into Claude Code, AmpCode, Cursor, Codex, or another coding agent:

```text
Install Coterm and configure its self-hosted collaboration backend by following the instructions here:
https://raw.githubusercontent.com/mana-am/coterm/refs/heads/main/coterm/instruction.md

Coterm is self-host only. Do not configure hosted sign-in, dashboard.coterm.cc, Clerk, Stack Auth, Stripe, or any official hosted Coterm backend. Use my Cloudflare account, deploy the self-host backend, capture the printed COTERM_API_BASE_URL, COTERM_COLLABORATION_RELAY_URL, and COTERM_PRESENCE_BASE_URL values, then configure my local Coterm client with those values.
```

If you only need the macOS app:

```text
https://github.com/mana-am/coterm/releases/latest/download/coterm-macos.dmg
```

Open the DMG and drag `Coterm.app` into `/Applications`.

### For LLM Agents

Fetch the installation guide and follow it end to end:

```bash
curl -fsSL https://raw.githubusercontent.com/mana-am/coterm/refs/heads/main/coterm/instruction.md
```

Rules:

- Coterm collaboration is self-host only.
- Do not configure hosted sign-in or `dashboard.coterm.cc`.
- Use the user's Cloudflare account.
- Prefer `cd coterm && bun install && bunx wrangler login && bun run deploy:self-host`.
- Capture `COTERM_API_BASE_URL`, `COTERM_COLLABORATION_RELAY_URL`, and `COTERM_PRESENCE_BASE_URL`.

## What Is Coterm?

Coterm combines native terminal rendering powered by libghostty, vertical workspaces, tabs, split panes, browser panes, notifications, local CLI/socket automation, and optional self-hosted real-time collaboration.

## Collaboration Is Self-Hosted

Coterm does not provide a public hosted collaboration backend. Deploy it to your own Cloudflare account:

```bash
cd coterm
bun install
bunx wrangler login
bun run deploy:self-host
```

The script prints:

```text
COTERM_API_BASE_URL=...
COTERM_COLLABORATION_RELAY_URL=...
COTERM_PRESENCE_BASE_URL=...
```

## Share Security

A room code alone is not enough to join. Coterm uses a short room code, a high-entropy share secret, and owner approval before a guest receives a relay grant.

## Lineage

Coterm is an independent open-source distribution built from the Mosaic/cmux code lineage. It is not an official Mosaic or cmux release. Ghostty is used through libghostty/GhosttyKit as the terminal rendering foundation.

See [ATTRIBUTION.md](./ATTRIBUTION.md), [docs/coterm-cmux-compat.md](./docs/coterm-cmux-compat.md), and [docs/upstream-cmux-sync.md](./docs/upstream-cmux-sync.md).

## Build From Source

```bash
git clone --recursive https://github.com/mana-am/coterm.git
cd coterm
./scripts/setup.sh
./scripts/reload.sh --tag local
```

## Documentation

- [Self-host collaboration install guide](./coterm/instruction.md)
- [Client setup](./coterm/docs/client-setup.md)
- [Preview sharing](./coterm/docs/preview-sharing.md)
- [Attribution](./ATTRIBUTION.md)

## License

Coterm is open source under GPL-3.0-or-later. See [LICENSE](./LICENSE).
