import Foundation

enum RemoteInteractiveShellBootstrapBuilder {
    static func script(
        remoteRelayPort: Int,
        shellFeatures: String,
        terminfoSource: String? = nil,
        bundledZshIntegration: String? = nil,
        bundledBashIntegration: String? = nil,
        bundledFishIntegration: String? = nil
    ) -> String {
        let shellStateDir = shellStateDirForRemoteRelayPort(remoteRelayPort)
        let commonShellExportLines = commonShellLines(
            remoteRelayPort: remoteRelayPort,
            shellStateDir: shellStateDir,
            shellFeatures: shellFeatures,
            terminfoSource: terminfoSource
        )
        var zshShellLines = commonShellExportLines
        zshShellLines.append(
            #"if [ "${COTERM_SHELL_INTEGRATION:-1}" != "0" ] && [ -r "${COTERM_SHELL_INTEGRATION_DIR}/coterm-zsh-integration.zsh" ]; then . "${COTERM_SHELL_INTEGRATION_DIR}/coterm-zsh-integration.zsh"; fi"#
        )
        var bashShellLines = commonShellExportLines
        bashShellLines.append(
            #"if [ "${COTERM_SHELL_INTEGRATION:-1}" != "0" ] && [ -r "${COTERM_SHELL_INTEGRATION_DIR}/coterm-bash-integration.bash" ]; then . "${COTERM_SHELL_INTEGRATION_DIR}/coterm-bash-integration.bash"; fi"#
        )
        let zshBootstrap = RemoteRelayZshBootstrap(shellStateDir: shellStateDir)
        let relayWarmupLines = relayWarmupLines(remoteRelayPort: remoteRelayPort)

        var outerLines: [String] = [
            "mkdir -p \"$HOME/.coterm/relay\"",
            "coterm_shell_dir=\"\(shellStateDir)\"",
            "mkdir -p \"$coterm_shell_dir\"",
        ]
        if let bundledZshIntegration {
            outerLines += [
                "cat > \"$coterm_shell_dir/coterm-zsh-integration.zsh\" <<'COTERMCOTERMZSH'",
                bundledZshIntegration,
                "COTERMCOTERMZSH",
            ]
        }
        if let bundledBashIntegration {
            outerLines += [
                "cat > \"$coterm_shell_dir/coterm-bash-integration.bash\" <<'COTERMCOTERMBASH'",
                bundledBashIntegration,
                "COTERMCOTERMBASH",
            ]
        }
        if let bundledFishIntegration {
            outerLines += [
                "mkdir -p \"$coterm_shell_dir/fish\"",
                "cat > \"$coterm_shell_dir/fish/config.fish\" <<'COTERMCOTERMFISH'",
                bundledFishIntegration,
                "COTERMCOTERMFISH",
            ]
        }
        outerLines.append(contentsOf: commonShellExportLines)
        outerLines += [
            "COTERM_LOGIN_SHELL=\"${SHELL:-/bin/zsh}\"",
            "case \"${COTERM_LOGIN_SHELL##*/}\" in",
            "  zsh)",
            "    cat > \"$coterm_shell_dir/.zshenv\" <<'COTERMZSHENV'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshEnvLines)
        outerLines += [
            "COTERMZSHENV",
            "    cat > \"$coterm_shell_dir/.zprofile\" <<'COTERMZSHPROFILE'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshProfileLines)
        outerLines += [
            "COTERMZSHPROFILE",
            "    cat > \"$coterm_shell_dir/.zshrc\" <<'COTERMZSHRC'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshRCLines(commonShellLines: zshShellLines))
        outerLines += [
            "COTERMZSHRC",
            "    cat > \"$coterm_shell_dir/.zlogin\" <<'COTERMZSHLOGIN'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshLoginLines)
        outerLines += [
            "COTERMZSHLOGIN",
            "    chmod 600 \"$coterm_shell_dir/.zshenv\" \"$coterm_shell_dir/.zprofile\" \"$coterm_shell_dir/.zshrc\" \"$coterm_shell_dir/.zlogin\" >/dev/null 2>&1 || true",
        ]
        outerLines.append(contentsOf: relayWarmupLines.map { "    " + $0 })
        outerLines += [
            "    export COTERM_REAL_ZDOTDIR=\"${ZDOTDIR:-$HOME}\"",
            "    export ZDOTDIR=\"$coterm_shell_dir\"",
            "    exec \"$COTERM_LOGIN_SHELL\" -il",
            "    ;;",
            "  bash)",
            "    cat > \"$coterm_shell_dir/.bashrc\" <<'COTERMBASHRC'",
        ]
        outerLines.append(contentsOf: [
            "if [ -f \"$HOME/.bash_profile\" ]; then",
            "  . \"$HOME/.bash_profile\"",
            "elif [ -f \"$HOME/.bash_login\" ]; then",
            "  . \"$HOME/.bash_login\"",
            "elif [ -f \"$HOME/.profile\" ]; then",
            "  . \"$HOME/.profile\"",
            "fi",
            "[ -f \"$HOME/.bashrc\" ] && . \"$HOME/.bashrc\"",
        ] + bashShellLines)
        outerLines += [
            "COTERMBASHRC",
            "    chmod 600 \"$coterm_shell_dir/.bashrc\" >/dev/null 2>&1 || true",
        ]
        outerLines.append(contentsOf: relayWarmupLines.map { "    " + $0 })
        outerLines += [
            "    exec \"$COTERM_LOGIN_SHELL\" --rcfile \"$coterm_shell_dir/.bashrc\" -i",
            "    ;;",
            "  fish)",
        ]
        outerLines.append(contentsOf: relayWarmupLines.map { "    " + $0 })
        outerLines += [
            "    export COTERM_FISH_INTEGRATION_FILE=\"$coterm_shell_dir/fish/config.fish\"",
            "    export COTERM_FISH_USER_CONFIG_ALREADY_LOADED=1",
            "    exec \"$COTERM_LOGIN_SHELL\" -il --init-command 'source \"$COTERM_FISH_INTEGRATION_FILE\"'",
            "    ;;",
            "  *)",
        ]
        outerLines.append(contentsOf: relayWarmupLines)
        outerLines += [
            "exec \"$COTERM_LOGIN_SHELL\" -i",
            ";;",
            "esac",
        ]

        return outerLines.joined(separator: "\n")
    }

    static func shellFeatures(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let rawExisting = environment["GHOSTTY_SHELL_FEATURES"] ?? ""
        var seen: Set<String> = []
        var merged: [String] = []

        for token in rawExisting.split(separator: ",") {
            let feature = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !feature.isEmpty else { continue }
            if seen.insert(feature).inserted {
                merged.append(feature)
            }
        }

        for required in ["ssh-env", "ssh-terminfo"] {
            if seen.insert(required).inserted {
                merged.append(required)
            }
        }

        return merged.joined(separator: ",")
    }

    static func bundledShellIntegrationScript(
        named fileName: String,
        bundleResourceURL: URL? = Bundle.main.resourceURL,
        fileManager: FileManager = .default
    ) -> String? {
        guard let bundleResourceURL else { return nil }
        let url = bundleResourceURL
            .appendingPathComponent("shell-integration", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8) else {
            return nil
        }
        return contents
    }

    private static func commonShellLines(
        remoteRelayPort: Int,
        shellStateDir: String,
        shellFeatures: String,
        terminfoSource: String?
    ) -> [String] {
        let relaySocket = remoteRelayPort > 0 ? "127.0.0.1:\(remoteRelayPort)" : nil
        var lines = terminalSetupLines(terminfoSource: terminfoSource)
        lines.append(contentsOf: RemoteShellEnvironment.utf8LocaleSetupLines())
        lines.append(contentsOf: shellExportLines(shellFeatures: shellFeatures))
        lines.append("export PATH=\"$HOME/.coterm/bin:$PATH\"")
        lines.append("export COTERM_BUNDLED_CLI_PATH=\"$HOME/.coterm/bin/coterm\"")
        lines.append("export COTERM_SHELL_INTEGRATION_DIR=\"\(shellStateDir)\"")
        if let relaySocket {
            lines.append("export COTERM_SOCKET_PATH=\(relaySocket)")
        }
        // The assignment placeholders are replaced by `ssh-pty-attach` before
        // this script runs. Split the sentinel patterns so a missed replacement
        // does not export literal placeholder IDs into the remote shell.
        lines.append(contentsOf: [
            "coterm_workspace_id='__COTERM_WORKSPACE_ID__'",
            "case \"$coterm_workspace_id\" in \"\"|'__COTERM_''WORKSPACE_ID__') ;; *) export COTERM_WORKSPACE_ID=\"$coterm_workspace_id\"; export COTERM_TAB_ID=\"$coterm_workspace_id\" ;; esac",
            "coterm_surface_id='__COTERM_SURFACE_ID__'",
            "case \"$coterm_surface_id\" in \"\"|'__COTERM_''SURFACE_ID__') ;; *) export COTERM_SURFACE_ID=\"$coterm_surface_id\"; export COTERM_PANEL_ID=\"$coterm_surface_id\" ;; esac",
            "unset coterm_workspace_id coterm_surface_id",
            "hash -r >/dev/null 2>&1 || true",
            "rehash >/dev/null 2>&1 || true",
        ])
        return lines
    }

    static func terminalSetupLines(terminfoSource: String?) -> [String] {
        let trimmedTerminfoSource = terminfoSource?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedTerminfoSource, !trimmedTerminfoSource.isEmpty else {
            // Without a bundled terminfo to install we can only probe what the
            // remote already has and fall back to a universally-present entry.
            return [
                "coterm_term='xterm-256color'",
                "if command -v infocmp >/dev/null 2>&1 && infocmp xterm-ghostty >/dev/null 2>&1; then",
                "  coterm_term='xterm-ghostty'",
                "fi",
                "export TERM=\"$coterm_term\"",
            ]
        }
        // Install the bundled xterm-ghostty terminfo *synchronously*, before
        // deciding TERM, so a full-screen TUI (e.g. Claude Code) never starts
        // against a TERM whose terminfo entry is missing or half-written.
        //
        // The previous design deferred `tic` to a background job and decided
        // TERM up front, so the first shell on a host without the entry got
        // xterm-256color while a later pass could select xterm-ghostty mid-write
        // and garble output (#6352). Here we compile into a private temp
        // directory on the same filesystem as ~/.terminfo, then move each
        // compiled entry into place with an atomic rename, so a concurrent reader
        // in another coterm ssh session sharing $HOME never observes a partially
        // written database. The temp directory comes from `mktemp` when present,
        // otherwise a per-process `$$` directory (unique among live processes) so
        // the atomic-rename path applies even without `mktemp` — no branch ever
        // compiles terminfo directly into ~/.terminfo.
        return [
            "coterm_term='xterm-256color'",
            "if command -v infocmp >/dev/null 2>&1 && infocmp xterm-ghostty >/dev/null 2>&1; then",
            "  coterm_term='xterm-ghostty'",
            "elif command -v tic >/dev/null 2>&1; then",
            "  mkdir -p \"$HOME/.terminfo\" 2>/dev/null",
            "  coterm_ti_tmp=$(mktemp -d \"$HOME/.terminfo.coterm.XXXXXX\" 2>/dev/null) || coterm_ti_tmp=''",
            "  if [ -z \"$coterm_ti_tmp\" ]; then",
            "    coterm_ti_tmp=\"$HOME/.terminfo.coterm.$$\"",
            "    rm -rf \"$coterm_ti_tmp\" 2>/dev/null",
            "    mkdir \"$coterm_ti_tmp\" 2>/dev/null || coterm_ti_tmp=''",
            "  fi",
            "  {",
            "    cat <<'COTERMINFO'",
            trimmedTerminfoSource,
            "COTERMINFO",
            "  } | {",
            "    if [ -n \"$coterm_ti_tmp\" ] && tic -x -o \"$coterm_ti_tmp\" - >/dev/null 2>&1; then",
            "      find \"$coterm_ti_tmp\" -type f 2>/dev/null | while IFS= read -r coterm_ti_file; do",
            "        coterm_ti_rel=${coterm_ti_file#\"$coterm_ti_tmp\"/}",
            "        coterm_ti_dest=\"$HOME/.terminfo/$coterm_ti_rel\"",
            "        mkdir -p \"$(dirname \"$coterm_ti_dest\")\" 2>/dev/null",
            "        mv -f \"$coterm_ti_file\" \"$coterm_ti_dest\" 2>/dev/null || cp -f \"$coterm_ti_file\" \"$coterm_ti_dest\" 2>/dev/null",
            "      done",
            "    fi",
            "  }",
            "  [ -n \"$coterm_ti_tmp\" ] && rm -rf \"$coterm_ti_tmp\" 2>/dev/null",
            "  if infocmp xterm-ghostty >/dev/null 2>&1; then",
            "    coterm_term='xterm-ghostty'",
            "  fi",
            "  unset coterm_ti_tmp coterm_ti_file coterm_ti_rel coterm_ti_dest 2>/dev/null || true",
            "fi",
            "export TERM=\"$coterm_term\"",
        ]
    }

    private static func shellExportLines(shellFeatures: String) -> [String] {
        let environment = ProcessInfo.processInfo.environment
        let colorTerm = normalizedEnvValue(environment["COLORTERM"]) ?? "truecolor"
        let termProgram = normalizedEnvValue(environment["TERM_PROGRAM"]) ?? "ghostty"
        let termProgramVersion = normalizedEnvValue(environment["TERM_PROGRAM_VERSION"])
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? ""
        let trimmedShellFeatures = shellFeatures.trimmingCharacters(in: .whitespacesAndNewlines)

        var exports: [String] = [
            "export COLORTERM=\(shellQuote(colorTerm))",
            "export TERM_PROGRAM=\(shellQuote(termProgram))",
        ]
        if !termProgramVersion.isEmpty {
            exports.append("export TERM_PROGRAM_VERSION=\(shellQuote(termProgramVersion))")
        }
        if !trimmedShellFeatures.isEmpty {
            exports.append("export GHOSTTY_SHELL_FEATURES=\(shellQuote(trimmedShellFeatures))")
        }
        return exports
    }

    private static func relayWarmupLines(remoteRelayPort: Int) -> [String] {
        guard remoteRelayPort > 0 else {
            return []
        }
        return [
            "coterm_relay_cli=\"${COTERM_BUNDLED_CLI_PATH:-$HOME/.coterm/bin/coterm}\"",
            "if [ ! -x \"$coterm_relay_cli\" ]; then coterm_relay_cli=\"$(command -v coterm 2>/dev/null || true)\"; fi",
            "coterm_relay_tty=\"${COTERM_BOOTSTRAP_TTY:-}\"",
            "if [ -z \"$coterm_relay_tty\" ]; then coterm_relay_tty=\"$(tty 2>/dev/null || true)\"; fi",
            "coterm_relay_tty=\"${coterm_relay_tty##*/}\"",
            "if [ -n \"$coterm_relay_tty\" ] && [ \"$coterm_relay_tty\" != \"not a tty\" ]; then",
            "  mkdir -p \"$HOME/.coterm/relay\" >/dev/null 2>&1 || true",
            "  printf '%s' \"$coterm_relay_tty\" > \"$HOME/.coterm/relay/\(remoteRelayPort).tty\" 2>/dev/null || true",
            "fi",
            "if [ -n \"$coterm_relay_cli\" ] && [ -n \"$COTERM_WORKSPACE_ID\" ] && [ -n \"$coterm_relay_tty\" ] && [ \"$coterm_relay_tty\" != \"not a tty\" ]; then",
            "  (",
            "    coterm_relay_report_tty=\"{\\\"workspace_id\\\":\\\"$COTERM_WORKSPACE_ID\\\",\\\"tty_name\\\":\\\"$coterm_relay_tty\\\"}\"",
            "    coterm_relay_ports_kick=\"{\\\"workspace_id\\\":\\\"$COTERM_WORKSPACE_ID\\\",\\\"reason\\\":\\\"command\\\"}\"",
            "    if [ -n \"$COTERM_SURFACE_ID\" ]; then",
            "      coterm_relay_report_tty=\"{\\\"workspace_id\\\":\\\"$COTERM_WORKSPACE_ID\\\",\\\"surface_id\\\":\\\"$COTERM_SURFACE_ID\\\",\\\"tty_name\\\":\\\"$coterm_relay_tty\\\"}\"",
            "      coterm_relay_ports_kick=\"{\\\"workspace_id\\\":\\\"$COTERM_WORKSPACE_ID\\\",\\\"surface_id\\\":\\\"$COTERM_SURFACE_ID\\\",\\\"reason\\\":\\\"command\\\"}\"",
            "    fi",
            "    \"$coterm_relay_cli\" rpc surface.report_tty \"$coterm_relay_report_tty\" >/dev/null 2>&1 || true",
            "    \"$coterm_relay_cli\" rpc surface.ports_kick \"$coterm_relay_ports_kick\" >/dev/null 2>&1 || true",
            "  ) </dev/null >/dev/null 2>&1 &",
            "fi",
            "unset COTERM_BOOTSTRAP_TTY coterm_relay_cli coterm_relay_tty coterm_relay_report_tty coterm_relay_ports_kick",
        ]
    }

    private static func shellStateDirForRemoteRelayPort(_ remoteRelayPort: Int) -> String {
        "$HOME/.coterm/relay/\(max(remoteRelayPort, 0)).shell"
    }

    private static func normalizedEnvValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func shellQuote(_ value: String) -> String {
        let safePattern = "^[A-Za-z0-9_@%+=:,./-]+$"
        if value.range(of: safePattern, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
