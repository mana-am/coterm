#!/usr/bin/env python3
"""
Regression for issue #2448:
shell integrations should dispatch `claude` through coterm's wrapper even when
GHOSTTY_BIN_DIR is unset and PATH later prefers another binary.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHELL_DIR = ROOT / "Resources" / "shell-integration"


def write_executable(path: Path, contents: str) -> None:
    path.write_text(contents, encoding="utf-8")
    path.chmod(0o755)


def read_lines(path: Path) -> list[str]:
    if not path.exists():
        return []
    return [line.rstrip("\n") for line in path.read_text(encoding="utf-8").splitlines()]


def prepare_bundle(tmp: Path) -> tuple[Path, Path]:
    shell_dir = tmp / "bundle" / "Resources" / "shell-integration"
    bin_dir = tmp / "bundle" / "Resources" / "bin"
    shell_dir.mkdir(parents=True, exist_ok=True)
    bin_dir.mkdir(parents=True, exist_ok=True)

    for name in (".zshenv", ".zprofile", ".zshrc", "coterm-zsh-integration.zsh", "coterm-bash-integration.bash"):
        shutil.copy2(SOURCE_SHELL_DIR / name, shell_dir / name)
    (shell_dir / "fish").mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE_SHELL_DIR / "fish" / "config.fish", shell_dir / "fish" / "config.fish")

    return shell_dir, bin_dir


def run_zsh(shell_dir: Path, real_bin: Path, log_path: Path) -> tuple[int, str, list[str]]:
    home = shell_dir.parent.parent.parent / "home"
    orig = shell_dir.parent.parent.parent / "orig-zdotdir"
    home.mkdir(parents=True, exist_ok=True)
    orig.mkdir(parents=True, exist_ok=True)

    for filename in (".zshenv", ".zprofile", ".zshrc"):
        (orig / filename).write_text("", encoding="utf-8")

    env = dict(os.environ)
    env["HOME"] = str(home)
    env["ZDOTDIR"] = str(shell_dir)
    env["COTERM_ZSH_ZDOTDIR"] = str(orig)
    env["COTERM_SHELL_INTEGRATION"] = "1"
    env["COTERM_SHELL_INTEGRATION_DIR"] = str(shell_dir)
    env["COTERM_LOAD_GHOSTTY_ZSH_INTEGRATION"] = "0"
    env["COTERM_TEST_LOG"] = str(log_path)
    env["COTERM_TEST_REAL_BIN"] = str(real_bin)
    env["PATH"] = f"{real_bin}:/usr/bin:/bin"
    env.pop("GHOSTTY_BIN_DIR", None)

    result = subprocess.run(
        ["zsh", "-d", "-i", "-c", 'PATH="$COTERM_TEST_REAL_BIN:$PATH"; claude zsh-case'],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    combined = ((result.stdout or "") + (result.stderr or "")).strip()
    return result.returncode, combined, read_lines(log_path)


def run_zsh_with_alias(shell_dir: Path, real_bin: Path, log_path: Path) -> tuple[int, str, list[str]]:
    env = dict(os.environ)
    env["COTERM_SHELL_INTEGRATION_DIR"] = str(shell_dir)
    env["COTERM_TEST_LOG"] = str(log_path)
    env["COTERM_TEST_REAL_BIN"] = str(real_bin)
    env["PATH"] = f"{real_bin}:/usr/bin:/bin"
    env.pop("GHOSTTY_BIN_DIR", None)

    result = subprocess.run(
        [
            "zsh",
            "-fic",
            f'alias claude="echo alias"; source "{shell_dir / "coterm-zsh-integration.zsh"}"; '
            'PATH="$COTERM_TEST_REAL_BIN:$PATH"; claude zsh-alias-case',
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    combined = ((result.stdout or "") + (result.stderr or "")).strip()
    return result.returncode, combined, read_lines(log_path)


def run_zsh_with_late_user_function(shell_dir: Path, real_bin: Path, log_path: Path) -> tuple[int, str, list[str]]:
    env = dict(os.environ)
    env["COTERM_SHELL_INTEGRATION_DIR"] = str(shell_dir)
    env["COTERM_TEST_LOG"] = str(log_path)
    env["COTERM_TEST_REAL_BIN"] = str(real_bin)
    env["PATH"] = f"{real_bin}:/usr/bin:/bin"
    env.pop("GHOSTTY_BIN_DIR", None)

    result = subprocess.run(
        [
            "zsh",
            "-fic",
            f'source "{shell_dir / "coterm-zsh-integration.zsh"}"; '
            'claude() { "$COTERM_TEST_REAL_BIN/user-claude-function" "$@"; }; '
            '_coterm_fix_path; PATH="$COTERM_TEST_REAL_BIN:$PATH"; claude zsh-late-function-case',
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    combined = ((result.stdout or "") + (result.stderr or "")).strip()
    return result.returncode, combined, read_lines(log_path)


def run_bash(shell_dir: Path, real_bin: Path, log_path: Path) -> tuple[int, str, list[str]]:
    env = dict(os.environ)
    env["COTERM_SHELL_INTEGRATION_DIR"] = str(shell_dir)
    env["COTERM_TEST_LOG"] = str(log_path)
    env["COTERM_TEST_REAL_BIN"] = str(real_bin)
    env["PATH"] = f"{real_bin}:/usr/bin:/bin"
    env.pop("GHOSTTY_BIN_DIR", None)

    result = subprocess.run(
        [
            "bash",
            "--noprofile",
            "--norc",
            "-c",
            f'source "{shell_dir / "coterm-bash-integration.bash"}"; PATH="$COTERM_TEST_REAL_BIN:$PATH"; claude bash-case',
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    combined = ((result.stdout or "") + (result.stderr or "")).strip()
    return result.returncode, combined, read_lines(log_path)


def run_bash_with_alias(shell_dir: Path, real_bin: Path, log_path: Path) -> tuple[int, str, list[str]]:
    env = dict(os.environ)
    env["COTERM_SHELL_INTEGRATION_DIR"] = str(shell_dir)
    env["COTERM_TEST_LOG"] = str(log_path)
    env["COTERM_TEST_REAL_BIN"] = str(real_bin)
    env["PATH"] = f"{real_bin}:/usr/bin:/bin"
    env.pop("GHOSTTY_BIN_DIR", None)

    result = subprocess.run(
        [
            "bash",
            "--noprofile",
            "--norc",
            "-ic",
            f'alias claude="$COTERM_TEST_REAL_BIN/user-claude"\n'
            f'source "{shell_dir / "coterm-bash-integration.bash"}"\n'
            'PATH="$COTERM_TEST_REAL_BIN:$PATH"; claude bash-alias-case',
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    combined = ((result.stdout or "") + (result.stderr or "")).strip()
    return result.returncode, combined, read_lines(log_path)


def run_bash_with_function(shell_dir: Path, real_bin: Path, log_path: Path) -> tuple[int, str, list[str]]:
    env = dict(os.environ)
    env["COTERM_SHELL_INTEGRATION_DIR"] = str(shell_dir)
    env["COTERM_TEST_LOG"] = str(log_path)
    env["COTERM_TEST_REAL_BIN"] = str(real_bin)
    env["PATH"] = f"{real_bin}:/usr/bin:/bin"
    env.pop("GHOSTTY_BIN_DIR", None)

    result = subprocess.run(
        [
            "bash",
            "--noprofile",
            "--norc",
            "-ic",
            f'claude() {{ "$COTERM_TEST_REAL_BIN/user-claude-function" "$@"; }}; '
            f'source "{shell_dir / "coterm-bash-integration.bash"}"; '
            'PATH="$COTERM_TEST_REAL_BIN:$PATH"; claude bash-function-case',
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    combined = ((result.stdout or "") + (result.stderr or "")).strip()
    return result.returncode, combined, read_lines(log_path)


def run_zsh_with_stale_original_wrapper(
    shell_dir: Path,
    real_bin: Path,
    old_wrapper: Path,
    current_cli: Path,
    log_path: Path,
) -> tuple[int, str, list[str]]:
    env = dict(os.environ)
    env["COTERM_SHELL_INTEGRATION_DIR"] = str(shell_dir)
    env["COTERM_TEST_LOG"] = str(log_path)
    env["COTERM_TEST_REAL_BIN"] = str(real_bin)
    env["COTERM_TEST_OLD_WRAPPER"] = str(old_wrapper)
    env["COTERM_BUNDLED_CLI_PATH"] = str(current_cli)
    env["PATH"] = f"{real_bin}:/usr/bin:/bin"
    env.pop("GHOSTTY_BIN_DIR", None)

    result = subprocess.run(
        [
            "zsh",
            "-fic",
            f'source "{shell_dir / "coterm-zsh-integration.zsh"}"; '
            'rm -f "$COTERM_TEST_OLD_WRAPPER"; '
            'PATH="$COTERM_TEST_REAL_BIN:$PATH"; claude zsh-stale-wrapper-case',
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    combined = ((result.stdout or "") + (result.stderr or "")).strip()
    return result.returncode, combined, read_lines(log_path)


def run_bash_with_stale_original_wrapper(
    shell_dir: Path,
    real_bin: Path,
    old_wrapper: Path,
    current_cli: Path,
    log_path: Path,
) -> tuple[int, str, list[str]]:
    env = dict(os.environ)
    env["COTERM_SHELL_INTEGRATION_DIR"] = str(shell_dir)
    env["COTERM_TEST_LOG"] = str(log_path)
    env["COTERM_TEST_REAL_BIN"] = str(real_bin)
    env["COTERM_TEST_OLD_WRAPPER"] = str(old_wrapper)
    env["COTERM_BUNDLED_CLI_PATH"] = str(current_cli)
    env["PATH"] = f"{real_bin}:/usr/bin:/bin"
    env.pop("GHOSTTY_BIN_DIR", None)

    result = subprocess.run(
        [
            "bash",
            "--noprofile",
            "--norc",
            "-c",
            f'source "{shell_dir / "coterm-bash-integration.bash"}"; '
            'rm -f "$COTERM_TEST_OLD_WRAPPER"; '
            'PATH="$COTERM_TEST_REAL_BIN:$PATH"; claude bash-stale-wrapper-case',
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    combined = ((result.stdout or "") + (result.stderr or "")).strip()
    return result.returncode, combined, read_lines(log_path)


def run_fish_with_stale_original_wrapper(
    shell_dir: Path,
    real_bin: Path,
    old_wrapper: Path,
    current_cli: Path,
    log_path: Path,
) -> tuple[int, str, list[str]]:
    fish = shutil.which("fish")
    if fish is None:
        return 0, "fish not installed; skipped", ["skip:fish-not-installed"]

    env = dict(os.environ)
    env["COTERM_SHELL_INTEGRATION_DIR"] = str(shell_dir)
    env["COTERM_TEST_LOG"] = str(log_path)
    env["COTERM_TEST_REAL_BIN"] = str(real_bin)
    env["COTERM_TEST_OLD_WRAPPER"] = str(old_wrapper)
    env["COTERM_BUNDLED_CLI_PATH"] = str(current_cli)
    env["PATH"] = f"{real_bin}:/usr/bin:/bin"
    env.pop("GHOSTTY_BIN_DIR", None)

    result = subprocess.run(
        [
            fish,
            "--no-config",
            "-c",
            f'source "{shell_dir / "fish" / "config.fish"}"; '
            'rm -f "$COTERM_TEST_OLD_WRAPPER"; '
            'set -gx PATH "$COTERM_TEST_REAL_BIN" $PATH; claude fish-stale-wrapper-case',
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    combined = ((result.stdout or "") + (result.stderr or "")).strip()
    return result.returncode, combined, read_lines(log_path)


def main() -> int:
    failures: list[str] = []

    with tempfile.TemporaryDirectory(prefix="coterm-issue-2448-") as td:
        tmp = Path(td)
        shell_dir, bundle_bin = prepare_bundle(tmp)
        real_bin = tmp / "real-bin"
        real_bin.mkdir(parents=True, exist_ok=True)
        current_bin = tmp / "current-bin"
        current_bin.mkdir(parents=True, exist_ok=True)

        write_executable(
            bundle_bin / "coterm-claude-wrapper",
            """#!/bin/sh
set -eu
printf 'wrapper:%s\n' "$*" >> "$COTERM_TEST_LOG"
""",
        )
        write_executable(
            real_bin / "claude",
            """#!/bin/sh
set -eu
printf 'real:%s\n' "$*" >> "$COTERM_TEST_LOG"
""",
        )
        write_executable(
            real_bin / "user-claude",
            """#!/bin/sh
set -eu
printf 'user-alias:%s\n' "$*" >> "$COTERM_TEST_LOG"
""",
        )
        write_executable(
            real_bin / "user-claude-function",
            """#!/bin/sh
set -eu
printf 'user-function:%s\n' "$*" >> "$COTERM_TEST_LOG"
""",
        )
        write_executable(
            current_bin / "coterm",
            """#!/bin/sh
set -eu
printf 'coterm-cli:%s\n' "$*" >> "$COTERM_TEST_LOG"
""",
        )
        write_executable(
            current_bin / "coterm-claude-wrapper",
            """#!/bin/sh
set -eu
printf 'current-wrapper:%s\n' "$*" >> "$COTERM_TEST_LOG"
""",
        )

        zsh_log = tmp / "zsh.log"
        rc, output, lines = run_zsh(shell_dir, real_bin, zsh_log)
        if rc != 0:
            failures.append(f"zsh exited non-zero rc={rc}: {output}")
        elif lines != ["wrapper:zsh-case"]:
            failures.append(f"zsh expected wrapper dispatch, saw {lines!r}")

        bash_log = tmp / "bash.log"
        rc, output, lines = run_bash(shell_dir, real_bin, bash_log)
        if rc != 0:
            failures.append(f"bash exited non-zero rc={rc}: {output}")
        elif lines != ["wrapper:bash-case"]:
            failures.append(f"bash expected wrapper dispatch, saw {lines!r}")

        zsh_alias_log = tmp / "zsh-alias.log"
        rc, output, lines = run_zsh_with_alias(shell_dir, real_bin, zsh_alias_log)
        if rc != 0:
            failures.append(f"zsh alias case exited non-zero rc={rc}: {output}")
        elif lines != ["wrapper:zsh-alias-case"]:
            failures.append(f"zsh alias case expected wrapper dispatch, saw {lines!r}")

        zsh_late_function_log = tmp / "zsh-late-function.log"
        rc, output, lines = run_zsh_with_late_user_function(shell_dir, real_bin, zsh_late_function_log)
        if rc != 0:
            failures.append(f"zsh late function case exited non-zero rc={rc}: {output}")
        elif lines != ["wrapper:zsh-late-function-case"]:
            failures.append(f"zsh late function case expected wrapper dispatch, saw {lines!r}")

        bash_alias_log = tmp / "bash-alias.log"
        rc, output, lines = run_bash_with_alias(shell_dir, real_bin, bash_alias_log)
        if rc != 0:
            failures.append(f"bash alias case exited non-zero rc={rc}: {output}")
        elif lines != ["user-alias:bash-alias-case"]:
            failures.append(f"bash alias case should preserve user alias, saw {lines!r}")

        bash_function_log = tmp / "bash-function.log"
        rc, output, lines = run_bash_with_function(shell_dir, real_bin, bash_function_log)
        if rc != 0:
            failures.append(f"bash function case exited non-zero rc={rc}: {output}")
        elif lines != ["user-function:bash-function-case"]:
            failures.append(f"bash function case should preserve user function, saw {lines!r}")

        write_executable(
            bundle_bin / "coterm-claude-wrapper",
            """#!/bin/sh
set -eu
printf 'wrapper:%s\n' "$*" >> "$COTERM_TEST_LOG"
""",
        )
        zsh_stale_wrapper_log = tmp / "zsh-stale-wrapper.log"
        rc, output, lines = run_zsh_with_stale_original_wrapper(
            shell_dir,
            real_bin,
            bundle_bin / "coterm-claude-wrapper",
            current_bin / "coterm",
            zsh_stale_wrapper_log,
        )
        if rc != 0:
            failures.append(f"zsh stale wrapper case exited non-zero rc={rc}: {output}")
        elif lines != ["current-wrapper:zsh-stale-wrapper-case"]:
            failures.append(f"zsh stale wrapper case expected current wrapper dispatch, saw {lines!r}")

        write_executable(
            bundle_bin / "coterm-claude-wrapper",
            """#!/bin/sh
set -eu
printf 'wrapper:%s\n' "$*" >> "$COTERM_TEST_LOG"
""",
        )
        bash_stale_wrapper_log = tmp / "bash-stale-wrapper.log"
        rc, output, lines = run_bash_with_stale_original_wrapper(
            shell_dir,
            real_bin,
            bundle_bin / "coterm-claude-wrapper",
            current_bin / "coterm",
            bash_stale_wrapper_log,
        )
        if rc != 0:
            failures.append(f"bash stale wrapper case exited non-zero rc={rc}: {output}")
        elif lines != ["current-wrapper:bash-stale-wrapper-case"]:
            failures.append(f"bash stale wrapper case expected current wrapper dispatch, saw {lines!r}")

        write_executable(
            bundle_bin / "coterm-claude-wrapper",
            """#!/bin/sh
set -eu
printf 'wrapper:%s\n' "$*" >> "$COTERM_TEST_LOG"
""",
        )
        fish_stale_wrapper_log = tmp / "fish-stale-wrapper.log"
        rc, output, lines = run_fish_with_stale_original_wrapper(
            shell_dir,
            real_bin,
            bundle_bin / "coterm-claude-wrapper",
            current_bin / "coterm",
            fish_stale_wrapper_log,
        )
        if lines == ["skip:fish-not-installed"]:
            print("SKIP: fish is not installed; fish stale-wrapper dispatch was not exercised")
        elif rc != 0:
            failures.append(f"fish stale wrapper case exited non-zero rc={rc}: {output}")
        elif lines != ["current-wrapper:fish-stale-wrapper-case"]:
            failures.append(f"fish stale wrapper case expected current wrapper dispatch, saw {lines!r}")

    if failures:
        print("FAIL: shell integration did not keep claude on the coterm wrapper")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("PASS: zsh, bash, and fish integrations dispatch claude through the coterm wrapper")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
