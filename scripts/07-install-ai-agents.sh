#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
CORE_FAILURE=0

log() {
  printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

run_as_target() {
  if [ "$(id -un)" = "$TARGET_USER" ]; then
    "$@"
  else
    sudo -H -u "$TARGET_USER" bash -lc "$(printf '%q ' "$@")"
  fi
}

require_target_user() {
  if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "Target user not found: $TARGET_USER"
    exit 1
  fi

  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
    echo "Could not determine home directory for: $TARGET_USER"
    exit 1
  fi
}

require_uv() {
  if run_as_target bash -lc 'export PATH="$HOME/.local/bin:$PATH" && command -v uv >/dev/null 2>&1'; then
    return
  fi

  echo "uv is required but not installed for ${TARGET_USER}. Run scripts/03-install-web-dev-stack.sh first."
  exit 1
}

require_npm() {
  if command -v npm >/dev/null 2>&1; then
    return
  fi

  echo "npm is required but not installed. Run scripts/03-install-web-dev-stack.sh first."
  exit 1
}

install_tunacode() {
  log "Installing tunacode-cli with uv"
  run_as_target bash -lc 'export PATH="$HOME/.local/bin:$PATH" && uv tool install --force tunacode-cli'
}

install_opencode() {
  log "Installing opencode"
  run_as_target bash -lc 'curl -fsSL https://opencode.ai/install | bash'
}

install_pi() {
  log "Installing pi-coding-agent"
  as_root npm install -g @mariozechner/pi-coding-agent
}

install_coderabbit() {
  log "Installing coderabbit"
  run_as_target bash -lc 'curl -fsSL https://cli.coderabbit.ai/install.sh | sh'
}

install_codex() {
  log "Installing codex"
  as_root npm i -g @openai/codex
}

verify_cmd_target() {
  local label="$1"
  local cmd="$2"
  local status="no"

  if run_as_target bash -lc "export PATH=\"\$HOME/.local/bin:\$HOME/.opencode/bin:\$PATH\" && command -v $cmd >/dev/null 2>&1"; then
    status="yes"
  fi

  printf '%s=%s\n' "$label" "$status"

  if [ "$status" != "yes" ]; then
    CORE_FAILURE=1
  fi
}

verify_cmd_system() {
  local label="$1"
  local cmd="$2"
  local status="no"

  if command -v "$cmd" >/dev/null 2>&1; then
    status="yes"
  fi

  printf '%s=%s\n' "$label" "$status"

  if [ "$status" != "yes" ]; then
    CORE_FAILURE=1
  fi
}

verify_versions() {
  printf 'uv_version=%s\n' "$(run_as_target bash -lc 'export PATH="$HOME/.local/bin:$PATH" && uv --version' 2>/dev/null || echo missing)"
  printf 'tunacode_version=%s\n' "$(run_as_target bash -lc 'export PATH="$HOME/.local/bin:$PATH" && tunacode --version' 2>/dev/null || echo missing)"
  printf 'opencode_version=%s\n' "$(run_as_target bash -lc 'export PATH="$HOME/.opencode/bin:$PATH" && opencode --version' 2>/dev/null || echo missing)"
  printf 'pi_version=%s\n' "$(pi --version 2>/dev/null || echo missing)"
  printf 'coderabbit_version=%s\n' "$(run_as_target bash -lc 'export PATH="$HOME/.local/bin:$PATH" && coderabbit --version' 2>/dev/null || echo missing)"
  printf 'codex_version=%s\n' "$(codex --version 2>/dev/null || echo missing)"
}

verify_install() {
  log "Verification"
  verify_cmd_target uv_installed uv
  verify_cmd_target tunacode_installed tunacode
  verify_cmd_target opencode_installed opencode
  verify_cmd_system pi_installed pi
  verify_cmd_target coderabbit_installed coderabbit
  verify_cmd_system codex_installed codex
  verify_versions

  if [ "$CORE_FAILURE" -ne 0 ]; then
    return 1
  fi
}

print_notes() {
  cat <<EOF

Done.
- Installed tunacode-cli with uv for ${TARGET_USER}
- Installed opencode for ${TARGET_USER}
- Installed coderabbit for ${TARGET_USER}
- Installed pi-coding-agent and codex globally with npm
EOF
}

main() {
  require_target_user
  require_uv
  require_npm
  install_tunacode
  install_opencode
  install_pi
  install_coderabbit
  install_codex
  verify_install
  print_notes
}

main "$@"
