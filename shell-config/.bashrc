# Managed by salary-man-setup/scripts/05-install-shell-config.sh

# Exit early for non-interactive shells after basic PATH setup.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/pnpm:$HOME/.bun/bin:$HOME/go/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less -FR"

[[ $- != *i* ]] && return

[ -f "$HOME/.config/salary-man-shell/common.sh" ] && source "$HOME/.config/salary-man-shell/common.sh"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"
[ -f /usr/share/bash-completion/bash_completion ] && source /usr/share/bash-completion/bash_completion
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash

command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
