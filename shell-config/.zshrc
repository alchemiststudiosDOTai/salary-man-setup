# Managed by salary-man-setup/scripts/05-install-shell-config.sh

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/pnpm:$HOME/.bun/bin:$HOME/.opencode/bin:$HOME/go/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less -FR"
export DISABLE_AUTOUPDATER=1

[ -f "$HOME/.config/salary-man-shell/common.sh" ] && source "$HOME/.config/salary-man-shell/common.sh"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"

autoload -Uz compinit && compinit
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v git-wt >/dev/null 2>&1 && eval "$(git-wt --init zsh)"
