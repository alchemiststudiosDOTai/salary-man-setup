# Managed by salary-man-setup/scripts/05-install-shell-config.sh

export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less -FR"
export LESS="-FR"
export GOPATH="$HOME/go"
export PNPM_HOME="$HOME/.local/share/pnpm"
export BUN_INSTALL="$HOME/.bun"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PNPM_HOME:$BUN_INSTALL/bin:$HOME/go/bin:$PATH"

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

RENAME() {
  if [ -z "$*" ]; then
    echo 'Usage: RENAME "tab name"'
    return 1
  fi

  local name b64
  name="$*"
  b64="$(printf '%s' "$name" | base64 | tr -d '\n')"

  if [ -n "$TMUX" ]; then
    printf '\033Ptmux;\033\033]1337;SetUserVar=TAB_TITLE=%s\007\033\\' "$b64"
  else
    printf '\033]1337;SetUserVar=TAB_TITLE=%s\007' "$b64"
  fi
}

[ -f "$HOME/.config/salary-man-shell/local.sh" ] && source "$HOME/.config/salary-man-shell/local.sh"
