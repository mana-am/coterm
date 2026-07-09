public import Foundation

// Remote-side relay provisioning script builders. Static because they
// compose pure script text from raw inputs independent of a session instance
// (the CotermCore SSH-option-normalization precedent); the script text is
// wire/process behavior pinned by tests — do not alter.
extension RemoteSessionCoordinator {
    /// Script that removes the relay metadata files for `relayPort` and the
    /// `socket_addr` pointer when it still points at that relay.
    public static func remoteRelayMetadataCleanupScript(relayPort: Int) -> String {
        """
        relay_socket='127.0.0.1:\(relayPort)'
        socket_addr_file="$HOME/.coterm/socket_addr"
        if [ -r "$socket_addr_file" ] && [ "$(tr -d '\\r\\n' < "$socket_addr_file")" = "$relay_socket" ]; then
          rm -f "$socket_addr_file"
        fi
        rm -f "$HOME/.coterm/relay/\(relayPort).auth" "$HOME/.coterm/relay/\(relayPort).daemon_path" "$HOME/.coterm/relay/\(relayPort).slot" "$HOME/.coterm/relay/\(relayPort).tty"
        """
    }

    /// Script that kills a stale sshd listener (and its persistent
    /// cotermd-remote children for `persistentDaemonSlot`) still bound to
    /// `relayPort`, or `nil` when the inputs cannot be matched safely.
    public static func remoteStaleRelayListenerCleanupScript(
        relayPort: Int,
        persistentDaemonSlot: String?
    ) -> String? {
        guard relayPort > 0, relayPort <= 65535 else { return nil }
        guard let persistentDaemonSlot = normalizedPersistentDaemonSlotForRemoteCleanup(persistentDaemonSlot) else {
            return nil
        }

        return """
        coterm_stale_relay_listener_cleanup=1
        coterm_relay_port='\(relayPort)'
        coterm_persistent_slot=\(persistentDaemonSlot.shellSingleQuoted)
        coterm_listener_pids=''
        if command -v lsof >/dev/null 2>&1; then
          coterm_listener_pids="$(lsof -nP -iTCP:"$coterm_relay_port" -sTCP:LISTEN -Fpn 2>/dev/null | awk -v port="$coterm_relay_port" '
            /^p/ { pid = substr($0, 2); next }
            /^n/ {
              name = substr($0, 2)
              if (pid ~ /^[0-9]+$/ && name ~ ("(^|[^0-9])127[.]0[.]0[.]1:" port "$")) {
                seen[pid] = 1
              }
            }
            END {
              for (pid in seen) print pid
            }
          ')"
        fi
        [ -n "$coterm_listener_pids" ] || exit 0
        coterm_ps_output="$(ps -axo pid=,ppid=,command= 2>/dev/null || true)"
        for coterm_listener_pid in $coterm_listener_pids; do
          case "$coterm_listener_pid" in
            ''|*[!0-9]*) continue ;;
          esac
          coterm_listener_command="$(printf '%s\\n' "$coterm_ps_output" | awk -v target="$coterm_listener_pid" '$1 == target { $1 = ""; $2 = ""; sub(/^[[:space:]]+/, ""); print; exit }')"
          case "$coterm_listener_command" in
            *sshd*|*ssh*) ;;
            *) continue ;;
          esac
          coterm_child_pids="$(printf '%s\\n' "$coterm_ps_output" | awk -v parent="$coterm_listener_pid" -v slot="$coterm_persistent_slot" '
            function clean_token(value) {
              gsub(/\\047/, "", value)
              gsub(/"/, "", value)
              gsub(/\\\\/, "", value)
              return value
            }
            function has_token(target, i) {
              for (i = 3; i <= NF; i++) {
                if (clean_token($i) == target) return 1
              }
              return 0
            }
            function next_value(after, i, value) {
              for (i = after + 1; i <= NF; i++) {
                value = clean_token($i)
                if (value != "") return value
              }
              return ""
            }
            function has_exact_slot(i, token, value) {
              for (i = 3; i <= NF; i++) {
                token = clean_token($i)
                if (token == "--slot") {
                  return next_value(i) == slot
                }
                if (token ~ /^--slot=/) {
                  value = substr(token, 8)
                  if (value != "") return value == slot
                  return next_value(i) == slot
                }
              }
              return 0
            }
            $2 == parent &&
            index($0, "cotermd-remote") &&
            has_token("serve") &&
            has_token("--stdio") &&
            has_token("--persistent") &&
            has_exact_slot() &&
            $1 ~ /^[0-9]+$/ {
              print $1
            }
          ')"
          coterm_cleanup_reason=child
          if [ -z "$coterm_child_pids" ]; then
            coterm_cleanup_reason=metadata
            coterm_metadata_ok=0
            coterm_slot_file="$HOME/.coterm/relay/${coterm_relay_port}.slot"
            coterm_metadata_slot_ok=0
            if [ -r "$coterm_slot_file" ]; then
              coterm_stored_slot="$(tr -d '\\r\\n' < "$coterm_slot_file")"
              [ "$coterm_stored_slot" = "$coterm_persistent_slot" ] && coterm_metadata_slot_ok=1
            fi
            if [ "$coterm_metadata_slot_ok" -eq 1 ]; then
              coterm_daemon_map="$HOME/.coterm/relay/${coterm_relay_port}.daemon_path"
              coterm_auth_file="$HOME/.coterm/relay/${coterm_relay_port}.auth"
              if [ -r "$coterm_daemon_map" ]; then
                coterm_daemon_path="$(tr -d '\\r\\n' < "$coterm_daemon_map")"
                case "$coterm_daemon_path" in
                  *cotermd-remote*) coterm_metadata_ok=1 ;;
                esac
              fi
              if [ "$coterm_metadata_ok" -ne 1 ] && [ -r "$coterm_auth_file" ]; then
                coterm_auth_payload="$(tr -d '\\r\\n' < "$coterm_auth_file")"
                case "$coterm_auth_payload" in
                  *relay_id*relay_token*) coterm_metadata_ok=1 ;;
                esac
              fi
            fi
            [ "$coterm_metadata_ok" -eq 1 ] || continue
          fi
          kill -TERM "$coterm_listener_pid" $coterm_child_pids 2>/dev/null || true
          for coterm_child_pid in $coterm_child_pids; do
            kill -0 "$coterm_child_pid" 2>/dev/null && kill -KILL "$coterm_child_pid" 2>/dev/null || true
          done
          kill -0 "$coterm_listener_pid" 2>/dev/null && kill -KILL "$coterm_listener_pid" 2>/dev/null || true
          coterm_child_list="$(printf '%s\\n' "$coterm_child_pids" | tr '\\n' ' ' | sed 's/[[:space:]]*$//')"
          printf 'coterm_stale_relay_killed pid=%s children=%s port=%s reason=%s\\n' "$coterm_listener_pid" "$coterm_child_list" "$coterm_relay_port" "$coterm_cleanup_reason"
        done
        """
    }

    static func normalizedPersistentDaemonSlotForRemoteCleanup(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != ".",
              trimmed != "..",
              trimmed.range(of: "^[A-Za-z0-9._-]{1,128}$", options: .regularExpression) != nil else {
            return nil
        }
        return trimmed
    }

    static func remoteCLIWrapperScript() -> String {
        """
        #!/bin/sh
        set -eu

        daemon="$HOME/.coterm/bin/cotermd-remote-current"
        socket_path="${COTERM_SOCKET_PATH:-}"
        if [ -z "$socket_path" ] && [ -r "$HOME/.coterm/socket_addr" ]; then
          socket_path="$(tr -d '\\r\\n' < "$HOME/.coterm/socket_addr")"
        fi

        if [ -n "$socket_path" ] && [ "${socket_path#/}" = "$socket_path" ] && [ "${socket_path#*:}" != "$socket_path" ]; then
          relay_port="${socket_path##*:}"
          relay_map="$HOME/.coterm/relay/${relay_port}.daemon_path"
          if [ -r "$relay_map" ]; then
            mapped_daemon="$(tr -d '\\r\\n' < "$relay_map")"
            if [ -n "$mapped_daemon" ] && [ -x "$mapped_daemon" ]; then
              daemon="$mapped_daemon"
            fi
          fi
        fi

        exec "$daemon" "$@"
        """
    }

    static func remoteCLIWrapperInstallScript(daemonRemotePath: String) -> String {
        let trimmedRemotePath = daemonRemotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let daemonPathExpression = remoteDaemonPathShellExpression(trimmedRemotePath)
        return """
        mkdir -p "$HOME/.coterm/bin" "$HOME/.coterm/relay"
        ln -sf \(daemonPathExpression) "$HOME/.coterm/bin/cotermd-remote-current"
        wrapper_tmp="$HOME/.coterm/bin/.coterm-wrapper.tmp.$$"
        cat > "$wrapper_tmp" <<'COTERMWRAPPER'
        \(remoteCLIWrapperScript())
        COTERMWRAPPER
        chmod 755 "$wrapper_tmp"
        mv -f "$wrapper_tmp" "$HOME/.coterm/bin/coterm"
        """
    }

    static func remoteRelayMetadataInstallScript(
        daemonRemotePath: String,
        relayPort: Int,
        relayID: String,
        relayToken: String,
        persistentDaemonSlot: String? = nil
    ) -> String {
        let trimmedRemotePath = daemonRemotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let daemonPathExpression = remoteDaemonPathShellExpression(trimmedRemotePath)
        let slotMetadataLine: String
        if let slot = normalizedPersistentDaemonSlotForRemoteCleanup(persistentDaemonSlot) {
            slotMetadataLine = "printf '%s' \(slot.shellSingleQuoted) > \"$HOME/.coterm/relay/\(relayPort).slot\"\nchmod 600 \"$HOME/.coterm/relay/\(relayPort).slot\""
        } else {
            slotMetadataLine = "rm -f \"$HOME/.coterm/relay/\(relayPort).slot\""
        }
        let authPayload = """
        {"relay_id":"\(relayID)","relay_token":"\(relayToken)"}
        """
        return """
        umask 077
        mkdir -p "$HOME/.coterm" "$HOME/.coterm/relay"
        chmod 700 "$HOME/.coterm/relay"
        \(remoteCLIWrapperInstallScript(daemonRemotePath: trimmedRemotePath))
        printf '%s' \(daemonPathExpression) > "$HOME/.coterm/relay/\(relayPort).daemon_path"
        \(slotMetadataLine)
        cat > "$HOME/.coterm/relay/\(relayPort).auth" <<'COTERMRELAYAUTH'
        \(authPayload)
        COTERMRELAYAUTH
        chmod 600 "$HOME/.coterm/relay/\(relayPort).auth"
        printf '%s' '127.0.0.1:\(relayPort)' > "$HOME/.coterm/socket_addr"
        """
    }

    static func remoteDaemonPathShellExpression(_ remotePath: String) -> String {
        let trimmedRemotePath = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedRemotePath.hasPrefix("/") {
            return trimmedRemotePath.shellSingleQuoted
        }
        return "\"$HOME/\(trimmedRemotePath)\""
    }
}
