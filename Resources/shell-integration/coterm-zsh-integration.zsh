# coterm shell integration for zsh
# Injected automatically — do not source manually

# Prefer zsh/net/unix for socket sends (no fork, ~0.2ms per send vs ~3ms
# for fork+exec of ncat/socat/nc).  Falls back to external tools if the
# module is unavailable.
typeset -g _COTERM_HAS_ZSOCKET=0
if zmodload zsh/net/unix 2>/dev/null; then
    _COTERM_HAS_ZSOCKET=1
fi

typeset -g _COTERM_HAS_ZSH_JOBSTATES=0
if zmodload zsh/parameter 2>/dev/null && (( ${+jobstates} )); then
    _COTERM_HAS_ZSH_JOBSTATES=1
fi

_coterm_zsh_job_table_saturated() {
    (( _COTERM_HAS_ZSH_JOBSTATES )) || return 1

    local limit="${COTERM_ZSH_JOB_TABLE_SOFT_LIMIT:-900}"
    case "$limit" in
        ''|*[!0-9]*) limit=900 ;;
    esac
    (( limit > 0 )) || limit=900

    local job_count=${#jobstates}
    (( job_count >= limit ))
}

_coterm_restore_status() {
    builtin return "$1"
}

_coterm_send() {
    local payload="$1"
    if (( _COTERM_HAS_ZSOCKET )); then
        local fd
        zsocket "$COTERM_SOCKET_PATH" 2>/dev/null || return 1
        fd=$REPLY
        print -u $fd -r -- "$payload" 2>/dev/null
        exec {fd}>&- 2>/dev/null
        return 0
    fi
    if command -v ncat >/dev/null 2>&1; then
        print -r -- "$payload" | ncat -w 1 -U "$COTERM_SOCKET_PATH" --send-only
    elif command -v socat >/dev/null 2>&1; then
        print -r -- "$payload" | socat -T 1 - "UNIX-CONNECT:$COTERM_SOCKET_PATH" >/dev/null 2>&1
    elif command -v nc >/dev/null 2>&1; then
        if print -r -- "$payload" | nc -N -U "$COTERM_SOCKET_PATH" >/dev/null 2>&1; then
            :
        else
            print -r -- "$payload" | nc -w 1 -U "$COTERM_SOCKET_PATH" >/dev/null 2>&1 || true
        fi
    fi
}

# Fire-and-forget send: synchronous when zsocket is available (fast, no fork),
# backgrounded otherwise.
_coterm_send_bg() {
    if (( _COTERM_HAS_ZSOCKET )); then
        _coterm_send "$1"
    else
        _coterm_zsh_job_table_saturated && return 0
        { _coterm_send "$1" } >/dev/null 2>&1 &!
    fi
}

_coterm_socket_is_unix() {
    [[ -n "$COTERM_SOCKET_PATH" && -S "$COTERM_SOCKET_PATH" ]]
}

_coterm_relay_cli_path() {
    if [[ -n "${COTERM_BUNDLED_CLI_PATH:-}" && -x "${COTERM_BUNDLED_CLI_PATH}" ]]; then
        print -r -- "${COTERM_BUNDLED_CLI_PATH}"
        return 0
    fi
    command -v coterm 2>/dev/null
}

_coterm_socket_uses_remote_relay() {
    [[ -n "$COTERM_SOCKET_PATH" ]] || return 1
    [[ "$COTERM_SOCKET_PATH" == /* ]] && return 1
    [[ "$COTERM_SOCKET_PATH" == *:* ]] || return 1
    [[ -n "$(_coterm_relay_cli_path)" ]]
}

_coterm_has_port_scan_transport() {
    _coterm_socket_is_unix && return 0
    _coterm_socket_uses_remote_relay
}

_coterm_json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    print -r -- "$value"
}

_coterm_relay_rpc_bg() {
    local method="$1"
    local params="$2"
    local relay_cli=""
    _coterm_zsh_job_table_saturated && return 1
    _coterm_socket_uses_remote_relay || return 1
    relay_cli="$(_coterm_relay_cli_path)" || return 1
    { "$relay_cli" rpc "$method" "$params" >/dev/null 2>&1 || true } >/dev/null 2>&1 &!
}

_coterm_relay_rpc() {
    local method="$1"
    local params="$2"
    local relay_cli=""
    local response=""
    _coterm_socket_uses_remote_relay || return 1
    # Relay `coterm rpc` exits nonzero on server error. The real remote CLI prints
    # only the JSON result payload on success, while some test stubs return the
    # full `{"ok":...}` envelope. Retry only on explicit `ok:false`.
    relay_cli="$(_coterm_relay_cli_path)" || return 1
    response="$("$relay_cli" rpc "$method" "$params" 2>/dev/null)" || return 1
    response="${response//$'\n'/}"
    response="${response//$'\r'/}"
    [[ "$response" == *'"ok":false'* || "$response" == *'"ok": false'* ]] && return 1
    return 0
}

_coterm_relay_workspace_id() {
    if [[ -n "$COTERM_WORKSPACE_ID" ]]; then
        print -r -- "$COTERM_WORKSPACE_ID"
        return 0
    fi
    [[ -n "$COTERM_TAB_ID" ]] || return 1
    print -r -- "$COTERM_TAB_ID"
}

_coterm_report_tty_via_relay() {
    _coterm_socket_uses_remote_relay || return 1
    local workspace_id=""
    workspace_id="$(_coterm_relay_workspace_id)" || return 1
    [[ -n "$_COTERM_TTY_NAME" ]] || return 1

    local tty_name_json params
    tty_name_json="$(_coterm_json_escape "$_COTERM_TTY_NAME")"
    params="{\"workspace_id\":\"$workspace_id\",\"tty_name\":\"$tty_name_json\""
    if [[ -n "$COTERM_PANEL_ID" ]]; then
        params+=",\"surface_id\":\"$COTERM_PANEL_ID\""
    fi
    params+="}"
    _coterm_relay_rpc "surface.report_tty" "$params"
}

_coterm_report_pwd_via_relay() {
    local pwd="$1"
    _coterm_socket_uses_remote_relay || return 1
    [[ -n "$pwd" ]] || return 1
    local workspace_id=""
    workspace_id="$(_coterm_relay_workspace_id)" || return 1

    local pwd_json params
    pwd_json="$(_coterm_json_escape "$pwd")"
    params="{\"workspace_id\":\"$workspace_id\",\"path\":\"$pwd_json\""
    if [[ -n "$COTERM_PANEL_ID" ]]; then
        params+=",\"surface_id\":\"$COTERM_PANEL_ID\""
    fi
    params+="}"
    _coterm_relay_rpc_bg "surface.report_pwd" "$params"
}

_coterm_ports_kick_via_relay() {
    local reason="${1:-command}"
    _coterm_socket_uses_remote_relay || return 1
    local workspace_id=""
    workspace_id="$(_coterm_relay_workspace_id)" || return 1
    local params="{\"workspace_id\":\"$workspace_id\",\"reason\":\"$reason\""
    if [[ -n "$COTERM_PANEL_ID" ]]; then
        params+=",\"surface_id\":\"$COTERM_PANEL_ID\""
    fi
    params+="}"
    _coterm_relay_rpc_bg "surface.ports_kick" "$params"
}

_coterm_restore_scrollback_once() {
    local path="${COTERM_RESTORE_SCROLLBACK_FILE:-}"
    [[ -n "$path" ]] || return 0
    unset COTERM_RESTORE_SCROLLBACK_FILE

    if [[ -r "$path" ]]; then
        /bin/cat -- "$path" 2>/dev/null || true
        /bin/rm -f -- "$path" >/dev/null 2>&1 || true
    fi
}
_coterm_restore_scrollback_once

_coterm_now() {
    print -r -- "${EPOCHSECONDS:-$SECONDS}"
}

typeset -g _COTERM_CLAUDE_WRAPPER=""
typeset -g _COTERM_GROK_WRAPPER=""
_coterm_path_prepend_unique_directory() {
    local directory="$1"
    local current_path="${2-}"
    local skipped_directory="${3-}"
    local result="$directory"
    local rest="$current_path"
    local entry=""
    local has_more=false

    [[ -n "$directory" ]] || {
        printf '%s' "$current_path"
        return 0
    }
    [[ -n "$current_path" ]] || {
        printf '%s' "$directory"
        return 0
    }

    while true; do
        if [[ "$rest" == *:* ]]; then
            entry="${rest%%:*}"
            rest="${rest#*:}"
            has_more=true
        else
            entry="$rest"
            rest=""
            has_more=false
        fi

        if [[ "$entry" != "$directory" && ( -z "$skipped_directory" || "$entry" != "$skipped_directory" ) ]]; then
            result="$result:$entry"
        fi
        [[ "$has_more" == true ]] || break
    done

    printf '%s' "$result"
}
_coterm_install_cli_command_shim() {
    local command_name="$1"
    local wrapper_path="$2"
    local shim_root="${TMPDIR:-/tmp}/coterm-cli-shims/${COTERM_SURFACE_ID:-$$}"
    local shim_path="$shim_root/$command_name"
    local escaped_wrapper="$wrapper_path"

    escaped_wrapper="${escaped_wrapper//\\/\\\\}"
    escaped_wrapper="${escaped_wrapper//\"/\\\"}"
    escaped_wrapper="${escaped_wrapper//\$/\\\$}"
    escaped_wrapper="${escaped_wrapper//\`/\\\`}"

    /bin/mkdir -p "$shim_root" >/dev/null 2>&1 || return 0
    {
        printf '%s\n' '#!/usr/bin/env bash'
        if [[ "$command_name" == "claude" ]]; then
            printf 'coterm_wrapper="%s"\n' "$escaped_wrapper"
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
            printf 'export COTERM_CLAUDE_WRAPPER_SHIM="%s"\n' "$shim_path"
            printf 'export COTERM_CLAUDE_WRAPPER_SHIM_ROOT="%s"\n' "$shim_root"
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
            printf 'exec "%s" "$@"\n' "$escaped_wrapper"
        fi
    # Use zsh's explicit clobber redirection (>|) so coterm always refreshes its
    # own generated shim, even when the user's interactive zsh has `noclobber`
    # set. A plain `>` is refused under noclobber and prints `file exists` on
    # startup (the writer runs again from the _coterm_fix_path precmd hook after
    # the shim already exists). See issue #6714.
    } >|"$shim_path" 2>/dev/null || return 0
    /bin/chmod 0700 "$shim_path" >/dev/null 2>&1 || return 0

    if [[ "$command_name" == "claude" ]]; then
        export COTERM_CLAUDE_WRAPPER_SHIM="$shim_path"
        export COTERM_CLAUDE_WRAPPER_SHIM_ROOT="$shim_root"
    fi

    PATH="$(_coterm_path_prepend_unique_directory "$shim_root" "${PATH-}")"
    hash -r >/dev/null 2>&1 || rehash >/dev/null 2>&1 || true
}
_coterm_claude_wrapper_command() {
    if [[ -x "${COTERM_CLAUDE_WRAPPER_SHIM:-}" ]]; then
        "$COTERM_CLAUDE_WRAPPER_SHIM" "$@"
    elif [[ -x "${_COTERM_CLAUDE_WRAPPER:-}" ]]; then
        "$_COTERM_CLAUDE_WRAPPER" "$@"
    else
        command claude "$@"
    fi
}
_coterm_install_cli_wrapper() {
    local command_name="$1"
    local wrapper_variable="$2"
    local wrapper_file="${3:-$command_name}"
    local integration_dir="${COTERM_SHELL_INTEGRATION_DIR:-}"
    [[ -n "$integration_dir" ]] || return 0

    integration_dir="${integration_dir%/}"
    local bundle_dir="${integration_dir%/shell-integration}"
    local wrapper_path="$bundle_dir/bin/$wrapper_file"
    [[ -x "$wrapper_path" ]] || return 0

    # Keep the bundled wrapper ahead of later PATH mutations. Install it
    # via eval so an existing alias cannot break parsing.
    typeset -g "$wrapper_variable=$wrapper_path"
    if [[ "$command_name" == "claude" ]]; then
        _coterm_install_cli_command_shim "$command_name" "$wrapper_path"
    fi
    builtin unalias "$command_name" >/dev/null 2>&1 || true
    if [[ "$command_name" == "claude" ]]; then
        eval "$command_name() { _coterm_claude_wrapper_command \"\$@\"; }"
    else
        eval "$command_name() { \"\${$wrapper_variable}\" \"\$@\"; }"
    fi
}
_coterm_install_cli_wrapper claude _COTERM_CLAUDE_WRAPPER coterm-claude-wrapper
_coterm_install_cli_wrapper grok _COTERM_GROK_WRAPPER

_coterm_normalize_claude_config_dir() {
    [[ -n "${CLAUDE_CONFIG_DIR:-}" && -n "${HOME:-}" ]] || return 0

    local value="$CLAUDE_CONFIG_DIR"
    if [[ "$value" == "~/"* ]]; then
        value="$HOME/${value#~/}"
    fi

    local legacy_root="$HOME/.subrouter/codex/claude"
    local account_root="$HOME/.codex-accounts/claude"
    local suffix candidate

    if [[ "$value" == "$legacy_root" ]]; then
        candidate="$account_root"
    elif [[ "$value" == "$legacy_root/"* ]]; then
        suffix="${value#$legacy_root/}"
        candidate="$account_root/$suffix"
    else
        return 0
    fi

    [[ -d "$candidate" ]] || return 0
    export CLAUDE_CONFIG_DIR="$candidate"
}
_coterm_normalize_claude_config_dir

# Throttle heavy work to avoid prompt latency.
typeset -g _COTERM_PWD_LAST_PWD=""
typeset -g _COTERM_GIT_LAST_PWD=""
typeset -g _COTERM_GIT_LAST_RUN=0
typeset -g _COTERM_GIT_JOB_PID=""
typeset -g _COTERM_GIT_JOB_STARTED_AT=0
typeset -g _COTERM_GIT_FORCE=0
typeset -g _COTERM_GIT_HEAD_LAST_PWD=""
typeset -g _COTERM_GIT_HEAD_PATH=""
typeset -g _COTERM_GIT_HEAD_SIGNATURE=""
typeset -g _COTERM_GIT_HEAD_WATCH_PID=""
typeset -g _COTERM_GIT_ACTIVE_PWD_FILE="${_COTERM_GIT_ACTIVE_PWD_FILE:-$(/usr/bin/mktemp "${TMPDIR:-/tmp}/coterm-git-active-pwd.XXXXXX" 2>/dev/null || true)}"
typeset -g _COTERM_PR_POLL_PID=""
typeset -g _COTERM_PR_POLL_PWD=""
typeset -g _COTERM_PR_LAST_BRANCH=""
typeset -g _COTERM_PR_NO_PR_BRANCH=""
typeset -g _COTERM_PR_POLL_INTERVAL=45
typeset -g _COTERM_PR_FORCE=0
typeset -g _COTERM_PR_DEBUG=${_COTERM_PR_DEBUG:-0}
typeset -g _COTERM_ASYNC_JOB_TIMEOUT=20
typeset -g _COTERM_LAST_PR_ACTION=""
typeset -g _COTERM_LAST_PR_TARGET=""

typeset -g _COTERM_PORTS_LAST_RUN=0
typeset -g _COTERM_CMD_START=0
typeset -g _COTERM_SHELL_ACTIVITY_LAST=""
typeset -g _COTERM_TTY_NAME=""
typeset -g _COTERM_TTY_REPORTED=0
typeset -g _COTERM_GHOSTTY_SEMANTIC_PATCHED=0
typeset -g _COTERM_WINCH_GUARD_INSTALLED=0
typeset -g _COTERM_TMUX_PUSH_SIGNATURE=""
typeset -g _COTERM_TMUX_PULL_SIGNATURE=""
typeset -g _COTERM_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT=${_COTERM_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT:-0}
typeset -ga _COTERM_TMUX_SYNC_KEYS=(
    COTERM_BUNDLED_CLI_PATH
    COTERM_BUNDLE_ID
    COTERMD_UNIX_PATH
    COTERM_REPO_ROOT
    COTERM_DEBUG_LOG
    COTERM_LOAD_GHOSTTY_ZSH_INTEGRATION
    COTERM_PORT
    COTERM_PORT_END
    COTERM_PORT_RANGE
    COTERM_REMOTE_DAEMON_ALLOW_LOCAL_BUILD
    COTERM_SHELL_INTEGRATION
    COTERM_SHELL_INTEGRATION_DIR
    COTERM_SOCKET_ENABLE
    COTERM_SOCKET_MODE
    COTERM_SOCKET_PATH
    COTERM_TAB_ID
    COTERM_TAG
    COTERM_WORKSPACE_ID
)
typeset -ga _COTERM_TMUX_SURFACE_SCOPED_KEYS=(
    COTERM_PANEL_ID
    COTERM_SURFACE_ID
)

_coterm_tmux_sync_key_is_managed() {
    local candidate="$1"
    local key
    for key in "${_COTERM_TMUX_SYNC_KEYS[@]}"; do
        [[ "$key" == "$candidate" ]] && return 0
    done
    return 1
}

_coterm_tmux_shell_env_signature() {
    local key value
    local -a parts
    for key in "${_COTERM_TMUX_SYNC_KEYS[@]}"; do
        value="${(P)key}"
        [[ -n "$value" ]] || continue
        parts+=("${key}=${value}")
    done
    print -r -- "${(j:\x1f:)parts}"
}

_coterm_tmux_publish_coterm_environment() {
    [[ -z "$TMUX" ]] || return 0
    command -v tmux >/dev/null 2>&1 || return 0

    local signature
    signature="$(_coterm_tmux_shell_env_signature)"
    [[ -n "$signature" ]] || return 0
    [[ "$signature" == "$_COTERM_TMUX_PUSH_SIGNATURE" ]] && return 0

    local key value
    for key in "${_COTERM_TMUX_SYNC_KEYS[@]}"; do
        value="${(P)key}"
        [[ -n "$value" ]] || continue
        tmux set-environment -g "$key" "$value" >/dev/null 2>&1 || return 0
    done

    for key in "${_COTERM_TMUX_SURFACE_SCOPED_KEYS[@]}"; do
        tmux set-environment -gu "$key" >/dev/null 2>&1 || return 0
    done

    _COTERM_TMUX_PUSH_SIGNATURE="$signature"
}

_coterm_tmux_refresh_coterm_environment() {
    [[ -n "$TMUX" ]] || return 0
    command -v tmux >/dev/null 2>&1 || return 0

    local output
    output="$(tmux show-environment -g 2>/dev/null)" || return 0

    local line key filtered="" did_change=0
    while IFS= read -r line; do
        [[ "$line" == COTERM_* ]] || continue
        key="${line%%=*}"
        _coterm_tmux_sync_key_is_managed "$key" || continue
        filtered+="${line}"$'\n'
    done <<< "$output"

    [[ -n "$filtered" ]] || return 0
    [[ "$filtered" == "$_COTERM_TMUX_PULL_SIGNATURE" ]] && return 0

    local value
    while IFS= read -r line; do
        [[ "$line" == COTERM_* ]] || continue
        key="${line%%=*}"
        _coterm_tmux_sync_key_is_managed "$key" || continue
        value="${line#*=}"
        if [[ "${(P)key}" != "$value" ]]; then
            export "$key=$value"
            did_change=1
        fi
    done <<< "$filtered"

    _COTERM_TMUX_PULL_SIGNATURE="$filtered"
    if (( did_change )); then
        _COTERM_TTY_REPORTED=0
        _COTERM_SHELL_ACTIVITY_LAST=""
        _COTERM_PWD_LAST_PWD=""
        _COTERM_GIT_LAST_PWD=""
        _COTERM_GIT_HEAD_LAST_PWD=""
        _COTERM_GIT_HEAD_PATH=""
        _COTERM_GIT_HEAD_SIGNATURE=""
        _COTERM_GIT_FORCE=1
        _COTERM_PR_FORCE=1
        _coterm_stop_pr_poll_loop
        _coterm_stop_git_head_watch
    fi
}

_coterm_tmux_sync_coterm_environment() {
    if [[ -n "$TMUX" ]]; then
        _coterm_tmux_refresh_coterm_environment
    else
        _coterm_tmux_publish_coterm_environment
    fi
}

_coterm_ensure_ghostty_preexec_strips_both_marks() {
    local fn_name="$1"
    (( $+functions[$fn_name] )) || return 0

    local old_strip new_strip updated
    old_strip=$'PS1=${PS1//$\'%{\\e]133;A;cl=line\\a%}\'}'
    new_strip=$'PS1=${PS1//$\'%{\\e]133;A;redraw=last;cl=line\\a%}\'}'
    updated="${functions[$fn_name]}"

    if [[ "$updated" == *"$new_strip"* && "$updated" != *"$old_strip"* ]]; then
        updated="${updated/$new_strip/$old_strip
        $new_strip}"
        functions[$fn_name]="$updated"
        _COTERM_GHOSTTY_SEMANTIC_PATCHED=1
        return 0
    fi
    if [[ "$updated" == *"$old_strip"* && "$updated" != *"$new_strip"* ]]; then
        updated="${updated/$old_strip/$old_strip
        $new_strip}"
        functions[$fn_name]="$updated"
        _COTERM_GHOSTTY_SEMANTIC_PATCHED=1
    fi
}

_coterm_patch_ghostty_semantic_redraw() {
    local old_frag new_frag
    old_frag='133;A;cl=line'
    new_frag='133;A;redraw=last;cl=line'

    # Patch both deferred and live hook definitions, depending on init timing.
    if (( $+functions[_ghostty_deferred_init] )); then
        functions[_ghostty_deferred_init]="${functions[_ghostty_deferred_init]//$old_frag/$new_frag}"
        _COTERM_GHOSTTY_SEMANTIC_PATCHED=1
    fi
    if (( $+functions[_ghostty_precmd] )); then
        functions[_ghostty_precmd]="${functions[_ghostty_precmd]//$old_frag/$new_frag}"
        _COTERM_GHOSTTY_SEMANTIC_PATCHED=1
    fi
    if (( $+functions[_ghostty_preexec] )); then
        functions[_ghostty_preexec]="${functions[_ghostty_preexec]//$old_frag/$new_frag}"
        _COTERM_GHOSTTY_SEMANTIC_PATCHED=1
    fi

    # Keep legacy + redraw-aware strip lines so prompts created before patching
    # are still cleared by preexec.
    _coterm_ensure_ghostty_preexec_strips_both_marks _ghostty_deferred_init
    _coterm_ensure_ghostty_preexec_strips_both_marks _ghostty_preexec
}
_coterm_patch_ghostty_semantic_redraw

_coterm_prepend_job_table_guard_to_function() {
    local fn_name="$1"
    (( $+functions[$fn_name] )) || return 0
    local saved_var="__coterm_${fn_name}_saved_status"
    [[ "${functions[$fn_name]}" == *"$saved_var"* ]] && return 0

    functions[$fn_name]="builtin local ${saved_var}=\$?
_coterm_zsh_job_table_saturated && builtin return 0
_coterm_restore_status \"\$${saved_var}\"
${functions[$fn_name]}"
}

_coterm_insert_job_table_guard_after_declaration() {
    builtin emulate -L zsh -o extended_glob -o no_aliases

    local fn_name="$1"
    local target_name="$2"
    local guard="$3"
    (( $+functions[$fn_name] )) || return 0

    local body="${functions[$fn_name]}"
    [[ "$body" == *"$guard"* ]] && return 0

    local -a lines patched_lines declaration_names
    lines=("${(@f)body}")
    local line trimmed declaration candidate
    local inserted=0

    for line in "${lines[@]}"; do
        patched_lines+=("$line")
        (( inserted )) && continue

        trimmed="${line##[[:space:]]#}"
        [[ "$trimmed" == *"{"* ]] || continue

        declaration="${trimmed%%\{}"
        declaration="${declaration//\(\)/ }"
        if [[ "$declaration" == function[[:space:]]* ]]; then
            declaration="${declaration#function}"
        fi
        declaration_names=("${(@z)declaration}")

        for candidate in "${declaration_names[@]}"; do
            if [[ "$candidate" == "$target_name" ]]; then
                patched_lines+=("${(@f)guard}")
                inserted=1
                break
            fi
        done
    done

    (( inserted )) || return 0
    functions[$fn_name]="${(F)patched_lines}"
}

_coterm_patch_ghostty_job_table_guard() {
    local guard_precmd=$'        builtin local __coterm__ghostty_precmd_saved_status=$?\n        _coterm_zsh_job_table_saturated && builtin return 0\n        _coterm_restore_status "$__coterm__ghostty_precmd_saved_status"'
    local guard_preexec=$'        builtin local __coterm__ghostty_preexec_saved_status=$?\n        _coterm_zsh_job_table_saturated && builtin return 0\n        _coterm_restore_status "$__coterm__ghostty_preexec_saved_status"'
    local guard_zle_init=$'          builtin local __coterm__ghostty_zle_line_init_saved_status=$?\n          _coterm_zsh_job_table_saturated && builtin return 0\n          _coterm_restore_status "$__coterm__ghostty_zle_line_init_saved_status"'
    local guard_zle_finish=$'          builtin local __coterm__ghostty_zle_line_finish_saved_status=$?\n          _coterm_zsh_job_table_saturated && builtin return 0\n          _coterm_restore_status "$__coterm__ghostty_zle_line_finish_saved_status"'
    local guard_zle_keymap=$'          builtin local __coterm__ghostty_zle_keymap_select_saved_status=$?\n          _coterm_zsh_job_table_saturated && builtin return 0\n          _coterm_restore_status "$__coterm__ghostty_zle_keymap_select_saved_status"'

    # Patch deferred definitions before Ghostty's first precmd installs and
    # invokes its live hook functions.
    if (( $+functions[_ghostty_deferred_init] )); then
        _coterm_insert_job_table_guard_after_declaration _ghostty_deferred_init _ghostty_precmd "$guard_precmd"
        _coterm_insert_job_table_guard_after_declaration _ghostty_deferred_init _ghostty_preexec "$guard_preexec"
        _coterm_insert_job_table_guard_after_declaration _ghostty_deferred_init _ghostty_zle_line_init "$guard_zle_init"
        _coterm_insert_job_table_guard_after_declaration _ghostty_deferred_init _ghostty_zle_line_finish "$guard_zle_finish"
        _coterm_insert_job_table_guard_after_declaration _ghostty_deferred_init _ghostty_zle_keymap_select "$guard_zle_keymap"
    fi

    _coterm_prepend_job_table_guard_to_function _ghostty_precmd
    _coterm_prepend_job_table_guard_to_function _ghostty_preexec
    _coterm_prepend_job_table_guard_to_function _ghostty_zle_line_init
    _coterm_prepend_job_table_guard_to_function _ghostty_zle_line_finish
    _coterm_prepend_job_table_guard_to_function _ghostty_zle_keymap_select
}
_coterm_patch_ghostty_job_table_guard

_coterm_prompt_wrap_guard() {
    local cmd_start="$1"
    local pwd="$2"
    [[ -n "$cmd_start" && "$cmd_start" != 0 ]] || return 0

    local cols="${COLUMNS:-0}"
    (( cols > 0 )) || return 0

    local budget=$(( cols - 24 ))
    (( budget < 20 )) && budget=20
    (( ${#pwd} >= budget )) || return 0

    # Keep a spacer line between command output and a wrapped prompt so
    # resize-driven prompt redraw cannot overwrite the command tail.
    builtin print -r -- ""
}

_coterm_install_winch_guard() {
    (( _COTERM_WINCH_GUARD_INSTALLED )) && return 0

    # Respect user-defined WINCH handlers (function-based or trap-based).
    local existing_winch_trap=""
    existing_winch_trap="$(trap -p WINCH 2>/dev/null || true)"
    if (( $+functions[TRAPWINCH] )) || [[ -n "$existing_winch_trap" ]]; then
        _COTERM_WINCH_GUARD_INSTALLED=1
        return 0
    fi

    TRAPWINCH() {
        [[ -n "$COTERM_TAB_ID" ]] || return 0
        [[ -n "$COTERM_PANEL_ID" ]] || return 0

        # Ghostty already marks prompt redraws on SIGWINCH. Writing to the PTY
        # here grows the screen and makes resize look like a fresh prompt.
        return 0
    }

    _COTERM_WINCH_GUARD_INSTALLED=1
}
_coterm_install_winch_guard

_coterm_git_resolve_head_path() {
    # Resolve the HEAD file path without invoking git (fast; works for worktrees).
    local dir="${1:-$PWD}"
    while true; do
        if [[ -d "$dir/.git" ]]; then
            print -r -- "$dir/.git/HEAD"
            return 0
        fi
        if [[ -f "$dir/.git" ]]; then
            local line gitdir
            line="$(<"$dir/.git")"
            if [[ "$line" == gitdir:* ]]; then
                gitdir="${line#gitdir:}"
                gitdir="${gitdir## }"
                gitdir="${gitdir%% }"
                [[ -n "$gitdir" ]] || return 1
                [[ "$gitdir" != /* ]] && gitdir="$dir/$gitdir"
                print -r -- "$gitdir/HEAD"
                return 0
            fi
        fi
        [[ "$dir" == "/" || -z "$dir" ]] && break
        dir="${dir:h}"
    done
    return 1
}

_coterm_git_resolve_git_dir() {
    local repo_path="${1:-$PWD}"
    local head_path
    head_path="$(_coterm_git_resolve_head_path "$repo_path" 2>/dev/null || true)"
    [[ -n "$head_path" ]] || return 1
    print -r -- "${head_path:h}"
}

_coterm_git_head_signature() {
    local head_path="$1"
    [[ -n "$head_path" && -r "$head_path" ]] || return 1
    local line=""
    if IFS= read -r line < "$head_path"; then
        print -r -- "$line"
        return 0
    fi
    return 1
}

_coterm_git_branch_for_path() {
    local repo_path="$1"
    local head_path="" head_line="" prefix="ref: refs/heads/"
    head_path="$(_coterm_git_resolve_head_path "$repo_path" 2>/dev/null || true)"
    [[ -n "$head_path" && -r "$head_path" ]] || return 1
    head_line="$(<"$head_path")"
    [[ "$head_line" == "$prefix"* ]] || return 1
    print -r -- "${head_line#$prefix}"
}

_coterm_set_git_active_pwd() {
    local active_pwd="$1"
    [[ -n "$active_pwd" ]] || return 0
    [[ -n "${_COTERM_GIT_ACTIVE_PWD_FILE:-}" ]] || return 0
    print -r -- "$active_pwd" >| "$_COTERM_GIT_ACTIVE_PWD_FILE" 2>/dev/null || true
}

_coterm_git_report_path_is_active() {
    local repo_path="$1"
    [[ -n "$repo_path" ]] || return 1
    [[ -n "${_COTERM_GIT_ACTIVE_PWD_FILE:-}" ]] || return 0
    [[ -r "$_COTERM_GIT_ACTIVE_PWD_FILE" ]] || return 0

    local active_pwd=""
    IFS= read -r active_pwd < "$_COTERM_GIT_ACTIVE_PWD_FILE" || active_pwd=""
    # No recorded cwd yet, or the report targets the current cwd exactly: allow.
    [[ -z "$active_pwd" || "$repo_path" == "$active_pwd" ]] && return 0

    # Otherwise the report is valid only when the current cwd is in the SAME
    # repository as repo_path. This keeps live branch updates flowing after an
    # in-repo `cd pkg` (the HEAD watch still reports the preexec watch_pwd) while
    # still dropping a report once the shell has left the repo entirely (the
    # stale-branch case). Resolve both HEAD paths without invoking git and compare.
    local repo_head active_head
    repo_head="$(_coterm_git_resolve_head_path "$repo_path" 2>/dev/null || true)"
    active_head="$(_coterm_git_resolve_head_path "$active_pwd" 2>/dev/null || true)"
    [[ -n "$repo_head" && "$repo_head" == "$active_head" ]]
}

_coterm_report_tty_payload() {
    [[ -n "$COTERM_TAB_ID" ]] || return 0
    [[ -n "$_COTERM_TTY_NAME" ]] || return 0

    local payload="report_tty $_COTERM_TTY_NAME --tab=$COTERM_TAB_ID"
    if [[ -z "$TMUX" ]]; then
        [[ -n "$COTERM_PANEL_ID" ]] || return 0
        payload+=" --panel=$COTERM_PANEL_ID"
    fi

    print -r -- "$payload"
}

_coterm_report_tty_once() {
    # Send the TTY name to the app once per session so the batched port scanner
    # knows which TTY belongs to this panel.
    (( _COTERM_TTY_REPORTED )) && return 0
    _coterm_has_port_scan_transport || return 0

    if _coterm_socket_is_unix; then
        local payload=""
        payload="$(_coterm_report_tty_payload)"
        [[ -n "$payload" ]] || return 0
        _COTERM_TTY_REPORTED=1
        _coterm_send_bg "$payload"
    else
        [[ -n "$_COTERM_TTY_NAME" ]] || return 0
        # Keep the first relay TTY report synchronous so the server can resolve
        # the target surface before command-start kicks begin their scan burst.
        _coterm_report_tty_via_relay || return 0
        _COTERM_TTY_REPORTED=1
    fi
}

_coterm_report_shell_activity_state() {
    local state="$1"
    [[ -n "$state" ]] || return 0
    [[ -S "$COTERM_SOCKET_PATH" ]] || return 0
    [[ -n "$COTERM_TAB_ID" ]] || return 0
    [[ -n "$COTERM_PANEL_ID" ]] || return 0
    [[ "$_COTERM_SHELL_ACTIVITY_LAST" == "$state" ]] && return 0
    _COTERM_SHELL_ACTIVITY_LAST="$state"
    _coterm_send_bg "report_shell_state $state --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID"
}

_coterm_reset_terminal_keyboard_protocols() {
    [[ -t 1 || -n "${COTERM_TEST_FORCE_KEYBOARD_RESET:-}${COTERM_TEST_FORCE_KITTY_RESET:-}" ]] || return 0
    # A crashed TUI may leave input-reporting modes pushed. At a fresh shell
    # prompt, return terminal input encoding/click reporting to plain readline bytes.
    printf '\033[>m\033[<8u\033[?9l\033[?1000l\033[?1002l\033[?1003l\033[?1005l\033[?1006l\033[?1004l\033[?2004l\033[?2026l'
}

_coterm_ports_kick() {
    local reason="${1:-command}"
    # Lightweight: just tell the app to run a batched scan for this panel.
    # The app coalesces kicks across all panels and runs a single ps+lsof.
    _coterm_has_port_scan_transport || return 0
    [[ -n "$COTERM_TAB_ID" ]] || return 0
    if _coterm_socket_is_unix; then
        [[ -n "$COTERM_PANEL_ID" ]] || return 0
    fi
    _COTERM_PORTS_LAST_RUN="$(_coterm_now)"
    if _coterm_socket_is_unix; then
        _coterm_send_bg "ports_kick --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID --reason=$reason"
    else
        _coterm_ports_kick_via_relay "$reason"
    fi
}

_coterm_report_git_branch_for_path() {
    local repo_path="$1"
    [[ "${COTERM_NO_GIT_WATCH:-}" == "1" ]] && return 0
    [[ -n "$repo_path" ]] || return 0
    [[ -S "$COTERM_SOCKET_PATH" ]] || return 0
    [[ -n "$COTERM_TAB_ID" ]] || return 0
    [[ -n "$COTERM_PANEL_ID" ]] || return 0
    _coterm_git_report_path_is_active "$repo_path" || return 0

    local branch dirty_opt="--status=unknown"
    branch="$(_coterm_git_branch_for_path "$repo_path" 2>/dev/null || true)"
    _coterm_git_report_path_is_active "$repo_path" || return 0
    if [[ -n "$branch" ]]; then
        _coterm_send "report_git_branch $branch $dirty_opt --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID"
    else
        _coterm_send "clear_git_branch --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID"
    fi
}

_coterm_record_pr_command_hint() {
    local cmd="$1"
    _COTERM_LAST_PR_ACTION=""
    _COTERM_LAST_PR_TARGET=""

    local -a words
    words=("${(z)cmd}")

    local index=1
    local word base
    while (( index <= ${#words} )); do
        word="${words[index]}"

        case "$word" in
            *=*)
                index=$(( index + 1 ))
                continue ;;
            exec|command|builtin|noglob|time)
                index=$(( index + 1 ))
                continue ;;
            env)
                index=$(( index + 1 ))
                while (( index <= ${#words} )); do
                    word="${words[index]}"
                    case "$word" in
                        -*|*=*)
                            index=$(( index + 1 ))
                            continue ;;
                    esac
                    break
                done
                continue ;;
        esac

        base="${word:t}"
        [[ "$base" == "gh" ]] || return 0
        index=$(( index + 1 ))
        break
    done

    (( index + 1 <= ${#words} )) || return 0
    [[ "${words[index]}" == "pr" ]] || return 0
    local action="${words[index + 1]:l}"
    case "$action" in
        merge|close|reopen|create|checkout|ready|edit|view)
            _COTERM_LAST_PR_ACTION="$action" ;;
        *)
            return 0 ;;
    esac

    index=$(( index + 2 ))
    while (( index <= ${#words} )); do
        word="${words[index]}"
        case "$word" in
            --*=*)
                index=$(( index + 1 ))
                continue ;;
            --*)
                index=$(( index + 2 ))
                continue ;;
            -*)
                index=$(( index + 1 ))
                continue ;;
            *)
                _COTERM_LAST_PR_TARGET="$word"
                break ;;
        esac
    done
}

_coterm_emit_pr_command_hint() {
    [[ "${COTERM_NO_PR_WATCH:-}" == "1" ]] && return 0
    [[ -S "$COTERM_SOCKET_PATH" ]] || return 0
    [[ -n "$COTERM_TAB_ID" ]] || return 0
    [[ -n "$COTERM_PANEL_ID" ]] || return 0
    [[ -n "$_COTERM_LAST_PR_ACTION" ]] || return 0

    local payload="report_pr_action $_COTERM_LAST_PR_ACTION --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID"
    if [[ -n "$_COTERM_LAST_PR_TARGET" ]]; then
        local quoted_target="${_COTERM_LAST_PR_TARGET//\"/\\\"}"
        payload+=" --target=\"$quoted_target\""
    fi
    _coterm_send_bg "$payload"
    _COTERM_LAST_PR_ACTION=""
    _COTERM_LAST_PR_TARGET=""
}

_coterm_clear_pr_for_panel() {
    [[ "${COTERM_NO_GIT_WATCH:-}" == "1" ]] && return 0
    [[ -S "$COTERM_SOCKET_PATH" ]] || return 0
    [[ -n "$COTERM_TAB_ID" ]] || return 0
    [[ -n "$COTERM_PANEL_ID" ]] || return 0
    _coterm_send_bg "clear_pr --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID"
}

_coterm_pr_output_indicates_no_pull_request() {
    local output="${1:l}"
    [[ "$output" == *"no pull requests found"* \
        || "$output" == *"no pull request found"* \
        || "$output" == *"no pull requests associated"* \
        || "$output" == *"no pull request associated"* ]]
}

_coterm_git_config_resolve_include_path() {
    local path="$1" config_dir="$2"
    case "$path" in
        "~")
            printf '%s\n' "$HOME" ;;
        "~/"*)
            printf '%s/%s\n' "$HOME" "${path#~/}" ;;
        /*)
            printf '%s\n' "$path" ;;
        *)
            printf '%s/%s\n' "$config_dir" "$path" ;;
    esac
}

_coterm_git_config_gitdir_pattern_matches() {
    local pattern="$1" repo_path="$2" git_dir="$3" common_dir="$4" case_insensitive="$5"
    local expanded="$pattern" candidate cmp_candidate cmp_pattern prefix

    case "$expanded" in
        "~")
            expanded="$HOME" ;;
        "~/"*)
            expanded="$HOME/${expanded#~/}" ;;
    esac
    if [[ "$expanded" == */ ]]; then
        prefix="$expanded"
        [[ "$case_insensitive" == "1" ]] && prefix="$(printf '%s' "$prefix" | tr '[:upper:]' '[:lower:]')"
        for candidate in "$git_dir" "$common_dir" "$repo_path"; do
            cmp_candidate="$candidate"
            [[ "$case_insensitive" == "1" ]] && cmp_candidate="$(printf '%s' "$cmp_candidate" | tr '[:upper:]' '[:lower:]')"
            [[ "$cmp_candidate" == "${prefix%/}" || "$cmp_candidate/" == "$prefix"* ]] && return 0
        done
        return 1
    fi
    if [[ "$expanded" == */'**' ]]; then
        prefix="${expanded%/\*\*}/"
        [[ "$case_insensitive" == "1" ]] && prefix="$(printf '%s' "$prefix" | tr '[:upper:]' '[:lower:]')"
        for candidate in "$git_dir" "$common_dir" "$repo_path"; do
            cmp_candidate="$candidate"
            [[ "$case_insensitive" == "1" ]] && cmp_candidate="$(printf '%s' "$cmp_candidate" | tr '[:upper:]' '[:lower:]')"
            [[ "$cmp_candidate" == "${prefix%/}" || "$cmp_candidate/" == "$prefix"* ]] && return 0
        done
        return 1
    fi

    cmp_pattern="$expanded"
    [[ "$case_insensitive" == "1" ]] && cmp_pattern="$(printf '%s' "$cmp_pattern" | tr '[:upper:]' '[:lower:]')"
    for candidate in "$git_dir" "$common_dir" "$repo_path"; do
        cmp_candidate="$candidate"
        [[ "$case_insensitive" == "1" ]] && cmp_candidate="$(printf '%s' "$cmp_candidate" | tr '[:upper:]' '[:lower:]')"
        [[ "$cmp_candidate" == $cmp_pattern || "$cmp_candidate/" == $cmp_pattern ]] && return 0
    done
    return 1
}

_coterm_git_config_include_condition_matches() {
    local condition="$1" repo_path="$2" git_dir="$3" common_dir="$4"
    local lower pattern
    lower="$(printf '%s' "$condition" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        gitdir/i:*)
            pattern="${condition#gitdir/i:}"
            _coterm_git_config_gitdir_pattern_matches "$pattern" "$repo_path" "$git_dir" "$common_dir" 1 ;;
        gitdir:*)
            pattern="${condition#gitdir:}"
            _coterm_git_config_gitdir_pattern_matches "$pattern" "$repo_path" "$git_dir" "$common_dir" 0 ;;
        *)
            return 1 ;;
    esac
}

_coterm_git_origin_url_read_config_file() {
    local repo_path="$1" git_dir="$2" common_dir="$3" config_file="$4"
    local config_dir="" output=""
    local kind="" entry_payload="" entry_value="" include_path=""

    [[ -r "$config_file" ]] || return 0
    case "$_coterm_git_origin_url_seen" in
        *$'\n'"$config_file"$'\n'*) return 0 ;;
    esac
    _coterm_git_origin_url_depth=$(( _coterm_git_origin_url_depth + 1 ))
    [[ "$_coterm_git_origin_url_depth" -le 32 ]] || return 0
    _coterm_git_origin_url_seen+="$config_file"$'\n'

    config_dir="$(dirname "$config_file")"
    output="$(awk '
        function trim(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }
        function strip_inline_comment(s, i, c, out, previous_was_space, in_quote, escaped) {
            out = ""
            previous_was_space = 1
            in_quote = 0
            escaped = 0
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                if (escaped) {
                    out = out c
                    escaped = 0
                    previous_was_space = (c ~ /[[:space:]]/)
                    continue
                }
                if (in_quote && c == "\\") {
                    out = out c
                    escaped = 1
                    previous_was_space = 0
                    continue
                }
                if (c == "\"") {
                    out = out c
                    in_quote = !in_quote
                    previous_was_space = 0
                    continue
                }
                if (!in_quote && previous_was_space && (c == "#" || c == ";")) {
                    break
                }
                out = out c
                previous_was_space = (c ~ /[[:space:]]/)
            }
            return out
        }
        function unquote_config_value(s, i, c, out, escaped) {
            s = trim(s)
            if (length(s) >= 2 && substr(s, 1, 1) == "\"" && substr(s, length(s), 1) == "\"") {
                out = ""
                escaped = 0
                for (i = 2; i < length(s); i++) {
                    c = substr(s, i, 1)
                    if (escaped) {
                        out = out c
                        escaped = 0
                        continue
                    }
                    if (c == "\\") {
                        escaped = 1
                        continue
                    }
                    out = out c
                }
                if (escaped) {
                    out = out "\\"
                }
                return out
            }
            return s
        }
        function path_value(line) {
            sub(/^[^=]*=/, "", line)
            return unquote_config_value(line)
        }
        {
            line = strip_inline_comment($0)
            trimmed = trim(line)
            if (trimmed ~ /^\[remote[[:space:]]+"origin"\][[:space:]]*$/) {
                section = "remote"
                condition = ""
                next
            }
            if (trimmed == "[include]") {
                section = "include"
                condition = ""
                next
            }
            if (trimmed ~ /^\[includeIf[[:space:]]+"/) {
                section = "includeIf"
                condition = trimmed
                sub(/^\[includeIf[[:space:]]+"/, "", condition)
                sub(/"\][[:space:]]*$/, "", condition)
                next
            }
            if (trimmed ~ /^\[/) {
                section = ""
                condition = ""
                next
            }
            if (section == "remote" && line ~ /^[[:space:]]*url[[:space:]]*=/) {
                print "remote\t" path_value(line) "\t"
            }
            if (section == "include" && line ~ /^[[:space:]]*path[[:space:]]*=/) {
                print "include\t" path_value(line) "\t"
            }
            if (section == "includeIf" && line ~ /^[[:space:]]*path[[:space:]]*=/) {
                print "includeIf\t" condition "\t" path_value(line)
            }
        }
    ' "$config_file" 2>/dev/null)"

    while IFS=$'\t' read -r kind entry_payload entry_value; do
        case "$kind" in
            remote)
                [[ -n "$entry_payload" ]] && _coterm_git_origin_url_result="$entry_payload" ;;
            include)
                include_path="$(_coterm_git_config_resolve_include_path "$entry_payload" "$config_dir")"
                [[ -r "$include_path" ]] && _coterm_git_origin_url_read_config_file "$repo_path" "$git_dir" "$common_dir" "$include_path" ;;
            includeIf)
                if _coterm_git_config_include_condition_matches "$entry_payload" "$repo_path" "$git_dir" "$common_dir"; then
                    include_path="$(_coterm_git_config_resolve_include_path "$entry_value" "$config_dir")"
                    [[ -r "$include_path" ]] && _coterm_git_origin_url_read_config_file "$repo_path" "$git_dir" "$common_dir" "$include_path"
                fi ;;
        esac
    done <<< "$output"
}

_coterm_git_origin_url_from_config_files() {
    local repo_path="$1" git_dir="$2" common_dir="$3"
    local _coterm_git_origin_url_seen=$'\n'
    local _coterm_git_origin_url_depth=0
    local _coterm_git_origin_url_result=""

    [[ -r "$common_dir/config" ]] && _coterm_git_origin_url_read_config_file "$repo_path" "$git_dir" "$common_dir" "$common_dir/config"
    [[ "$git_dir" != "$common_dir" && -r "$git_dir/config" ]] && _coterm_git_origin_url_read_config_file "$repo_path" "$git_dir" "$common_dir" "$git_dir/config"
    [[ -n "$_coterm_git_origin_url_result" ]] && printf '%s\n' "$_coterm_git_origin_url_result"
}

_coterm_github_repo_slug_for_path() {
    local repo_path="$1"
    local git_dir="" common_dir="" remote_url="" path_part=""
    [[ -n "$repo_path" ]] || return 0

    git_dir="$(_coterm_git_resolve_git_dir "$repo_path" 2>/dev/null || true)"
    [[ -n "$git_dir" ]] || return 0
    common_dir="$git_dir"
    if [[ -r "$git_dir/commondir" ]]; then
        common_dir="$(<"$git_dir/commondir")"
        common_dir="${common_dir## }"
        common_dir="${common_dir%% }"
        [[ "$common_dir" != /* ]] && common_dir="$git_dir/$common_dir"
    fi
    remote_url="$(_coterm_git_origin_url_from_config_files "$repo_path" "$git_dir" "$common_dir")"
    [[ -n "$remote_url" ]] || return 0

    case "$remote_url" in
        git@github.com:*)
            path_part="${remote_url#git@github.com:}"
            ;;
        ssh://git@github.com/*)
            path_part="${remote_url#ssh://git@github.com/}"
            ;;
        https://github.com/*)
            path_part="${remote_url#https://github.com/}"
            ;;
        http://github.com/*)
            path_part="${remote_url#http://github.com/}"
            ;;
        git://github.com/*)
            path_part="${remote_url#git://github.com/}"
            ;;
        *)
            return 0
            ;;
    esac

    path_part="${path_part%.git}"
    [[ "$path_part" == */* ]] || return 0
    print -r -- "$path_part"
}

_coterm_pr_cache_prefix() {
    [[ -n "$COTERM_PANEL_ID" ]] || return 1
    print -r -- "/tmp/coterm-pr-cache-${COTERM_PANEL_ID}"
}

_coterm_pr_force_signal_path() {
    [[ -n "$COTERM_PANEL_ID" ]] || return 1
    print -r -- "/tmp/coterm-pr-force-${COTERM_PANEL_ID}"
}

_coterm_pr_debug_log() {
    (( _COTERM_PR_DEBUG )) || return 0

    local branch="$1"
    local event="$2"
    local now="${EPOCHSECONDS:-$SECONDS}"
    printf '%s\tbranch=%s\tevent=%s\n' "$now" "$branch" "$event" >> /tmp/coterm-pr-debug.log
}

_coterm_pr_cache_clear() {
    local prefix=""
    prefix="$(_coterm_pr_cache_prefix 2>/dev/null || true)"
    if [[ -n "$prefix" ]]; then
        /bin/rm -f -- \
            "${prefix}.branch" \
            "${prefix}.repo" \
            "${prefix}.result" \
            "${prefix}.timestamp" \
            "${prefix}.no-pr-branch" \
            >/dev/null 2>&1 || true
    fi

    _COTERM_PR_LAST_BRANCH=""
    _COTERM_PR_NO_PR_BRANCH=""
}

_coterm_pr_request_probe() {
    local signal_path=""
    signal_path="$(_coterm_pr_force_signal_path 2>/dev/null || true)"
    [[ -n "$signal_path" ]] || return 0
    : >| "$signal_path"
}

_coterm_report_pr_for_path() {
    local repo_path="$1"
    local force_probe="${2:-0}"
    if [[ "${COTERM_NO_PR_WATCH:-}" == "1" ]]; then
        _coterm_pr_cache_clear
        _coterm_clear_pr_for_panel
        return 0
    fi
    [[ -n "$repo_path" ]] || {
        _coterm_pr_cache_clear
        _coterm_clear_pr_for_panel
        return 0
    }
    [[ -d "$repo_path" ]] || {
        _coterm_pr_cache_clear
        _coterm_clear_pr_for_panel
        return 0
    }
    [[ -S "$COTERM_SOCKET_PATH" ]] || return 0
    [[ -n "$COTERM_TAB_ID" ]] || return 0
    [[ -n "$COTERM_PANEL_ID" ]] || return 0

    local branch repo_slug="" gh_output="" gh_error="" err_file="" number state url status_opt="" gh_status
    local now="${EPOCHSECONDS:-$SECONDS}"
    local prefix="" branch_file="" repo_file="" result_file="" timestamp_file="" no_pr_branch_file=""
    local cache_branch="" cache_result="" cache_no_pr_branch=""
    local -a gh_repo_args
    gh_repo_args=()
    branch="$(_coterm_git_branch_for_path "$repo_path" 2>/dev/null || true)"
    if [[ -z "$branch" ]] || ! command -v gh >/dev/null 2>&1; then
        _coterm_pr_debug_log "$branch" "cache-miss:clear"
        _coterm_pr_cache_clear
        _coterm_clear_pr_for_panel
        return 0
    fi

    prefix="$(_coterm_pr_cache_prefix 2>/dev/null || true)"
    if [[ -n "$prefix" ]]; then
        branch_file="${prefix}.branch"
        repo_file="${prefix}.repo"
        result_file="${prefix}.result"
        timestamp_file="${prefix}.timestamp"
        no_pr_branch_file="${prefix}.no-pr-branch"
        [[ -r "$branch_file" ]] && cache_branch="$(<"$branch_file")"
        [[ -r "$result_file" ]] && cache_result="$(<"$result_file")"
        [[ -r "$no_pr_branch_file" ]] && cache_no_pr_branch="$(<"$no_pr_branch_file")"
    fi

    _COTERM_PR_LAST_BRANCH="$cache_branch"
    _COTERM_PR_NO_PR_BRANCH="$cache_no_pr_branch"
    if [[ "$cache_branch" == "$branch" && -n "$cache_result" ]]; then
        _coterm_pr_debug_log "$branch" "cache-refresh"
    else
        _coterm_pr_debug_log "$branch" "cache-miss"
    fi

    repo_slug="$(_coterm_github_repo_slug_for_path "$repo_path")"
    if [[ -n "$repo_slug" ]]; then
        gh_repo_args=(--repo "$repo_slug")
    fi

    err_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/coterm-gh-pr-view.XXXXXX" 2>/dev/null || true)"
    [[ -n "$err_file" ]] || return 1
    gh_output="$(
        builtin cd "$repo_path" 2>/dev/null \
            && gh pr view "$branch" \
                "${gh_repo_args[@]}" \
                --json number,state,url \
                --jq '[.number, .state, .url] | @tsv' \
                2>"$err_file"
    )"
    gh_status=$?
    if [[ -f "$err_file" ]]; then
        gh_error="$("/bin/cat" -- "$err_file" 2>/dev/null || true)"
        /bin/rm -f -- "$err_file" >/dev/null 2>&1 || true
    fi

    if (( gh_status != 0 )) || [[ -z "$gh_output" ]]; then
        if (( gh_status == 0 )) && [[ -z "$gh_output" ]]; then
            if [[ -n "$prefix" ]]; then
                print -r -- "$branch" >| "$branch_file"
                print -r -- "$repo_path" >| "$repo_file"
                print -r -- "$now" >| "$timestamp_file"
                print -r -- "none" >| "$result_file"
                print -r -- "$branch" >| "$no_pr_branch_file"
            fi
            _COTERM_PR_LAST_BRANCH="$branch"
            _COTERM_PR_NO_PR_BRANCH="$branch"
            _coterm_clear_pr_for_panel
            return 0
        fi
        if _coterm_pr_output_indicates_no_pull_request "$gh_error"; then
            if [[ -n "$prefix" ]]; then
                print -r -- "$branch" >| "$branch_file"
                print -r -- "$repo_path" >| "$repo_file"
                print -r -- "$now" >| "$timestamp_file"
                print -r -- "none" >| "$result_file"
                print -r -- "$branch" >| "$no_pr_branch_file"
            fi
            _COTERM_PR_LAST_BRANCH="$branch"
            _COTERM_PR_NO_PR_BRANCH="$branch"
            _coterm_clear_pr_for_panel
            return 0
        fi

        # Always scope PR detection to the exact current branch. When gh fails
        # transiently (auth hiccups, API lag, rate limiting), keep the last-known
        # badge and retry on the next poll instead of showing a mismatched PR.
        return 1
    fi

    local IFS=$'\t'
    read -r number state url <<< "$gh_output"
    if [[ -z "$number" ]] || [[ -z "$url" ]]; then
        return 1
    fi

    case "$state" in
        MERGED) status_opt="--state=merged" ;;
        OPEN) status_opt="--state=open" ;;
        CLOSED) status_opt="--state=closed" ;;
        *) return 1 ;;
    esac

    if [[ -n "$prefix" ]]; then
        print -r -- "$branch" >| "$branch_file"
        print -r -- "$repo_path" >| "$repo_file"
        print -r -- "$now" >| "$timestamp_file"
        printf '%s\t%s\t%s\t%s\n' "pr" "$number" "$state" "$url" >| "$result_file"
        /bin/rm -f -- "$no_pr_branch_file" >/dev/null 2>&1 || true
    fi
    _COTERM_PR_LAST_BRANCH="$branch"
    _COTERM_PR_NO_PR_BRANCH=""

    local quoted_branch="${branch//\"/\\\"}"
    _coterm_send "report_pr $number $url $status_opt --branch=\"$quoted_branch\" --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID"
}

_coterm_child_pids() {
    local parent_pid="$1"
    [[ -n "$parent_pid" ]] || return 0
    /bin/ps -ax -o pid= -o ppid= 2>/dev/null | /usr/bin/awk -v parent="$parent_pid" '$2 == parent { print $1 }'
}

_coterm_kill_process_tree() {
    local pid="$1"
    local signal="${2:-TERM}"
    local child_pid=""
    [[ -n "$pid" ]] || return 0

    while IFS= read -r child_pid; do
        [[ -n "$child_pid" ]] || continue
        [[ "$child_pid" == "$pid" ]] && continue
        _coterm_kill_process_tree "$child_pid" "$signal"
    done < <(_coterm_child_pids "$pid")

    kill "-$signal" "$pid" >/dev/null 2>&1 || true
}

_coterm_run_pr_probe_with_timeout() {
    local repo_path="$1"
    local force_probe="${2:-0}"
    local probe_pid=""
    local started_at="${EPOCHSECONDS:-$SECONDS}"
    local now=$started_at

    _coterm_zsh_job_table_saturated && return 1

    (
        _coterm_report_pr_for_path "$repo_path" "$force_probe"
    ) &
    probe_pid=$!

    while kill -0 "$probe_pid" >/dev/null 2>&1; do
        sleep 1
        now="${EPOCHSECONDS:-$SECONDS}"
        if (( _COTERM_ASYNC_JOB_TIMEOUT > 0 )) && (( now - started_at >= _COTERM_ASYNC_JOB_TIMEOUT )); then
            _coterm_kill_process_tree "$probe_pid" TERM
            sleep 0.2
            if kill -0 "$probe_pid" >/dev/null 2>&1; then
                _coterm_kill_process_tree "$probe_pid" KILL
                sleep 0.2
            fi
            if ! kill -0 "$probe_pid" >/dev/null 2>&1; then
                wait "$probe_pid" >/dev/null 2>&1 || true
            fi
            return 1
        fi
    done

    wait "$probe_pid"
}

_coterm_halt_pr_poll_loop() {
    # Process-group kill: background jobs are process-group leaders, so
    # negative PID kills the loop + all descendants (gh, sleep) without
    # the synchronous /bin/ps + awk of tree-kill (~5-13ms).
    [[ -z "$_COTERM_PR_POLL_PID" ]] || kill -KILL -- -"$_COTERM_PR_POLL_PID" 2>/dev/null || true
    local signal_path=""
    [[ -n "$COTERM_PANEL_ID" ]] && signal_path="/tmp/coterm-pr-force-${COTERM_PANEL_ID}"
    [[ -z "$signal_path" ]] || /bin/rm -f -- "$signal_path" >/dev/null 2>&1 || true
    _COTERM_PR_POLL_PID=""
    _COTERM_PR_POLL_PWD=""
}

_coterm_stop_pr_poll_loop() {
    _coterm_halt_pr_poll_loop
    _coterm_pr_cache_clear
}

_coterm_start_pr_poll_loop() {
    if [[ "${COTERM_NO_PR_WATCH:-}" == "1" ]]; then
        _coterm_stop_pr_poll_loop
        return 0
    fi
    [[ "${COTERM_NO_GIT_WATCH:-}" == "1" ]] && return 0
    [[ -S "$COTERM_SOCKET_PATH" ]] || return 0
    [[ -n "$COTERM_TAB_ID" ]] || return 0
    [[ -n "$COTERM_PANEL_ID" ]] || return 0
    _coterm_zsh_job_table_saturated && return 0

    local watch_pwd="${1:-$PWD}"
    local force_restart="${2:-0}"
    local watch_shell_pid="$$"
    local interval="${_COTERM_PR_POLL_INTERVAL:-45}"

    if [[ "$force_restart" != "1" && "$watch_pwd" == "$_COTERM_PR_POLL_PWD" && -n "$_COTERM_PR_POLL_PID" ]] \
        && kill -0 "$_COTERM_PR_POLL_PID" 2>/dev/null; then
        return 0
    fi

    if [[ -n "$_COTERM_PR_POLL_PID" ]] && kill -0 "$_COTERM_PR_POLL_PID" 2>/dev/null; then
        _coterm_halt_pr_poll_loop
    else
        _COTERM_PR_POLL_PID=""
    fi
    _COTERM_PR_POLL_PWD="$watch_pwd"

    {
        local signal_path=""
        signal_path="$(_coterm_pr_force_signal_path 2>/dev/null || true)"
        while true; do
            kill -0 "$watch_shell_pid" >/dev/null 2>&1 || break
            local force_probe=0
            if [[ -n "$signal_path" && -f "$signal_path" ]]; then
                force_probe=1
                /bin/rm -f -- "$signal_path" >/dev/null 2>&1 || true
            fi
            _coterm_run_pr_probe_with_timeout "$watch_pwd" "$force_probe" || true

            local slept=0
            while (( slept < interval )); do
                kill -0 "$watch_shell_pid" >/dev/null 2>&1 || exit 0
                if [[ -n "$signal_path" && -f "$signal_path" ]]; then
                    break
                fi
                sleep 1
                slept=$(( slept + 1 ))
            done
        done
    } >/dev/null 2>&1 &!
    _COTERM_PR_POLL_PID=$!
}

_coterm_stop_git_head_watch() {
    [[ -n "$_COTERM_GIT_HEAD_WATCH_PID" ]] || return 0
    kill "$_COTERM_GIT_HEAD_WATCH_PID" >/dev/null 2>&1 || true
    _COTERM_GIT_HEAD_WATCH_PID=""
}

_coterm_start_git_head_watch() {
    [[ "${COTERM_NO_GIT_WATCH:-}" == "1" ]] && return 0
    [[ -S "$COTERM_SOCKET_PATH" ]] || return 0
    [[ -n "$COTERM_TAB_ID" ]] || return 0
    [[ -n "$COTERM_PANEL_ID" ]] || return 0
    _coterm_zsh_job_table_saturated && return 0

    local watch_pwd="$PWD"
    local watch_head_path
    watch_head_path="$(_coterm_git_resolve_head_path "$watch_pwd" 2>/dev/null || true)"
    [[ -n "$watch_head_path" ]] || return 0

    local watch_head_signature
    watch_head_signature="$(_coterm_git_head_signature "$watch_head_path" 2>/dev/null || true)"

    _COTERM_GIT_HEAD_LAST_PWD="$watch_pwd"
    _COTERM_GIT_HEAD_PATH="$watch_head_path"
    _COTERM_GIT_HEAD_SIGNATURE="$watch_head_signature"

    _coterm_stop_git_head_watch
    local watch_shell_pid="$$"
    {
        local last_signature="$watch_head_signature"
        while true; do
            kill -0 "$watch_shell_pid" >/dev/null 2>&1 || break
            sleep 1

            local signature
            signature="$(_coterm_git_head_signature "$watch_head_path" 2>/dev/null || true)"
            if [[ -n "$signature" && "$signature" != "$last_signature" ]]; then
                last_signature="$signature"
                _coterm_pr_cache_clear
                _coterm_report_git_branch_for_path "$watch_pwd"
                _coterm_clear_pr_for_panel
            fi
        done
    } >/dev/null 2>&1 &!
    _COTERM_GIT_HEAD_WATCH_PID=$!
}

_coterm_command_starts_nested_shell() {
    local cmd="$1"
    local -a words
    words=("${(z)cmd}")

    local index=1
    local word base
    while (( index <= ${#words} )); do
        word="${words[index]}"

        case "$word" in
            *=*)
                index=$(( index + 1 ))
                continue ;;
            exec|command|builtin|noglob|time)
                index=$(( index + 1 ))
                continue ;;
            env)
                index=$(( index + 1 ))
                while (( index <= ${#words} )); do
                    word="${words[index]}"
                    case "$word" in
                        -*|*=*)
                            index=$(( index + 1 ))
                            continue ;;
                    esac
                    break
                done
                continue ;;
        esac

        base="${word:t}"
        case "$base" in
            bash|zsh|sh|fish|nu|nix-shell)
                return 0 ;;
            nix)
                local next_index=$(( index + 1 ))
                local next_word="${words[next_index]}"
                case "$next_word" in
                    develop|shell)
                        return 0 ;;
                esac ;;
        esac

        return 1
    done

    return 1
}

_coterm_preexec() {
    local cmd="${1## }"
    _coterm_halt_pr_poll_loop
    _coterm_stop_git_head_watch
    _coterm_zsh_job_table_saturated && return 0

    _coterm_normalize_claude_config_dir
    if (( ! _COTERM_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT )); then
        _coterm_restore_terminal_identity_after_startup
    fi
    _coterm_tmux_sync_coterm_environment

    if [[ -z "$_COTERM_TTY_NAME" ]]; then
        local t
        t="$(tty 2>/dev/null || true)"
        t="${t##*/}"
        [[ -n "$t" && "$t" != "not a tty" ]] && _COTERM_TTY_NAME="$t"
    fi

    _COTERM_CMD_START="$(_coterm_now)"
    _coterm_report_shell_activity_state running
    _coterm_record_pr_command_hint "$cmd"

    # Heuristic: commands that may change git branch/dirty state without changing $PWD.
    case "$cmd" in
        git\ *|git|gh\ *|lazygit|lazygit\ *|tig|tig\ *|gitui|gitui\ *|stg\ *|jj\ *)
            _COTERM_GIT_FORCE=1
            _COTERM_PR_FORCE=1 ;;
    esac

    # Register TTY + kick batched port scan for foreground commands (servers).
    _coterm_report_tty_once
    _coterm_ports_kick command
    if _coterm_command_starts_nested_shell "$cmd"; then
        return 0
    fi
    _coterm_start_git_head_watch
}

_coterm_precmd() {
    local last_status=$?
    # Handle cases where Ghostty integration initializes after this file. This
    # is pure function-body patching, so it remains safe under job saturation.
    _coterm_patch_ghostty_job_table_guard
    (( _COTERM_GHOSTTY_SEMANTIC_PATCHED )) || _coterm_patch_ghostty_semantic_redraw
    _coterm_stop_git_head_watch
    _coterm_zsh_job_table_saturated && return 0

    _coterm_normalize_claude_config_dir
    if (( _COTERM_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT )); then
        _COTERM_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT=0
    fi
    _coterm_tmux_sync_coterm_environment

    local coterm_has_unix_socket=0
    _coterm_socket_is_unix && coterm_has_unix_socket=1
    (( coterm_has_unix_socket )) || _coterm_has_port_scan_transport || return 0
    [[ -n "$COTERM_TAB_ID" ]] || return 0
    if [[ -n "$COTERM_PANEL_ID" ]]; then
        _coterm_reset_terminal_keyboard_protocols
        _coterm_report_shell_activity_state prompt
    fi

    if [[ -z "$_COTERM_TTY_NAME" ]]; then
        local t
        t="$(tty 2>/dev/null || true)"
        t="${t##*/}"
        [[ -n "$t" && "$t" != "not a tty" ]] && _COTERM_TTY_NAME="$t"
    fi

    _coterm_report_tty_once

    local now="$(_coterm_now)"
    local cmd_start="$_COTERM_CMD_START"
    _COTERM_CMD_START=0
    local pwd="$PWD"
    local cmd_dur=0
    if [[ -n "$cmd_start" && "$cmd_start" != 0 ]]; then
        cmd_dur=$(( now - cmd_start ))
    fi

    if (( ! coterm_has_unix_socket )); then
        if [[ "$pwd" != "$_COTERM_PWD_LAST_PWD" ]]; then
            _coterm_report_pwd_via_relay "$pwd" && _COTERM_PWD_LAST_PWD="$pwd"
        fi
        if (( cmd_dur >= 2 || now - _COTERM_PORTS_LAST_RUN >= 10 )); then
            _coterm_ports_kick refresh
        fi
        return 0
    fi

    [[ -n "$COTERM_PANEL_ID" ]] || return 0
    _coterm_set_git_active_pwd "$pwd"

    _coterm_prompt_wrap_guard "$cmd_start" "$pwd"

    # Post-wake socket writes can occasionally leave a probe process wedged.
    # If one probe is stale, clear the guard so fresh async probes can resume.
    if [[ -n "$_COTERM_GIT_JOB_PID" ]]; then
        if ! kill -0 "$_COTERM_GIT_JOB_PID" 2>/dev/null; then
            _COTERM_GIT_JOB_PID=""
            _COTERM_GIT_JOB_STARTED_AT=0
        elif (( _COTERM_GIT_JOB_STARTED_AT > 0 )) && (( now - _COTERM_GIT_JOB_STARTED_AT >= _COTERM_ASYNC_JOB_TIMEOUT )); then
            _COTERM_GIT_JOB_PID=""
            _COTERM_GIT_JOB_STARTED_AT=0
            _COTERM_GIT_FORCE=1
        fi
    fi

    # CWD: keep the app in sync with the actual shell directory.
    # This is also the simplest way to test sidebar directory behavior end-to-end.
    if [[ "$pwd" != "$_COTERM_PWD_LAST_PWD" ]]; then
        _COTERM_PWD_LAST_PWD="$pwd"
        local qpwd="${pwd//\"/\\\"}"
        _coterm_send_bg "report_pwd \"${qpwd}\" --tab=$COTERM_TAB_ID --panel=$COTERM_PANEL_ID"
    fi

    # Git branch/dirty: update immediately on directory change, otherwise every ~3s.
    # While a foreground command is running, _coterm_start_git_head_watch probes HEAD
    # once per second so agent-initiated git checkouts still surface quickly.
    local should_git=0
    local git_head_changed=0

    # Git branch can change without a `git ...`-prefixed command (aliases like `gco`,
    # tools like `gh pr checkout`, etc.). Detect HEAD changes and force a refresh.
    if [[ "${COTERM_NO_GIT_WATCH:-}" == "1" ]]; then
        _coterm_stop_pr_poll_loop
        _coterm_stop_git_head_watch
        if [[ -n "$_COTERM_GIT_JOB_PID" ]] && kill -0 "$_COTERM_GIT_JOB_PID" 2>/dev/null; then
            kill "$_COTERM_GIT_JOB_PID" >/dev/null 2>&1 || true
        fi
        _COTERM_GIT_JOB_PID=""
        _COTERM_GIT_JOB_STARTED_AT=0
        _COTERM_GIT_FORCE=0
        _COTERM_GIT_HEAD_LAST_PWD=""
        _COTERM_GIT_HEAD_PATH=""
        _COTERM_GIT_HEAD_SIGNATURE=""
        _COTERM_GIT_LAST_PWD=""
        _COTERM_PR_FORCE=0
        _COTERM_LAST_PR_ACTION=""
        _COTERM_LAST_PR_TARGET=""
    else
        if [[ "$pwd" != "$_COTERM_GIT_HEAD_LAST_PWD" ]]; then
            _COTERM_GIT_HEAD_LAST_PWD="$pwd"
            _COTERM_GIT_HEAD_PATH="$(_coterm_git_resolve_head_path "$pwd" 2>/dev/null || true)"
            _COTERM_GIT_HEAD_SIGNATURE=""
        fi
        if [[ -n "$_COTERM_GIT_HEAD_PATH" ]]; then
            local head_signature
            head_signature="$(_coterm_git_head_signature "$_COTERM_GIT_HEAD_PATH" 2>/dev/null || true)"
            if [[ -n "$head_signature" ]]; then
                if [[ -z "$_COTERM_GIT_HEAD_SIGNATURE" ]]; then
                    # The first observed HEAD value establishes the baseline for this
                    # shell session. Don't treat it as a branch change or we'll clear
                    # restore-seeded PR badges before the first background probe runs.
                    _COTERM_GIT_HEAD_SIGNATURE="$head_signature"
                elif [[ "$head_signature" != "$_COTERM_GIT_HEAD_SIGNATURE" ]]; then
                    _COTERM_GIT_HEAD_SIGNATURE="$head_signature"
                    git_head_changed=1
                    # Treat HEAD file change like a git command — force-replace any
                    # running probe so the sidebar picks up the new branch immediately.
                    _COTERM_GIT_FORCE=1
                    _COTERM_PR_FORCE=1
                    should_git=1
                fi
            fi
        fi
    fi

    if [[ "$pwd" != "$_COTERM_GIT_LAST_PWD" ]]; then
        should_git=1
    elif (( _COTERM_GIT_FORCE )); then
        should_git=1
    elif (( now - _COTERM_GIT_LAST_RUN >= 3 )); then
        should_git=1
    fi

    if [[ "${COTERM_NO_GIT_WATCH:-}" != "1" ]] && (( should_git )); then
        local can_launch_git=1
        if [[ -n "$_COTERM_GIT_JOB_PID" ]] && kill -0 "$_COTERM_GIT_JOB_PID" 2>/dev/null; then
            # If a stale probe is still running but the cwd changed (or we just ran
            # a git command), restart immediately so branch state isn't delayed
            # until the next user command/prompt.
            # Note: this repeats the cwd check above on purpose. The first check
            # decides whether we should refresh at all; this one decides whether
            # an in-flight older probe can be reused vs. replaced.
            if [[ "$pwd" != "$_COTERM_GIT_LAST_PWD" ]] || (( _COTERM_GIT_FORCE )); then
                kill "$_COTERM_GIT_JOB_PID" >/dev/null 2>&1 || true
                _COTERM_GIT_JOB_PID=""
                _COTERM_GIT_JOB_STARTED_AT=0
            else
                can_launch_git=0
            fi
        fi

        if (( can_launch_git )); then
            _COTERM_GIT_FORCE=0
            _COTERM_GIT_LAST_PWD="$pwd"
            _COTERM_GIT_LAST_RUN=$now
            {
                _coterm_report_git_branch_for_path "$pwd"
            } >/dev/null 2>&1 &!
            _COTERM_GIT_JOB_PID=$!
            _COTERM_GIT_JOB_STARTED_AT=$now
        fi
    fi
    if (( git_head_changed )); then
        _coterm_pr_cache_clear
        _coterm_clear_pr_for_panel
    fi
    if [[ "${COTERM_NO_GIT_WATCH:-}" != "1" ]] && (( last_status == 0 )); then
        _coterm_emit_pr_command_hint
    else
        _COTERM_LAST_PR_ACTION=""
        _COTERM_LAST_PR_TARGET=""
    fi

    # Ports: lightweight kick to the app's batched scanner.
    # - Periodic scan to avoid stale values.
    # - Forced scan when a long-running command returns to the prompt (common when stopping a server).
    if (( cmd_dur >= 2 || now - _COTERM_PORTS_LAST_RUN >= 10 )); then
        _coterm_ports_kick refresh
    fi
}

# Ensure Resources/bin is at the front of PATH, and remove the app's
# Contents/MacOS entry so the GUI coterm binary cannot shadow the CLI coterm.
# Shell init (.zprofile/.zshrc) may prepend other dirs after launch.
# We fix this once on first prompt (after all init files have run), and
# reinstall coterm-owned wrapper functions in case user startup replaced them.
_coterm_fix_path() {
    if [[ -n "${GHOSTTY_BIN_DIR:-}" ]]; then
        local gui_dir="${GHOSTTY_BIN_DIR%/}"
        local bin_dir="${gui_dir%/MacOS}/Resources/bin"
        if [[ -d "$bin_dir" ]]; then
            PATH="$(_coterm_path_prepend_unique_directory "$bin_dir" "${PATH-}" "$gui_dir")"
        fi
    fi
    _coterm_install_cli_wrapper claude _COTERM_CLAUDE_WRAPPER coterm-claude-wrapper
    _coterm_install_cli_wrapper grok _COTERM_GROK_WRAPPER
    add-zsh-hook -d precmd _coterm_fix_path
}

_coterm_chpwd() {
    # Only refresh the active-cwd marker so async git reporters (the HEAD-watch
    # loop and deferred prompt probes) are scoped to the new cwd. Do NOT tear the
    # HEAD watch down here: chpwd fires mid-line for compound commands such as
    # `cd foo && pnpm dev`, and killing the watcher would drop live branch updates
    # during the long-running step. The marker guard already suppresses any stale
    # report for the path the shell just left, and precmd stops the watch at the
    # next prompt.
    _coterm_set_git_active_pwd "$PWD"
}

_coterm_restore_terminal_identity_after_startup() {
    if [[ -n "${COTERM_ZSH_RESTORE_TERM:-}" ]]; then
        builtin export TERM="$COTERM_ZSH_RESTORE_TERM"
        builtin unset COTERM_ZSH_RESTORE_TERM
    fi
    _COTERM_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT=0
}

_coterm_zshexit() {
    _coterm_stop_git_head_watch
    _coterm_stop_pr_poll_loop
    [[ -n "${_COTERM_GIT_ACTIVE_PWD_FILE:-}" ]] && /bin/rm -f -- "$_COTERM_GIT_ACTIVE_PWD_FILE" >/dev/null 2>&1 || true
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _coterm_preexec
add-zsh-hook precmd _coterm_precmd
add-zsh-hook precmd _coterm_fix_path
add-zsh-hook chpwd _coterm_chpwd
add-zsh-hook zshexit _coterm_zshexit
