# Example local overrides derived from a real ~/.bashrc, with secrets removed.
#
# Usage:
# - Keep this file tracked as a public-safe example
# - Copy pieces you want into ~/.config/salary-man-shell/local.sh
# - Put real API keys only in local.sh, never in this repo

# Run pre-commit against the current repo after auto-activating .venv if needed.
pr() {
  local venv_dir
  venv_dir="$(pwd)/.venv"

  if [[ ! -f "$venv_dir/bin/activate" ]]; then
    echo "Error: no .venv directory at $venv_dir"
    return 1
  fi

  if [[ "$VIRTUAL_ENV" != "$venv_dir" ]]; then
    # shellcheck disable=SC1090
    source "$venv_dir/bin/activate"
  fi

  pre-commit run --all-files
}

# Project-specific example. Adjust the path for your machine before copying.
alias tc-recursive='cd "$HOME/tunacode" && source venv/bin/activate && "$HOME/tunacode/venv/bin/tunacode"'

# Safe Claude alias.
alias cc='claude --dangerously-skip-permissions'

# Git aliases carried over from the original bashrc.
alias gst='git status'
alias gdc='git diff --cached'
alias gaa='git add -A'
alias gc='git commit'
alias co='git checkout'
alias ghelp='gcs'

# Show changed file names vs origin/main or origin/master.
gd() {
  local base
  base="$(git branch -r | grep -E 'origin/(main|master)' | head -1 | sed 's@origin/@@')"
  [ -z "$base" ] && base="main"
  git diff --name-only "$base"
}

# Review full diff vs a base branch.
gr() {
  local base="${1:-main}"
  git diff "$base"...HEAD --stat
  echo
  git diff "$base"...HEAD
}

# Review diff stats only vs a base branch.
grs() {
  local base="${1:-main}"
  git diff "$base"...HEAD --stat
}

# Git alias help.
gcs() {
  echo "Git Aliases:"
  echo "  gst   - git status"
  echo "  gd    - git diff --name-only (vs main/master)"
  echo "  gdc   - git diff --cached"
  echo "  gaa   - git add -A"
  echo "  gc    - git commit"
  echo "  co    - git checkout"
  echo "  gr    - review diff vs base branch (default: main)"
  echo "  grs   - review stat vs base branch (default: main)"
  echo "  ghelp - show this help"
}

# git-wt helper, if git-wt is installed.
gtw() {
  if [[ "$1" == "help" ]]; then
    echo "git wt commands:"
    echo "  git wt              List all worktrees"
    echo "  git wt <branch>     Switch to/create worktree"
    echo "  git wt -d <branch>  Delete worktree + branch (safe)"
    echo "  git wt -D <branch>  Delete worktree + branch (force)"
    echo "  git wt --help       Full help from git-wt"
  else
    git wt "$@"
  fi
}

# Rename the current WezTerm tab (best approximation of a "pane name").
rename() {
  if [ $# -eq 0 ]; then
    echo 'Usage: rename "tab name"'
    return 1
  fi

  local title="$*"

  if [ -n "${WEZTERM_PANE-}" ] && command -v wezterm >/dev/null 2>&1; then
    wezterm cli set-tab-title --pane-id "$WEZTERM_PANE" "$title" >/dev/null 2>&1 || true
    return 0
  fi

  if [ -n "${TMUX-}" ]; then
    printf '\033Ptmux;\033\033]0;%s\007\033\\' "$title"
  else
    printf '\033]0;%s\007' "$title"
  fi
}

# Back-compat with older configs.
RENAME() { rename "$@"; }

# WSL helper.
if command -v explorer.exe >/dev/null 2>&1; then
  alias file='explorer.exe .'
fi

# --- Secret-bearing provider wrappers: examples only, keep real values in local.sh ---

zz() {
  export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
  export ANTHROPIC_AUTH_TOKEN="<set-local-token>"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.7"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5"
  claude "$@"
}

mm() {
  export ANTHROPIC_BASE_URL="https://api.minimax.io/anthropic"
  export ANTHROPIC_AUTH_TOKEN="<set-local-token>"
  export API_TIMEOUT_MS="3000000"
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
  export ANTHROPIC_MODEL="MiniMax-M2.1"
  export ANTHROPIC_SMALL_FAST_MODEL="MiniMax-M2.1"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="MiniMax-M2.1"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="MiniMax-M2.1"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="MiniMax-M2.1"
  claude "$@"
}

kk() {
  export ANTHROPIC_BASE_URL="https://api.kimi.com/coding/"
  export ANTHROPIC_API_KEY="<set-local-token>"
  claude "$@"
}
