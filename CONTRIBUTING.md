# Contributing to coterm

## Prerequisites

- macOS 14+
- Xcode 15+
- [Zig](https://ziglang.org/) (install via `brew install zig`)

## Getting Started

1. Clone the repository with submodules:
   ```bash
   git clone --recursive https://github.com/emergent-inc/coterm.git
   cd coterm
   ```

2. Run the setup script:
   ```bash
   ./scripts/setup.sh
   ```

   This will:
   - Initialize git submodules (ghostty, homebrew-coterm)
   - Build the GhosttyKit.xcframework from source
   - Create the necessary symlinks

3. Build the debug app:
   ```bash
   ./scripts/reload.sh --tag my-feature
   ```
   The script prints the `.app` path. Cmd-click to open, or pass `--launch` to open automatically.

## Development Scripts

| Script | Description |
|--------|-------------|
| `./scripts/setup.sh` | One-time setup (submodules + xcframework) |
| `./scripts/reload.sh` | Build Debug app (pass `--launch` to also open it) |
| `./scripts/reloadp.sh` | Build and launch Release app |
| `./scripts/reload2.sh` | Reload both Debug and Release |
| `./scripts/rebuild.sh` | Clean rebuild |

## Upstream cmux updates

Coterm can pull selected fixes from the upstream cmux code line, but it is not a
blind rebrand that can be overwritten by upstream. Product identity,
collaboration protocol, self-hosted backend defaults, bundle IDs, sockets,
domains, update feeds, and release packaging are Coterm-owned boundaries.

Before syncing upstream changes, read [docs/upstream-cmux-sync.md](docs/upstream-cmux-sync.md).

## Team dogfood setup

DEBUG builds can auto-sign-in as you and auto-attach an iOS build to your Mac with no manual steps. Each developer does a one-time setup with their own Stack account.

Run this once:

```bash
scripts/setup-team-dev.sh
```

It prompts for your Stack email and password (the password is never echoed), verifies them against Stack, and writes `~/.secrets/coterm-dev.env` with `chmod 600`. Re-running it is safe; if you are already configured it prints the account and exits. To reset, delete `~/.secrets/coterm-dev.env` and run it again.

After that, every dev build signs you in automatically:

```bash
scripts/dev-setup.sh --tag <your-initials>
```

That builds the tagged macOS DEBUG app auto-signed-in as you, enables the iOS pairing host, mints an attach ticket, and launches the iOS dev build auto-attached to your Mac. Use `--surface mac` for macOS only. See `scripts/dev-setup.sh --help` for all flags.

This is DEBUG-only and per-user. The credentials file lives outside the repo and is never committed; `scripts/coterm-dev.env.example` is the in-repo template. Release builds never read these credentials (the auto-sign-in path is compiled out of release).

## Web and JS Tooling

Run Biome from the repository root with:

```bash
bun run biome:check
```

The root `biome.json` intentionally scopes `biome check .` to maintained web and JS/TS sources.
It excludes generated bundles, build outputs, vendored trees, and review-tool metadata such as
`.greptile/`.
Biome formatting and import sorting are disabled for now; do not wire this into required CI until
the remaining source lint diagnostics are paid down.

## Rebuilding GhosttyKit

If you make changes to the ghostty submodule, rebuild the xcframework:

```bash
cd ghostty
zig build -Demit-xcframework=true -Doptimize=ReleaseFast
```

## Running Tests

### Basic tests (run on VM)

```bash
ssh coterm-vm 'cd /Users/coterm/coterm && xcodebuild -project coterm.xcodeproj -scheme coterm -configuration Debug -destination "platform=macOS" build && pkill -x "Coterm DEV" || true && APP=$(find /Users/coterm/Library/Developer/Xcode/DerivedData -path "*/Build/Products/Debug/Coterm DEV.app" -print -quit) && open "$APP" && for i in {1..20}; do [ -S /tmp/coterm.sock ] && break; sleep 0.5; done && python3 tests/test_update_timing.py && python3 tests/test_signals_auto.py && python3 tests/test_ctrl_socket.py && python3 tests/test_notifications.py'
```

### UI tests (run on VM)

```bash
ssh coterm-vm 'cd /Users/coterm/coterm && xcodebuild -project coterm.xcodeproj -scheme coterm -configuration Debug -destination "platform=macOS" -only-testing:cotermUITests test'
```

## Ghostty Submodule

The `ghostty` submodule points to [emergent-inc/ghostty](https://github.com/emergent-inc/ghostty), a fork of the upstream Ghostty project.

### Making changes to ghostty

```bash
cd ghostty
git checkout -b my-feature
# make changes
git add .
git commit -m "Description of changes"
git push emergent.inc my-feature
```

### Keeping the fork updated

```bash
cd ghostty
git fetch origin
git checkout main
git merge origin/main
git push emergent.inc main
```

Then update the parent repo:

```bash
cd ..
git add ghostty
git commit -m "Update ghostty submodule"
```

See `docs/ghostty-fork.md` for details on fork changes and conflict notes.

## License

By contributing to this repository, you agree that:

1. Your contributions are licensed under the project's GNU General Public License v3.0 or later (`GPL-3.0-or-later`).
2. You grant emergent.inc a perpetual, worldwide, non-exclusive, royalty-free, irrevocable license to use, reproduce, modify, sublicense, and distribute your contributions under any license, including a commercial license offered to third parties.
