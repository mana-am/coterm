<div align="center">

# Coterm

**AI coding agent를 위한 네이티브 macOS 터미널/브라우저 workspace. 실시간 협업은 self-hosted 방식입니다.**

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
  <img src="./docs/assets/coterm-collab-demo-thumb.png" width="900" alt="Coterm 실시간 협업 데모 — YouTube에서 보기" />
</a>

<sub>▶ <a href="https://youtu.be/13qSk6Fgct0">데모 보기 — 두 개발자가 같은 Claude Code 세션을 실시간으로 조작</a></sub>

</div>

---

Coterm은 Claude Code, Codex, OpenCode, Gemini CLI, Aider, Amp, Cursor Agent 같은 terminal-based coding agent를 동시에 사용하는 개발자를 위한 macOS 앱입니다.

## Installation

Coterm은 두 부분으로 구성됩니다.

- **Mac app**: 로컬에서 실행되는 네이티브 terminal/browser workspace.
- **Self-hosted collaboration backend**: room sharing, presence, approval flow, preview sharing이 필요할 때 사용자의 Cloudflare 계정에 배포합니다.

### TL;DR

| You want | Do this | What you get |
| :--- | :--- | :--- |
| Use Coterm locally | Download the latest DMG | `Coterm.app` for macOS |
| Use collaboration | Deploy the self-host backend | Your own relay, control plane, and presence workers |
| Build from source | Clone with submodules and run setup | A local Debug or Release build |

### For Humans

**LLM agent에게 설치를 맡기는 것을 권장합니다.** Self-host backend는 Cloudflare login, Workers deploy order, Durable Object migrations, worker URLs, client config를 정확히 처리해야 합니다.

Claude Code, AmpCode, Cursor, Codex 같은 coding agent에 이 prompt를 붙여 넣으세요.

```text
Install Coterm and configure its self-hosted collaboration backend by following the instructions here:
https://raw.githubusercontent.com/mana-am/coterm/refs/heads/main/coterm/instruction.md

Coterm is self-host only. Do not configure hosted sign-in, dashboard.coterm.cc, Clerk, Stack Auth, Stripe, or any official hosted Coterm backend. Use my Cloudflare account, deploy the self-host backend, capture the printed COTERM_API_BASE_URL, COTERM_COLLABORATION_RELAY_URL, and COTERM_PRESENCE_BASE_URL values, then configure my local Coterm client with those values.
```

macOS app만 필요하다면:

```text
https://github.com/mana-am/coterm/releases/latest/download/coterm-macos.dmg
```

DMG를 열고 `Coterm.app`을 `/Applications`로 드래그하세요.

### For LLM Agents

설치 가이드를 가져와 끝까지 따르세요.

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

Coterm은 public hosted collaboration backend를 제공하지 않습니다. 사용자의 Cloudflare 계정에 배포하세요.

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

room code만으로는 입장할 수 없습니다. Coterm은 short room code, high-entropy share secret, owner approval을 사용한 뒤 guest에게 relay grant를 발급합니다.

## Lineage

Coterm은 Mosaic/cmux code lineage를 기반으로 한 독립 open-source distribution입니다. 공식 Mosaic 또는 cmux release가 아닙니다. Ghostty는 libghostty/GhosttyKit을 통해 terminal rendering foundation으로 사용됩니다.

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
