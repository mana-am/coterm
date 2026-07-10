<div align="center">

<img src="./docs/assets/main-first-image.png" alt="Coterm screenshot" width="900" />

# Coterm

**AI coding agent のためのネイティブ macOS ターミナル/ブラウザ workspace。リアルタイム協調機能は self-hosted です。**

[![GitHub Release](https://img.shields.io/github/v/release/mana-am/coterm?color=369eff&labelColor=black&logo=github&style=flat-square)](https://github.com/mana-am/coterm/releases)
[![Platform](https://img.shields.io/badge/platform-macOS-111111?labelColor=black&logo=apple&style=flat-square)](https://github.com/mana-am/coterm/releases/latest)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-white?labelColor=black&style=flat-square)](./LICENSE)
[![Self Host](https://img.shields.io/badge/collaboration-self--hosted-39d353?labelColor=black&style=flat-square)](./coterm/instruction.md)

[English](README.md) | [简体中文](README.zh-cn.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Русский](README.ru.md)

[Download](https://github.com/mana-am/coterm/releases/latest) · [Installation](#installation) · [Self-host Collaboration](./coterm/instruction.md) · [Attribution](./ATTRIBUTION.md)

</div>

---

Coterm は Claude Code、Codex、OpenCode、Gemini CLI、Aider、Amp、Cursor Agent など、複数の terminal-based coding agent を並行して使う開発者向けの macOS アプリです。

## Installation

Coterm は 2 つの要素で構成されます。

- **Mac app**: ローカルで動くネイティブ terminal/browser workspace。
- **Self-hosted collaboration backend**: room sharing、presence、approval flow、preview sharing が必要なときに、自分の Cloudflare アカウントへデプロイします。

### TL;DR

| You want | Do this | What you get |
| :--- | :--- | :--- |
| Use Coterm locally | Download the latest DMG | `Coterm.app` for macOS |
| Use collaboration | Deploy the self-host backend | Your own relay, control plane, and presence workers |
| Build from source | Clone with submodules and run setup | A local Debug or Release build |

### For Humans

**LLM agent にインストールを任せることを推奨します。** Self-host backend では Cloudflare login、Workers deploy order、Durable Object migrations、worker URLs、client config を正しく扱う必要があります。

Claude Code、AmpCode、Cursor、Codex などの coding agent に次の prompt を貼り付けてください。

```text
Install Coterm and configure its self-hosted collaboration backend by following the instructions here:
https://raw.githubusercontent.com/mana-am/coterm/refs/heads/main/coterm/instruction.md

Coterm is self-host only. Do not configure hosted sign-in, dashboard.coterm.cc, Clerk, Stack Auth, Stripe, or any official hosted Coterm backend. Use my Cloudflare account, deploy the self-host backend, capture the printed COTERM_API_BASE_URL, COTERM_COLLABORATION_RELAY_URL, and COTERM_PRESENCE_BASE_URL values, then configure my local Coterm client with those values.
```

macOS app だけが必要な場合:

```text
https://github.com/mana-am/coterm/releases/latest/download/coterm-macos.dmg
```

DMG を開き、`Coterm.app` を `/Applications` にドラッグしてください。

### For LLM Agents

次の guide を取得して、最初から最後まで実行してください。

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

Coterm combines:

- native terminal rendering powered by libghostty;
- vertical workspaces, tabs, and split panes;
- in-app browser panes that agents can inspect and control;
- notifications for long-running agent sessions;
- a local CLI and socket API;
- optional self-hosted real-time collaboration.

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
