#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
BACKUP_ROOT="${ROOT_DIR}/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/git-ssh-${TIMESTAMP}"
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
  log "Installing git/ssh packages"
  as_root apt-get update
  as_root apt-get install -y git openssh-client
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

install_git_config() {
  install_managed_file "$ROOT_DIR/git-config/.gitconfig" "$TARGET_HOME/.gitconfig" 0644
}

normalize_ssh_permissions() {
  local ssh_dir="$TARGET_HOME/.ssh"

  if [ ! -d "$ssh_dir" ]; then
    log "No existing ${ssh_dir}; leaving SSH untouched"
    return
  fi

  log "Normalizing existing SSH permissions"
  as_root chmod 700 "$ssh_dir"
  as_root chown "$TARGET_USER":"$TARGET_USER" "$ssh_dir"

  if [ -f "$ssh_dir/config" ]; then
    as_root chmod 600 "$ssh_dir/config"
    as_root chown "$TARGET_USER":"$TARGET_USER" "$ssh_dir/config"
  fi

  if [ -f "$ssh_dir/known_hosts" ]; then
    as_root chmod 644 "$ssh_dir/known_hosts"
    as_root chown "$TARGET_USER":"$TARGET_USER" "$ssh_dir/known_hosts"
  fi

  if [ -f "$ssh_dir/known_hosts.old" ]; then
    as_root chmod 644 "$ssh_dir/known_hosts.old"
    as_root chown "$TARGET_USER":"$TARGET_USER" "$ssh_dir/known_hosts.old"
  fi

  while IFS= read -r -d '' file; do
    case "$file" in
      *.pub)
        as_root chmod 644 "$file"
        ;;
      *)
        as_root chmod 600 "$file"
        ;;
    esac
    as_root chown "$TARGET_USER":"$TARGET_USER" "$file"
  done < <(find "$ssh_dir" -maxdepth 1 -type f ! -name 'known_hosts' ! -name 'known_hosts.old' ! -name 'config' -print0)
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

verify_file_contains() {
  local label="$1"
  local file="$2"
  local needle="$3"
  local status="no"

  if [ -f "$file" ] && grep -Fq "$needle" "$file"; then
    status="yes"
  fi

  printf '%s=%s\n' "$label" "$status"
  if [ "$status" != "yes" ]; then
    CORE_FAILURE=1
  fi
}

verify_optional_path() {
  local label="$1"
  local path="$2"
  local status="no"

  if [ -e "$path" ]; then
    status="yes"
  fi

  printf '%s=%s\n' "$label" "$status"
}

verify_ssh_permissions() {
  local ssh_dir="$TARGET_HOME/.ssh"
  local status="not_present"

  if [ -d "$ssh_dir" ]; then
    status="yes"
    if [ "$(stat -c '%a' "$ssh_dir")" != "700" ]; then
      status="no"
    fi
    if [ -f "$ssh_dir/config" ] && [ "$(stat -c '%a' "$ssh_dir/config")" != "600" ]; then
      status="no"
    fi
  fi

  printf 'ssh_permissions_ok=%s\n' "$status"

  if [ "$status" = "no" ]; then
    CORE_FAILURE=1
  fi
}

verify_versions() {
  printf 'git_version=%s\n' "$(git --version 2>/dev/null || echo missing)"
  printf 'ssh_version=%s\n' "$(ssh -V 2>&1 | head -n 1 || echo missing)"
}

verify_install() {
  log "Verification"
  verify_file_exists gitconfig_installed "$TARGET_HOME/.gitconfig"
  verify_file_contains git_user_name_present "$TARGET_HOME/.gitconfig" 'name = '
  verify_file_contains git_user_email_present "$TARGET_HOME/.gitconfig" 'email = '
  verify_file_contains git_delta_pager_configured "$TARGET_HOME/.gitconfig" 'pager = delta'
  verify_optional_path ssh_dir_present "$TARGET_HOME/.ssh"
  verify_optional_path ssh_config_present "$TARGET_HOME/.ssh/config"
  verify_optional_path ssh_private_key_present "$TARGET_HOME/.ssh/id_ed25519"
  verify_ssh_permissions
  verify_versions

  if [ "$CORE_FAILURE" -ne 0 ]; then
    return 1
  fi
}

print_notes() {
  cat <<EOF

Done.
- Installed managed ~/.gitconfig from this repo
- Did not generate SSH keys
- Did not create ~/.ssh/config or host entries
- If ~/.ssh already existed, its permissions were normalized
- Backups, if any, are in: ${BACKUP_DIR}
EOF
}

main() {
  require_ubuntu
  require_target_user
  install_prereqs
  install_git_config
  normalize_ssh_permissions
  verify_install
  print_notes
}

main "$@"
