<div align="center">

<img src="./docs/assets/main-first-image.png" alt="Coterm 截图" width="900" />

# Coterm

**面向 AI Coding Agent 的原生 macOS 终端与浏览器工作区，协作能力完全自托管。**

[![GitHub Release](https://img.shields.io/github/v/release/mana-am/coterm?color=369eff&labelColor=black&logo=github&style=flat-square)](https://github.com/mana-am/coterm/releases)
[![Platform](https://img.shields.io/badge/platform-macOS-111111?labelColor=black&logo=apple&style=flat-square)](https://github.com/mana-am/coterm/releases/latest)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-white?labelColor=black&style=flat-square)](./LICENSE)
[![Self Host](https://img.shields.io/badge/collaboration-self--hosted-39d353?labelColor=black&style=flat-square)](./coterm/instruction.md)

[English](README.md) | [简体中文](README.zh-cn.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Русский](README.ru.md)

[下载](https://github.com/mana-am/coterm/releases/latest) · [安装](#安装) · [自托管协作](./coterm/instruction.md) · [来源与署名](./ATTRIBUTION.md)

</div>

---

Coterm 适合同时运行 Claude Code、Codex、OpenCode、Gemini CLI、Aider、Amp、Cursor Agent 等终端型 Coding Agent 的开发者。

它提供原生 macOS 终端、分屏工作区、浏览器面板、通知、本地自动化，以及不依赖 Coterm 官方账号服务的自托管实时协作。

## 安装

Coterm 分为两部分：

- **Mac App**：本地运行的原生终端/浏览器工作区。
- **自托管协作后端**：需要房间共享、在线状态、加入审批或预览共享时，由你部署到自己的 Cloudflare 账号。

### TL;DR

| 你想要 | 怎么做 | 得到什么 |
| :--- | :--- | :--- |
| 本地使用 Coterm | 下载最新版 DMG | macOS 上的 `Coterm.app` |
| 使用协作 | 部署自托管后端 | 你自己的 relay、control plane、presence workers |
| 从源码构建 | clone submodules 并运行 setup | 本地 Debug 或 Release build |

### For Humans

**推荐让 LLM agent 帮你安装和配置协作后端。** 自托管会涉及 Cloudflare 登录、Workers 部署顺序、Durable Object migration、worker URL 和客户端配置，交给 agent 更不容易漏步骤。

把这段 prompt 粘贴到 Claude Code、AmpCode、Cursor、Codex 或其他 coding agent：

```text
Install Coterm and configure its self-hosted collaboration backend by following the instructions here:
https://raw.githubusercontent.com/mana-am/coterm/refs/heads/main/coterm/instruction.md

Coterm is self-host only. Do not configure hosted sign-in, dashboard.coterm.cc, Clerk, Stack Auth, Stripe, or any official hosted Coterm backend. Use my Cloudflare account, deploy the self-host backend, capture the printed COTERM_API_BASE_URL, COTERM_COLLABORATION_RELAY_URL, and COTERM_PRESENCE_BASE_URL values, then configure my local Coterm client with those values.
```

如果你只需要 macOS App：

```text
https://github.com/mana-am/coterm/releases/latest/download/coterm-macos.dmg
```

打开 DMG，把 `Coterm.app` 拖到 `/Applications`。

首批公开构建可能是 ad-hoc signed，还没有 Apple Developer ID notarization。首次启动如果被 macOS 拦截，右键 `Coterm.app`，选择 **Open**，并在系统设置里确认。

### For LLM Agents

获取安装指南并完整执行：

```bash
curl -fsSL https://raw.githubusercontent.com/mana-am/coterm/refs/heads/main/coterm/instruction.md
```

如果 raw URL 不可用，但用户在本地 checkout 中，请直接读取 `coterm/instruction.md`。

重要规则：

- Coterm 协作只有 self-host 模式。
- 不要寻找或配置官方托管后端。
- 不要配置 hosted sign-in 或 `dashboard.coterm.cc`。
- 使用用户自己的 Cloudflare 账号。
- 优先执行 `cd coterm && bun install && bunx wrangler login && bun run deploy:self-host`。
- 记录并返回 `COTERM_API_BASE_URL`、`COTERM_COLLABORATION_RELAY_URL`、`COTERM_PRESENCE_BASE_URL`。
- 需要重新打印配置时，使用 `bun run deploy:self-host -- --print-config`。
- 诊断已有部署时，使用 `bun run doctor:self-host`。
- DEBUG Coterm 客户端配置使用 `bun run configure:client`；只有需要指定显示名时才加 `-- --guest-id <name>`。

## Coterm 是什么？

Coterm 是一个开源 macOS App，用于 terminal-first 的 AI coding 工作流。

它包括：

- 基于 libghostty 的原生终端渲染；
- 纵向工作区、tab 和 split pane；
- Agent 可以检查和控制的内置浏览器面板；
- 面向长时间运行 agent session 的通知和未读状态；
- 本地 CLI 和 socket API；
- 可选的自托管实时协作。

## 协作是自托管的

Coterm 不提供公共托管协作后端。需要 room sharing 时，请部署到你自己的 Cloudflare 账号：

```bash
cd coterm
bun install
bunx wrangler login
bun run deploy:self-host
```

部署脚本会输出客户端需要的 URL：

```text
COTERM_API_BASE_URL=...
COTERM_COLLABORATION_RELAY_URL=...
COTERM_PRESENCE_BASE_URL=...
```

完整指南见 [coterm/instruction.md](./coterm/instruction.md)。

## 共享安全

Coterm 的房间共享不只依赖短 room code。

host 分享房间时，Coterm 会生成：

- 便于输入的短 room code；
- 用于加入请求的高熵 share secret；
- 当前 host session 的 relay grant。

guest 必须提交 room code 和 secret。房主批准 pending request 后，guest 才能获得 relay grant。只有 room code 不能加入。

## 功能

- **Agent Workspaces**：多个 coding agents 并排运行，workspace、tab、pane、目录和通知保持可见。
- **Browser Panes**：浏览器和终端并排，agent 可以检查 accessibility tree、点击、填表和操作本地 dev server。
- **Notifications**：支持 terminal notification sequences 和 `coterm notify`。
- **CLI Automation**：用 `coterm` CLI 和本地 socket API 创建 workspace、分屏、发送按键和打开 URL。
- **Ghostty Rendering**：使用 libghostty 渲染终端，并读取 Ghostty 风格的字体、主题和颜色配置。

## 来源关系

Coterm 是基于 Mosaic/cmux 代码谱系的独立开源发行版。它保留终端、workspace、pane、browser、command palette、settings 和 Ghostty integration 基础，同时将产品身份、部署模型和发布渠道改为 Coterm。

Coterm 不是 Mosaic 或 cmux 的官方版本，也不代表这些项目背书。Mosaic/cmux 的名称、logo、域名、托管服务和商标均与 Coterm 分离。

详情见 [ATTRIBUTION.md](./ATTRIBUTION.md)、[docs/coterm-cmux-compat.md](./docs/coterm-cmux-compat.md)、[docs/upstream-cmux-sync.md](./docs/upstream-cmux-sync.md)。

## 从源码构建

```bash
git clone --recursive https://github.com/mana-am/coterm.git
cd coterm
./scripts/setup.sh
./scripts/reload.sh --tag local
```

## 发布前检查

公开发布前请运行：

```bash
./scripts/coterm-release-audit.sh
./scripts/coterm-collaboration-two-app-check.sh
```

release audit 会检查公开仓库/下载链接、自托管默认行为、App 本地化字符串里的 Mosaic 品牌残留，以及 release asset 命名。two-app helper 会构建隔离的 `host-test` 和 `guest-test` DEBUG App，并打印 create、join、房主审批、长 secret 邀请码和 stop sharing 的手工回归清单。

Release 打包还要求使用 `zig 0.15.2` 构建内置 Ghostty CLI helper。不要从 Zig 版本不一致的机器或 CI runner 发布 macOS 安装包。

如果工作区里有个人部署覆盖，例如本地 `wrangler.toml`，正式打 tag 前必须清理；`COTERM_RELEASE_AUDIT_ALLOW_DIRTY=1` 只用于临时探索检查，不用于正式发布。

## 文档

- [自托管协作安装指南](./coterm/instruction.md)
- [自托管后端文档](./coterm/docs/self-hosting.md)
- [客户端配置](./coterm/docs/client-setup.md)
- [预览共享](./coterm/docs/preview-sharing.md)
- [来源与署名](./ATTRIBUTION.md)
- [Coterm/cmux 兼容登记](./docs/coterm-cmux-compat.md)
- [上游 cmux 同步策略](./docs/upstream-cmux-sync.md)
- [仓库结构](./docs/repo-map.md)

## License And Attribution

Coterm 使用 GPL-3.0-or-later 开源协议。见 [LICENSE](./LICENSE)。

上游署名、商标和再分发说明见 [ATTRIBUTION.md](./ATTRIBUTION.md)。
