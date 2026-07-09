import Foundation

extension DockSplitStore {
    static func resolvedWorkingDirectory(_ cwd: String?, baseDirectory: String) -> String {
        guard let cwd, !cwd.isEmpty else { return baseDirectory }
        if cwd.hasPrefix("/") {
            return cwd
        }
        return (baseDirectory as NSString).appendingPathComponent(cwd)
    }

    static func shellStartupScript(command: String, workingDirectory: String) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent(
            "coterm-dock-control-\(UUID().uuidString.lowercased()).sh"
        )
        let encodedCommand = Data(command.utf8).base64EncodedString()
        let encodedWorkingDirectory = Data(workingDirectory.utf8).base64EncodedString()
        let body = """
        #!/bin/sh
        coterm_dock_decode() { printf '%s' "$1" | base64 --decode 2>/dev/null || printf '%s' "$1" | base64 -D 2>/dev/null; }
        coterm_dock_login_shell() {
          coterm_dock_user="$(id -un 2>/dev/null || printf '%s' "${USER:-}")"
          coterm_dock_ds_shell="$(dscl . -read "/Users/$coterm_dock_user" UserShell 2>/dev/null | awk '{print $2; exit}')"
          if [ -n "$coterm_dock_ds_shell" ] && [ -x "$coterm_dock_ds_shell" ]; then printf '%s\\n' "$coterm_dock_ds_shell"
          elif [ -n "${SHELL:-}" ] && [ -x "${SHELL:-}" ]; then printf '%s\\n' "$SHELL"
          else printf '%s\\n' /bin/sh; fi
        }
        coterm_dock_command="$(coterm_dock_decode '\(encodedCommand)')"
        coterm_dock_working_directory="$(coterm_dock_decode '\(encodedWorkingDirectory)')"
        coterm_dock_shell="$(coterm_dock_login_shell)"
        coterm_dock_bundle_bin=""
        if [ -n "${COTERM_BUNDLED_CLI_PATH:-}" ]; then coterm_dock_bundle_bin="$(dirname "$COTERM_BUNDLED_CLI_PATH")"; fi
        export SHELL="$coterm_dock_shell"
        rm -f -- "$0" 2>/dev/null || true
        case "$(basename "$coterm_dock_shell")" in
          fish)
            COTERM_DOCK_BUNDLE_BIN="$coterm_dock_bundle_bin" COTERM_DOCK_START_COMMAND="$coterm_dock_command" COTERM_DOCK_START_DIRECTORY="$coterm_dock_working_directory" "$coterm_dock_shell" -l -c 'if test -n "$COTERM_DOCK_BUNDLE_BIN"; and not contains -- "$COTERM_DOCK_BUNDLE_BIN" $PATH; set -gx PATH "$COTERM_DOCK_BUNDLE_BIN" $PATH; end; if test -n "$COTERM_DOCK_START_DIRECTORY"; cd "$COTERM_DOCK_START_DIRECTORY"; end; eval "$COTERM_DOCK_START_COMMAND"'
            ;;
          *) COTERM_DOCK_BUNDLE_BIN="$coterm_dock_bundle_bin" COTERM_DOCK_START_COMMAND="$coterm_dock_command" COTERM_DOCK_START_DIRECTORY="$coterm_dock_working_directory" "$coterm_dock_shell" -lc 'if [ -n "${COTERM_DOCK_BUNDLE_BIN:-}" ]; then case ":${PATH:-}:" in *":$COTERM_DOCK_BUNDLE_BIN:"*) ;; *) PATH="$COTERM_DOCK_BUNDLE_BIN${PATH:+:$PATH}"; export PATH ;; esac; fi; cd "$COTERM_DOCK_START_DIRECTORY" 2>/dev/null || true; eval "$COTERM_DOCK_START_COMMAND"'
            ;;
        esac
        printf '\\n'
        exec "$coterm_dock_shell" -l
        """
        do {
            try body.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            return scriptURL.path
        } catch {
            return "/bin/sh"
        }
    }
}
