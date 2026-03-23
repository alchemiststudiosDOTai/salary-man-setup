# Managed by salary-man-setup/scripts/05-install-shell-config.sh

export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less -FR"
export LESS="-FR"
export GOPATH="$HOME/go"
export PNPM_HOME="$HOME/.local/share/pnpm"
export BUN_INSTALL="$HOME/.bun"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PNPM_HOME:$BUN_INSTALL/bin:$HOME/.opencode/bin:$HOME/go/bin:$PATH"

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lah --git --group-directories-first'
  alias la='eza -a --group-directories-first'
else
  alias ll='ls -lah'
  alias la='ls -A'
fi

alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias gdc='git diff --cached'
alias gaa='git add -A'
alias gc='git commit'
alias v='nvim'
alias t='tmux new -As main'
alias k='kubectl'
alias d='docker'
alias dc='docker compose'
alias py='python3'
alias reload='exec "$SHELL" -l'

mkcd() {
  mkdir -p "$1" && cd "$1"
}

grs() {
  local base="${1:-main}"
  git diff "$base"...HEAD --stat
}

gr() {
  local base="${1:-main}"
  git diff "$base"...HEAD --stat
  echo
  git diff "$base"...HEAD
}

rename() {
  if [ $# -eq 0 ]; then
    echo 'Usage: rename "tab name"'
    return 1
  fi

  local title="$*"

  # WezTerm: rename the current tab based on the active pane.
  if [ -n "${WEZTERM_PANE-}" ] && command -v wezterm >/dev/null 2>&1; then
    wezterm cli set-tab-title --pane-id "$WEZTERM_PANE" "$title" >/dev/null 2>&1 || true
    return 0
  fi

  # Fallback: set the terminal title (works in many terminals).
  # When inside tmux, wrap it so it reaches the outer terminal.
  if [ -n "${TMUX-}" ]; then
    printf '\033Ptmux;\033\033]0;%s\007\033\\' "$title"
  else
    printf '\033]0;%s\007' "$title"
  fi
}

# Back-compat / muscle memory.
RENAME() { rename "$@"; }

[ -f "$HOME/.config/salary-man-shell/local.sh" ] && source "$HOME/.config/salary-man-shell/local.sh"
