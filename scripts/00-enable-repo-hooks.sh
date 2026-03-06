#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOKS_DIR="${ROOT_DIR}/.githooks"
CORE_FAILURE=0

log() {
  printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

require_git_repo() {
  if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "${ROOT_DIR} is not a git repository"
    exit 1
  fi
}

install_hooks() {
  log "Enabling repo-local git hooks"
  chmod +x "$HOOKS_DIR/pre-commit"
  git -C "$ROOT_DIR" config core.hooksPath .githooks
}

verify_value() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  local status="no"

  if [ "$actual" = "$expected" ]; then
    status="yes"
  fi

  printf '%s=%s\n' "$label" "$status"
  if [ "$status" != "yes" ]; then
    CORE_FAILURE=1
  fi
}

verify_file_executable() {
  local label="$1"
  local file="$2"
  local status="no"

  if [ -x "$file" ]; then
    status="yes"
  fi

  printf '%s=%s\n' "$label" "$status"
  if [ "$status" != "yes" ]; then
    CORE_FAILURE=1
  fi
}

verify_install() {
  log "Verification"
  verify_file_executable pre_commit_hook_executable "$HOOKS_DIR/pre-commit"
  verify_value hooks_path_configured "$(git -C "$ROOT_DIR" config --get core.hooksPath || true)" ".githooks"

  if [ "$CORE_FAILURE" -ne 0 ]; then
    return 1
  fi
}

main() {
  require_git_repo
  install_hooks
  verify_install
}

main "$@"
