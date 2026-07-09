# vim:ft=zsh
#
# coterm ZDOTDIR bootstrap for zsh.
#
# GhosttyKit already uses a ZDOTDIR injection mechanism for zsh (setting ZDOTDIR
# to Ghostty's integration dir). coterm also needs to run its integration, but
# we must restore the user's real ZDOTDIR immediately so that:
# - /etc/zshrc sets HISTFILE relative to the real ZDOTDIR/HOME (shared history)
# - zsh loads the user's real .zprofile/.zshrc normally (no wrapper recursion)
#
# We restore ZDOTDIR from (in priority order):
# - GHOSTTY_ZSH_ZDOTDIR (set by GhosttyKit when it overwrote ZDOTDIR)
# - COTERM_ZSH_ZDOTDIR (set by coterm when it overwrote a user-provided ZDOTDIR)
# - unset (zsh treats unset ZDOTDIR as $HOME)

if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"
    builtin unset GHOSTTY_ZSH_ZDOTDIR
elif [[ -n "${COTERM_ZSH_ZDOTDIR+X}" \
   && "$COTERM_ZSH_ZDOTDIR" != "${COTERM_SHELL_INTEGRATION_DIR:-}" \
   && "$COTERM_ZSH_ZDOTDIR" != */Contents/Resources/shell-integration ]]; then
    builtin export ZDOTDIR="$COTERM_ZSH_ZDOTDIR"
    builtin unset COTERM_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
    builtin unset COTERM_ZSH_ZDOTDIR
fi

{
    # zsh treats unset ZDOTDIR as if it were HOME. We do the same.
    builtin typeset _coterm_file="${ZDOTDIR-$HOME}/.zshenv"
    [[ ! -r "$_coterm_file" ]] || builtin source -- "$_coterm_file"

    if [[ -o interactive \
       && -z "${ZSH_EXECUTION_STRING:-}" \
       && "${COTERM_SHELL_INTEGRATION:-1}" != "0" \
       && -n "${COTERM_SHELL_INTEGRATION_DIR:-}" \
       && -r "${COTERM_SHELL_INTEGRATION_DIR}/coterm-zsh-integration.zsh" \
       && "${TERM:-}" == "xterm-256color" \
       && -z "${COTERM_ZSH_RESTORE_TERM:-}" ]]; then
        # Keep startup TERM-compatible prompt/theme selection during shell init,
        # then restore the managed xterm-256color identity before the first
        # interactive command executes.
        builtin export COTERM_ZSH_RESTORE_TERM="$TERM"
        builtin export TERM="xterm-ghostty"
        builtin typeset -g _COTERM_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT=1
    fi
} always {
    if [[ -o interactive ]]; then
        # We overwrote GhosttyKit's injected ZDOTDIR, so manually load Ghostty's
        # zsh integration if available.
        #
        # We can't rely on GHOSTTY_ZSH_ZDOTDIR here because Ghostty's own zsh
        # bootstrap unsets it before chaining into this coterm wrapper.
        if [[ "${COTERM_LOAD_GHOSTTY_ZSH_INTEGRATION:-0}" == "1" ]]; then
            if [[ -n "${COTERM_SHELL_INTEGRATION_DIR:-}" ]]; then
                builtin typeset _coterm_ghostty="$COTERM_SHELL_INTEGRATION_DIR/ghostty-integration.zsh"
            fi
            if [[ ! -r "${_coterm_ghostty:-}" && -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
                builtin typeset _coterm_ghostty="$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
            fi
            [[ -r "$_coterm_ghostty" ]] && builtin source -- "$_coterm_ghostty"
        fi

        # Load coterm integration (unless disabled)
        if [[ "${COTERM_SHELL_INTEGRATION:-1}" != "0" && -n "${COTERM_SHELL_INTEGRATION_DIR:-}" ]]; then
            builtin typeset _coterm_integ="$COTERM_SHELL_INTEGRATION_DIR/coterm-zsh-integration.zsh"
            [[ -r "$_coterm_integ" ]] && builtin source -- "$_coterm_integ"
        fi
    fi

    builtin unset _coterm_file _coterm_ghostty _coterm_integ
}
