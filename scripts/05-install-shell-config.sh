#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
BACKUP_ROOT="${ROOT_DIR}/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/shell-${TIMESTAMP}"
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

require_ubuntu() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script assumes Ubuntu with apt."
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  if [ "${ID:-}" != "ubuntu" ]; then
    echo "This script assumes Ubuntu. Detected: ${ID:-unknown}"
    exit 1
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

install_prereqs() {
  log "Installing shell packages"
  as_root apt-get update
  as_root apt-get install -y bash-completion zsh
}

ensure_parent_dir() {
  local path="$1"
  as_root mkdir -p "$(dirname "$path")"
}

backup_if_needed() {
  local src="$1"
  local target="$2"
  local rel backup_target

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    return
  fi

  if [ -f "$target" ] && cmp -s "$src" "$target"; then
    return
  fi

  mkdir -p "$BACKUP_DIR"
  rel="${target#${TARGET_HOME}/}"
  backup_target="${BACKUP_DIR}/${rel}"
  as_root mkdir -p "$(dirname "$backup_target")"
  as_root mv "$target" "$backup_target"
  log "Backed up ${target} -> ${backup_target}"
}

install_managed_file() {
  local src="$1"
  local target="$2"
  local mode="$3"

  ensure_parent_dir "$target"

  if [ -f "$target" ] && cmp -s "$src" "$target"; then
    log "Already current: ${target}"
    return
  fi

  backup_if_needed "$src" "$target"
  as_root install -m "$mode" "$src" "$target"
  as_root chown "$TARGET_USER":"$TARGET_USER" "$target"
  log "Installed ${target}"
}

ensure_local_override() {
  local local_file="$TARGET_HOME/.config/salary-man-shell/local.sh"
  ensure_parent_dir "$local_file"

  if [ ! -f "$local_file" ]; then
    as_root touch "$local_file"
    as_root chmod 0644 "$local_file"
    as_root chown "$TARGET_USER":"$TARGET_USER" "$local_file"
    log "Created ${local_file}"
  fi
}

install_shell_configs() {
  install_managed_file "$ROOT_DIR/shell-config/.bashrc" "$TARGET_HOME/.bashrc" 0644
  install_managed_file "$ROOT_DIR/shell-config/.zshrc" "$TARGET_HOME/.zshrc" 0644
  install_managed_file "$ROOT_DIR/shell-config/.config/salary-man-shell/common.sh" "$TARGET_HOME/.config/salary-man-shell/common.sh" 0644
  install_managed_file "$ROOT_DIR/shell-config/.config/starship.toml" "$TARGET_HOME/.config/starship.toml" 0644
  ensure_local_override
}

verify_file_has_line() {
  local label="$1"
  local file="$2"
  local line="$3"
  local status="no"

  if [ -f "$file" ] && grep -Fqx "$line" "$file"; then
    status="yes"
  fi

  printf '%s=%s\n' "$label" "$status"
  if [ "$status" != "yes" ]; then
    CORE_FAILURE=1
  fi
}

verify_file_exists() {
  local label="$1"
  local file="$2"
  local status="no"

  if [ -f "$file" ]; then
    status="yes"
  fi

  printf '%s=%s\n' "$label" "$status"
  if [ "$status" != "yes" ]; then
    CORE_FAILURE=1
  fi
}

verify_install() {
  log "Verification"
  verify_file_exists bashrc_installed "$TARGET_HOME/.bashrc"
  verify_file_exists zshrc_installed "$TARGET_HOME/.zshrc"
  verify_file_exists common_shell_config_installed "$TARGET_HOME/.config/salary-man-shell/common.sh"
  verify_file_exists starship_config_installed "$TARGET_HOME/.config/starship.toml"
  verify_file_exists local_shell_override_present "$TARGET_HOME/.config/salary-man-shell/local.sh"
  verify_file_has_line bash_starship_init_present "$TARGET_HOME/.bashrc" 'command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"'
  verify_file_has_line bash_zoxide_init_present "$TARGET_HOME/.bashrc" 'command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"'
  verify_file_has_line bash_direnv_hook_present "$TARGET_HOME/.bashrc" 'command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"'
  verify_file_has_line zsh_starship_init_present "$TARGET_HOME/.zshrc" 'command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"'
  verify_file_has_line zsh_zoxide_init_present "$TARGET_HOME/.zshrc" 'command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"'
  verify_file_has_line zsh_direnv_hook_present "$TARGET_HOME/.zshrc" 'command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"'

  if [ "$CORE_FAILURE" -ne 0 ]; then
    return 1
  fi
}

print_notes() {
  cat <<EOF

Done.
- Managed shell files now live in this repo under shell-config/
- Existing shell files were backed up to: ${BACKUP_DIR}
- Per-machine or secret local additions can go in: ${TARGET_HOME}/.config/salary-man-shell/local.sh
EOF
}

main() {
  require_ubuntu
  require_target_user
  install_prereqs
  install_shell_configs
  verify_install
  print_notes
}

main "$@"
