import Foundation
import CotermFoundation

nonisolated enum SSHPTYAttachStartupCommandBuilder {
    struct ForegroundAuth {
        let destination: String
        let port: Int?
        let identityFile: String?
        let sshOptions: [String]
        let token: String
    }

    static func command(
        sessionID: String? = nil,
        foregroundAuth: ForegroundAuth? = nil,
        remoteCommand: String? = nil,
        requireExisting: Bool = true
    ) -> String {
        var lines = [
            "coterm_ssh_attach_cli=\"${COTERM_BUNDLED_CLI_PATH:-}\"",
            "if [ -z \"$coterm_ssh_attach_cli\" ] || [ ! -x \"$coterm_ssh_attach_cli\" ]; then coterm_ssh_attach_cli=\"$(command -v coterm 2>/dev/null || true)\"; fi",
            "if [ -z \"$coterm_ssh_attach_cli\" ]; then printf '%s\\n' '[coterm] bundled CLI not found for SSH PTY attach.' >&2; exit 127; fi",
            "if [ -z \"${COTERM_SOCKET_PATH:-}\" ]; then printf '%s\\n' '[coterm] required configuration missing for SSH PTY attach.' >&2; exit 1; fi",
            "if [ -z \"${COTERM_WORKSPACE_ID:-}\" ]; then printf '%s\\n' '[coterm] required workspace context missing for SSH PTY attach.' >&2; exit 1; fi",
        ]
        if let sessionID = normalized(sessionID) {
            lines.append("coterm_ssh_attach_session_id=\(shellQuote(sessionID))")
        } else {
            lines += [
                "if [ -z \"${COTERM_SURFACE_ID:-}\" ]; then printf '%s\\n' '[coterm] required terminal context missing for SSH PTY attach.' >&2; exit 1; fi",
                "coterm_ssh_attach_session_id=\"ssh-$COTERM_WORKSPACE_ID-$COTERM_SURFACE_ID\"",
            ]
        }
        if let foregroundAuth {
            lines += foregroundAuthLines(foregroundAuth)
        }
        let requireExistingFlag = requireExisting ? " --require-existing" : ""
        let commandB64Flag = normalized(remoteCommand).map {
            " --command-b64 \(shellQuote(Data($0.utf8).base64EncodedString()))"
        } ?? ""
        let attachCommand = "\"$coterm_ssh_attach_cli\" --socket \"$COTERM_SOCKET_PATH\" ssh-pty-attach --wait\(requireExistingFlag) --workspace \"$COTERM_WORKSPACE_ID\" --session-id \"$coterm_ssh_attach_session_id\" --attachment-id \"${COTERM_SURFACE_ID:-}\"\(commandB64Flag)"
        lines += retryingAttachLines(command: attachCommand)
        return "/bin/sh -c \(shellQuote(lines.joined(separator: "\n")))"
    }

    static func restoredRemoteShellCommand(relayPort: Int) -> String {
        RemoteInteractiveShellBootstrapBuilder.script(
            remoteRelayPort: relayPort,
            shellFeatures: RemoteInteractiveShellBootstrapBuilder.shellFeatures(),
            bundledZshIntegration: RemoteInteractiveShellBootstrapBuilder.bundledShellIntegrationScript(named: "coterm-zsh-integration.zsh"),
            bundledBashIntegration: RemoteInteractiveShellBootstrapBuilder.bundledShellIntegrationScript(named: "coterm-bash-integration.bash"),
            bundledFishIntegration: RemoteInteractiveShellBootstrapBuilder.bundledShellIntegrationScript(named: "fish/config.fish")
        )
    }

    private static func retryingAttachLines(command: String) -> [String] {
        [
            "coterm_ssh_attach_reconnect_limit=\"${COTERM_SSH_RECONNECT_LIMIT:-20}\"",
            "case \"$coterm_ssh_attach_reconnect_limit\" in ''|*[!0-9]*) coterm_ssh_attach_reconnect_limit=20 ;; esac",
            "coterm_ssh_attach_reconnect_delay=\"${COTERM_SSH_RECONNECT_DELAY_SECONDS:-2}\"",
            "case \"$coterm_ssh_attach_reconnect_delay\" in ''|*[!0-9]*) coterm_ssh_attach_reconnect_delay=2 ;; esac",
            "coterm_ssh_attach_retry=0",
            "while :; do",
            "  \(command)",
            "  coterm_ssh_attach_status=$?",
            "  case \"$coterm_ssh_attach_status\" in 254|255) ;; *) exit \"$coterm_ssh_attach_status\" ;; esac",
            "  if [ \"$coterm_ssh_attach_retry\" -ge \"$coterm_ssh_attach_reconnect_limit\" ]; then exit \"$coterm_ssh_attach_status\"; fi",
            "  coterm_ssh_attach_retry=$((coterm_ssh_attach_retry + 1))",
            "  if [ -t 2 ]; then printf '\\n\\033[33m[coterm] remote PTY bridge closed; reattaching (attempt %s/%s).\\033[0m\\n' \"$coterm_ssh_attach_retry\" \"$coterm_ssh_attach_reconnect_limit\" >&2 || true; fi",
            "  if [ \"$coterm_ssh_attach_reconnect_delay\" -gt 0 ]; then sleep \"$coterm_ssh_attach_reconnect_delay\"; fi",
            "done",
        ]
    }

    private static func foregroundAuthLines(_ auth: ForegroundAuth) -> [String] {
        let sshCommand = sshForegroundAuthCommand(auth)
        let quotedToken = shellQuote(auth.token)
        return [
            "\(sshCommand)",
            "coterm_ssh_auth_status=$?",
            "if [ \"$coterm_ssh_auth_status\" -ne 0 ]; then exit \"$coterm_ssh_auth_status\"; fi",
            "coterm_ssh_auth_token=\(quotedToken)",
            "coterm_ssh_auth_payload=\"{\\\"workspace_id\\\":\\\"$COTERM_WORKSPACE_ID\\\",\\\"foreground_auth_token\\\":\\\"$coterm_ssh_auth_token\\\"}\"",
            "\"$coterm_ssh_attach_cli\" --socket \"$COTERM_SOCKET_PATH\" rpc workspace.remote.foreground_auth_ready \"$coterm_ssh_auth_payload\" >/dev/null 2>&1 || true",
            "unset coterm_ssh_auth_payload coterm_ssh_auth_status coterm_ssh_auth_token",
        ]
    }

    private static func sshForegroundAuthCommand(_ auth: ForegroundAuth) -> String {
        var arguments = ["ssh"]
        let options = sshOptionsWithRestoreControlDefaults(auth.sshOptions)
        if !hasSSHOptionKey(options, key: "ConnectTimeout") {
            arguments += ["-o", "ConnectTimeout=6"]
        }
        if !hasSSHOptionKey(options, key: "ServerAliveInterval") {
            arguments += ["-o", "ServerAliveInterval=20"]
        }
        if !hasSSHOptionKey(options, key: "ServerAliveCountMax") {
            arguments += ["-o", "ServerAliveCountMax=2"]
        }
        if let port = auth.port {
            arguments += ["-p", String(port)]
        }
        if let identityFile = normalized(auth.identityFile) {
            arguments += ["-i", identityFile]
        }
        for option in options {
            arguments += ["-o", option]
        }
        arguments += ["-T", auth.destination, "true"]
        return arguments.map(shellQuote).joined(separator: " ")
    }

    static func sshOptionsWithRestoreControlDefaults(_ options: [String], relayPort: Int? = nil) -> [String] {
        var merged = options.compactMap(normalized)
        let controlMaster = sshOptionValue(named: "ControlMaster", in: merged)
        let controlMasterDisabled = sshOptionValueIsDisabled(controlMaster)
        if controlMaster == nil {
            merged.append("ControlMaster=auto")
        }
        if !controlMasterDisabled {
            if !hasSSHOptionKey(merged, key: "ControlPersist") {
                merged.append("ControlPersist=600")
            }
            if !hasSSHOptionKey(merged, key: "ControlPath") {
                merged.append("ControlPath=\(restoreControlPathTemplate(relayPort: relayPort))")
            }
        }
        return merged
    }

    private static func restoreControlPathTemplate(relayPort: Int?) -> String {
        if let relayPort, relayPort > 0 {
            return "/tmp/coterm-ssh-\(getuid())-\(relayPort)-%C"
        }
        return "/tmp/coterm-ssh-\(getuid())-%C"
    }

    static func sshOptionsSupportReusableForegroundAuth(_ options: [String]) -> Bool {
        guard !hasSSHOptionKey(options, key: "LocalCommand"),
              !hasSSHOptionKey(options, key: "PermitLocalCommand") else {
            return false
        }

        guard let controlPath = sshOptionValue(named: "ControlPath", in: options),
              !controlPath.isEmpty,
              controlPath.lowercased() != "none" else {
            return false
        }

        if sshOptionValueIsDisabled(sshOptionValue(named: "ControlMaster", in: options)) {
            return false
        }

        return !sshOptionValueIsDisabled(
            sshOptionValue(named: "ControlPersist", in: options),
            zeroIsDisabled: false
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func hasSSHOptionKey(_ options: [String], key: String) -> Bool {
        SSHAgentSocketResolver().hasOptionKey(options, key: key)
    }

    private static func sshOptionValue(named name: String, in options: [String]) -> String? {
        SSHAgentSocketResolver().optionValue(named: name, in: options)
    }

    private static func sshOptionValueIsDisabled(_ rawValue: String?, zeroIsDisabled: Bool = true) -> Bool {
        guard let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["no", "false", "off"].contains(normalized) || (zeroIsDisabled && normalized == "0")
    }

    private static func shellQuote(_ value: String) -> String {
        let safePattern = "^[A-Za-z0-9_@%+=:,./-]+$"
        if value.range(of: safePattern, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
