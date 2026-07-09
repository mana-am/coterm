# vim:ft=zsh
#
# Compatibility shim: with the current integration model, coterm restores
# ZDOTDIR in .zshenv so this file should never be reached. If it is, restore
# ZDOTDIR and behave like vanilla zsh by sourcing the user's .zshrc.

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

builtin typeset _coterm_file="${ZDOTDIR-$HOME}/.zshrc"
[[ ! -r "$_coterm_file" ]] || builtin source -- "$_coterm_file"
builtin unset _coterm_file
