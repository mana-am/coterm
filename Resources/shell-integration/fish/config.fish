# coterm shell integration for fish
# Injected automatically, do not source manually.

set -l _coterm_integration_enabled 1
if set -q COTERM_SHELL_INTEGRATION; and test "$COTERM_SHELL_INTEGRATION" = 0
    set _coterm_integration_enabled 0
end

if test "$_coterm_integration_enabled" != 0
    set -g _COTERM_SEND_TOOL ""
    if command -sq ncat
        set -g _COTERM_SEND_TOOL ncat
    else if command -sq socat
        set -g _COTERM_SEND_TOOL socat
    else if command -sq nc
        set -g _COTERM_SEND_TOOL nc
    end

    set -g _COTERM_SHELL_ACTIVITY_LAST ""
    set -g _COTERM_PORTS_LAST_RUN 0
    set -g _COTERM_TTY_NAME ""
    set -g _COTERM_TTY_REPORTED 0
    set -g _COTERM_PWD_LAST_PWD ""

    function _coterm_now
        if test -n "$EPOCHSECONDS"
            printf '%s\n' "$EPOCHSECONDS"
        else
            date +%s
        end
    end

    function _coterm_socket_is_unix
        test -n "$COTERM_SOCKET_PATH"; and test -S "$COTERM_SOCKET_PATH"
    end

    function _coterm_relay_cli_path
        if test -n "$COTERM_BUNDLED_CLI_PATH"; and test -x "$COTERM_BUNDLED_CLI_PATH"
            printf '%s\n' "$COTERM_BUNDLED_CLI_PATH"
            return 0
        end
        command -v coterm 2>/dev/null
    end

    function _coterm_socket_uses_remote_relay
        test -n "$COTERM_SOCKET_PATH"; or return 1
        string match -q '/*' -- "$COTERM_SOCKET_PATH"; and return 1
        string match -q '*:*' -- "$COTERM_SOCKET_PATH"; or return 1
        set -l relay_cli (_coterm_relay_cli_path)
        test -n "$relay_cli"
    end

    function _coterm_send --argument-names payload
        test -n "$payload"; or return 0
        test -n "$COTERM_SOCKET_PATH"; or return 0
        switch "$_COTERM_SEND_TOOL"
            case ncat
                printf '%s\n' "$payload" | ncat -w 1 -U "$COTERM_SOCKET_PATH" --send-only >/dev/null 2>&1
            case socat
                printf '%s\n' "$payload" | socat -T 1 - "UNIX-CONNECT:$COTERM_SOCKET_PATH" >/dev/null 2>&1
            case nc
                printf '%s\n' "$payload" | nc -N -U "$COTERM_SOCKET_PATH" >/dev/null 2>&1; or printf '%s\n' "$payload" | nc -w 1 -U "$COTERM_SOCKET_PATH" >/dev/null 2>&1
        end
    end

    function _coterm_send_bg --argument-names payload
        _coterm_send "$payload" >/dev/null 2>&1 &
    end

    function _coterm_json_escape --argument-names value
        set -l backslash "\\"
        set -l escaped_backslash "\\\\"
        set -l quote '"'
        set -l escaped_quote '\"'
        string replace -a "$backslash" "$escaped_backslash" -- "$value" \
            | string replace -a "$quote" "$escaped_quote" \
            | string replace -a (printf '\n') "\\n" \
            | string replace -a (printf '\r') "\\r" \
            | string replace -a (printf '\t') "\\t"
    end

    function _coterm_relay_workspace_id
        if test -n "$COTERM_WORKSPACE_ID"
            printf '%s\n' "$COTERM_WORKSPACE_ID"
            return 0
        end
        test -n "$COTERM_TAB_ID"; or return 1
        printf '%s\n' "$COTERM_TAB_ID"
    end

    function _coterm_relay_rpc_bg --argument-names method params
        _coterm_socket_uses_remote_relay; or return 1
        set -l relay_cli (_coterm_relay_cli_path)
        test -n "$relay_cli"; or return 1
        "$relay_cli" rpc "$method" "$params" >/dev/null 2>&1 &
    end

    function _coterm_report_tty_via_relay
        _coterm_socket_uses_remote_relay; or return 1
        test -n "$_COTERM_TTY_NAME"; or return 1
        set -l workspace_id (_coterm_relay_workspace_id); or return 1
        set -l tty_name_json (_coterm_json_escape "$_COTERM_TTY_NAME")
        set -l params "{\"workspace_id\":\"$workspace_id\",\"tty_name\":\"$tty_name_json\""
        if test -n "$COTERM_PANEL_ID"
            set params "$params,\"surface_id\":\"$COTERM_PANEL_ID\""
        end
        set params "$params}"
        _coterm_relay_rpc_bg surface.report_tty "$params"
    end

    function _coterm_report_pwd_via_relay --argument-names pwd
        _coterm_socket_uses_remote_relay; or return 1
        test -n "$pwd"; or return 1
        set -l workspace_id (_coterm_relay_workspace_id); or return 1
        set -l pwd_json (_coterm_json_escape "$pwd")
        set -l params "{\"workspace_id\":\"$workspace_id\",\"path\":\"$pwd_json\""
        if test -n "$COTERM_PANEL_ID"
            set params "$params,\"surface_id\":\"$COTERM_PANEL_ID\""
        end
        set params "$params}"
        _coterm_relay_rpc_bg surface.report_pwd "$params"
    end

    function _coterm_ports_kick_via_relay --argument-names reason
        _coterm_socket_uses_remote_relay; or return 1
        set -l workspace_id (_coterm_relay_workspace_id); or return 1
        test -n "$reason"; or set reason command
        set -l params "{\"workspace_id\":\"$workspace_id\",\"reason\":\"$reason\""
        if test -n "$COTERM_PANEL_ID"
            set params "$params,\"surface_id\":\"$COTERM_PANEL_ID\""
        end
        set params "$params}"
        _coterm_relay_rpc_bg surface.ports_kick "$params"
    end

    function _coterm_path_prepend_unique_directory --argument-names directory
        test -n "$directory"; or return 0
        set -l next_path "$directory"
        for entry in $PATH
            test "$entry" = "$directory"; and continue
            set -a next_path "$entry"
        end
        set -gx PATH $next_path
    end

    function _coterm_install_cli_command_shim --argument-names command_name wrapper_path
        set -l tmp_root /tmp
        if set -q TMPDIR; and test -n "$TMPDIR"
            set tmp_root "$TMPDIR"
        end
        set -l surface_component "$fish_pid"
        if set -q COTERM_SURFACE_ID; and test -n "$COTERM_SURFACE_ID"
            set surface_component "$COTERM_SURFACE_ID"
        end
        set -l shim_root "$tmp_root/coterm-cli-shims/$surface_component"
        set -l shim_path "$shim_root/$command_name"
        mkdir -p "$shim_root" >/dev/null 2>&1; or return 0
        begin
            printf '%s\n' '#!/usr/bin/env bash'
            if test "$command_name" = claude
                printf 'coterm_wrapper=%s\n' (string escape --style=script -- "$wrapper_path")
                printf '%s\n' 'if [[ ! -x "$coterm_wrapper" && -n "${COTERM_BUNDLED_CLI_PATH:-}" ]]; then'
                printf '%s\n' '    coterm_candidate="$(dirname "$COTERM_BUNDLED_CLI_PATH")/coterm-claude-wrapper"'
                printf '%s\n' '    if [[ -x "$coterm_candidate" ]]; then'
                printf '%s\n' '        coterm_wrapper="$coterm_candidate"'
                printf '%s\n' '    fi'
                printf '%s\n' 'fi'
                printf '%s\n' 'if [[ ! -x "$coterm_wrapper" ]]; then'
                printf '%s\n' '    coterm_cli="$(command -v coterm 2>/dev/null || true)"'
                printf '%s\n' '    if [[ -n "$coterm_cli" ]]; then'
                printf '%s\n' '        coterm_candidate="$(dirname "$coterm_cli")/coterm-claude-wrapper"'
                printf '%s\n' '        if [[ -x "$coterm_candidate" ]]; then'
                printf '%s\n' '            coterm_wrapper="$coterm_candidate"'
                printf '%s\n' '        fi'
                printf '%s\n' '    fi'
                printf '%s\n' 'fi'
                printf 'export COTERM_CLAUDE_WRAPPER_SHIM=%s\n' (string escape --style=script -- "$shim_path")
                printf 'export COTERM_CLAUDE_WRAPPER_SHIM_ROOT=%s\n' (string escape --style=script -- "$shim_root")
                printf '%s\n' 'if [[ -x "$coterm_wrapper" ]]; then'
                printf '%s\n' '    exec "$coterm_wrapper" "$@"'
                printf '%s\n' 'fi'
                printf '%s\n' 'coterm_path_without_shim=""'
                printf '%s\n' 'coterm_old_ifs="$IFS"'
                printf '%s\n' 'IFS=:'
                printf '%s\n' 'for coterm_entry in ${PATH:-}; do'
                printf '%s\n' '    if [[ "$coterm_entry" == "$COTERM_CLAUDE_WRAPPER_SHIM_ROOT" || "$coterm_entry" == */coterm-cli-shims/* || "$coterm_entry" == */coterm-cli-shims ]]; then'
                printf '%s\n' '        continue'
                printf '%s\n' '    fi'
                printf '%s\n' '    if [[ -z "$coterm_path_without_shim" ]]; then'
                printf '%s\n' '        coterm_path_without_shim="$coterm_entry"'
                printf '%s\n' '    else'
                printf '%s\n' '        coterm_path_without_shim="$coterm_path_without_shim:$coterm_entry"'
                printf '%s\n' '    fi'
                printf '%s\n' 'done'
                printf '%s\n' 'IFS="$coterm_old_ifs"'
                printf '%s\n' 'export PATH="$coterm_path_without_shim"'
                printf '%s\n' 'exec claude "$@"'
            else
                printf 'exec %s "$@"\n' (string escape --style=script -- "$wrapper_path")
            end
        end >"$shim_path" 2>/dev/null; or return 0
        chmod 0700 "$shim_path" >/dev/null 2>&1; or return 0
        if test "$command_name" = claude
            set -gx COTERM_CLAUDE_WRAPPER_SHIM "$shim_path"
            set -gx COTERM_CLAUDE_WRAPPER_SHIM_ROOT "$shim_root"
        end
        _coterm_path_prepend_unique_directory "$shim_root"
    end

    function _coterm_install_cli_wrapper --argument-names command_name wrapper_file
        test -n "$COTERM_SHELL_INTEGRATION_DIR"; or return 0
        set -l integration_dir (string replace -r '/$' '' -- "$COTERM_SHELL_INTEGRATION_DIR")
        set -l bundle_dir (string replace -r '/shell-integration$' '' -- "$integration_dir")
        set -l wrapper_path "$bundle_dir/bin/$wrapper_file"
        test -x "$wrapper_path"; or return 0

        if test "$command_name" = claude
            _coterm_install_cli_command_shim "$command_name" "$wrapper_path"
        end
        functions -q "$command_name"; and return 0
        switch "$command_name"
            case claude
                function claude --wraps "$wrapper_path" --inherit-variable wrapper_path
                    if test -x "$COTERM_CLAUDE_WRAPPER_SHIM"
                        "$COTERM_CLAUDE_WRAPPER_SHIM" $argv
                    else if test -x "$wrapper_path"
                        "$wrapper_path" $argv
                    else
                        command claude $argv
                    end
                end
            case grok
                function grok --wraps "$wrapper_path" --inherit-variable wrapper_path
                    "$wrapper_path" $argv
                end
        end
    end

    _coterm_install_cli_wrapper claude coterm-claude-wrapper
    _coterm_install_cli_wrapper grok grok

    function _coterm_report_tty_once
        test "$_COTERM_TTY_REPORTED" = 1; and return 0
        if test -z "$_COTERM_TTY_NAME"
            set -g _COTERM_TTY_NAME (tty 2>/dev/null | string replace -r '^.*/' '')
        end
        test -n "$_COTERM_TTY_NAME"; or return 0
        test "$_COTERM_TTY_NAME" != "not a tty"; or return 0

        if _coterm_socket_is_unix
            test -n "$COTERM_TAB_ID"; or return 0
            test -n "$COTERM_PANEL_ID"; or return 0
            set -g _COTERM_TTY_REPORTED 1
            _coterm_send_bg "report_tty $_COTERM_TTY_NAME --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID"
        else if _coterm_socket_uses_remote_relay
            set -g _COTERM_TTY_REPORTED 1
            _coterm_report_tty_via_relay
        end
    end

    function _coterm_report_shell_activity_state --argument-names state
        test -n "$state"; or return 0
        _coterm_socket_is_unix; or return 0
        test -n "$COTERM_TAB_ID"; or return 0
        test -n "$COTERM_PANEL_ID"; or return 0
        test "$_COTERM_SHELL_ACTIVITY_LAST" = "$state"; and return 0
        set -g _COTERM_SHELL_ACTIVITY_LAST "$state"
        _coterm_send_bg "report_shell_state $state --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID"
    end

    function _coterm_reset_terminal_keyboard_protocols
        isatty stdout; or test -n "$COTERM_TEST_FORCE_KEYBOARD_RESET$COTERM_TEST_FORCE_KITTY_RESET"; or return 0
        printf '\033[>m\033[<8u\033[?9l\033[?1000l\033[?1002l\033[?1003l\033[?1005l\033[?1006l\033[?1004l\033[?2004l\033[?2026l'
    end

    function _coterm_ports_kick --argument-names reason
        test -n "$reason"; or set reason command
        test -n "$COTERM_TAB_ID"; or return 0
        set -g _COTERM_PORTS_LAST_RUN (_coterm_now)
        if _coterm_socket_is_unix
            test -n "$COTERM_PANEL_ID"; or return 0
            _coterm_send_bg "ports_kick --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID --reason=$reason"
        else
            _coterm_ports_kick_via_relay "$reason"
        end
    end

    function _coterm_preexec --on-event fish_preexec
        _coterm_report_tty_once
        _coterm_report_shell_activity_state running
        _coterm_ports_kick command
    end

    function _coterm_prompt --on-event fish_prompt
        _coterm_reset_terminal_keyboard_protocols
        _coterm_report_tty_once
        _coterm_report_shell_activity_state prompt
        set -l pwd "$PWD"
        if test "$pwd" != "$_COTERM_PWD_LAST_PWD"
            if _coterm_socket_is_unix
                if test -n "$COTERM_TAB_ID"; and test -n "$COTERM_PANEL_ID"
                    set -l qpwd (_coterm_json_escape "$pwd")
                    if _coterm_send_bg "report_pwd \"$qpwd\" --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID"
                        set -g _COTERM_PWD_LAST_PWD "$pwd"
                    end
                end
            else if _coterm_report_pwd_via_relay "$pwd"
                set -g _COTERM_PWD_LAST_PWD "$pwd"
            end
        end
        set -l now (_coterm_now)
        if test (math "$now - $_COTERM_PORTS_LAST_RUN") -ge 5
            _coterm_ports_kick refresh
        end
    end
end

set -l _coterm_user_config_home ""
if set -q COTERM_FISH_CONFIG_HOME
    set _coterm_user_config_home "$COTERM_FISH_CONFIG_HOME"
else if set -q HOME
    set _coterm_user_config_home "$HOME/.config"
end

set -l _coterm_user_config "$_coterm_user_config_home/fish/config.fish"
if not set -q COTERM_FISH_USER_CONFIG_ALREADY_LOADED; and test -n "$_coterm_user_config_home"; and test "$_coterm_user_config_home" != "$XDG_CONFIG_HOME"
    set -gx XDG_CONFIG_HOME "$_coterm_user_config_home"

    set -l _coterm_user_functions "$_coterm_user_config_home/fish/functions"
    if test -d "$_coterm_user_functions"; and not contains -- "$_coterm_user_functions" $fish_function_path
        set -g fish_function_path "$_coterm_user_functions" $fish_function_path
    end

    set -l _coterm_user_completions "$_coterm_user_config_home/fish/completions"
    if test -d "$_coterm_user_completions"; and not contains -- "$_coterm_user_completions" $fish_complete_path
        set -g fish_complete_path "$_coterm_user_completions" $fish_complete_path
    end

    for _coterm_user_conf in "$_coterm_user_config_home"/fish/conf.d/*.fish
        if test -r "$_coterm_user_conf"
            source "$_coterm_user_conf"
        end
    end

    if test -r "$_coterm_user_config"
        source "$_coterm_user_config"
    end
end
