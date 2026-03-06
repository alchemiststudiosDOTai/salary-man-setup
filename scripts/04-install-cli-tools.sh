#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
LAZYGIT_VERSION="${LAZYGIT_VERSION:-}"
STARSHIP_VERSION="${STARSHIP_VERSION:-}"
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

map_arch() {
  local arch
  arch="$(dpkg --print-architecture)"

  case "$arch" in
    amd64)
      LG_ARCH="x86_64"
      ;;
    arm64)
      LG_ARCH="arm64"
      ;;
    *)
      echo "Unsupported architecture: $arch"
      exit 1
      ;;
  esac
}

ensure_keyrings_dir() {
  as_root mkdir -p /etc/apt/keyrings
  as_root chmod 0755 /etc/apt/keyrings
}

install_prereqs() {
  log "Installing prerequisite packages"
  as_root apt-get update
  as_root apt-get install -y \
    ca-certificates \
    curl \
    jq
}

add_github_cli_repo() {
  log "Adding GitHub CLI apt repo"
  ensure_keyrings_dir
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | as_root dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  as_root chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | as_root tee /etc/apt/sources.list.d/github-cli.list >/dev/null
}

install_apt_cli_tools() {
  log "Installing CLI tools"
  as_root apt-get update
  as_root apt-get install -y \
    bat \
    btop \
    direnv \
    entr \
    eza \
    fd-find \
    fzf \
    gh \
    git-delta \
    htop \
    httpie \
    hyperfine \
    jq \
    mosh \
    ncdu \
    ripgrep \
    rlwrap \
    shellcheck \
    tig \
    tmux \
    tree \
    unzip \
    zoxide \
    zip
}

fetch_latest_github_tag() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name'
}

install_lazygit() {
  local version tarball base_version
  version="$LAZYGIT_VERSION"
  if [ -z "$version" ]; then
    version="$(fetch_latest_github_tag jesseduffield/lazygit)"
  fi

  base_version="${version#v}"
  tarball="lazygit_${base_version}_linux_${LG_ARCH}.tar.gz"

  log "Installing lazygit ${version}"
  curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/${version}/${tarball}" -o "$TMP_DIR/$tarball"
  tar -xzf "$TMP_DIR/$tarball" -C "$TMP_DIR"
  as_root install -m 0755 "$TMP_DIR/lazygit" /usr/local/bin/lazygit
}

install_starship() {
  local version installer_args
  version="$STARSHIP_VERSION"
  installer_args=(-y -b /usr/local/bin)

  if [ -n "$version" ]; then
    installer_args+=("--version" "$version")
  fi

  log "Installing starship"
  curl -fsSL https://starship.rs/install.sh -o "$TMP_DIR/install-starship.sh"
  chmod +x "$TMP_DIR/install-starship.sh"
  as_root "$TMP_DIR/install-starship.sh" "${installer_args[@]}"
}

append_line_if_missing() {
  local file="$1"
  local line="$2"

  as_root touch "$file"
  if ! as_root grep -Fqx "$line" "$file"; then
    printf '%s\n' "$line" | as_root tee -a "$file" >/dev/null
  fi
}

configure_starship_shell() {
  log "Configuring starship for ${TARGET_USER}"
  append_line_if_missing "$TARGET_HOME/.bashrc" 'eval "$(starship init bash)"'
  append_line_if_missing "$TARGET_HOME/.zshrc" 'eval "$(starship init zsh)"'
  as_root chown "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.bashrc" "$TARGET_HOME/.zshrc"
}

ensure_ubuntu_command_aliases() {
  if command -v fdfind >/dev/null 2>&1 && [ ! -e /usr/local/bin/fd ]; then
    as_root ln -s "$(command -v fdfind)" /usr/local/bin/fd
  fi

  if command -v batcat >/dev/null 2>&1 && [ ! -e /usr/local/bin/bat ]; then
    as_root ln -s "$(command -v batcat)" /usr/local/bin/bat
  fi
}

verify_cmd() {
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

verify_optional() {
  local label="$1"
  local check_cmd="$2"
  local status="no"

  if bash -lc "$check_cmd" >/dev/null 2>&1; then
    status="yes"
  fi

  printf '%s=%s\n' "$label" "$status"
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

verify_versions() {
  printf 'gh_version=%s\n' "$(gh --version 2>/dev/null | head -n 1 || echo missing)"
  printf 'tmux_version=%s\n' "$(tmux -V 2>/dev/null || echo missing)"
  printf 'rg_version=%s\n' "$(rg --version 2>/dev/null | head -n 1 || echo missing)"
  printf 'fd_version=%s\n' "$(fd --version 2>/dev/null || fdfind --version 2>/dev/null || echo missing)"
  printf 'fzf_version=%s\n' "$(fzf --version 2>/dev/null || echo missing)"
  printf 'bat_version=%s\n' "$(bat --version 2>/dev/null || batcat --version 2>/dev/null || echo missing)"
  printf 'eza_version=%s\n' "$(eza --version 2>/dev/null | head -n 1 || echo missing)"
  printf 'zoxide_version=%s\n' "$(zoxide --version 2>/dev/null || echo missing)"
  printf 'delta_version=%s\n' "$(delta --version 2>/dev/null || echo missing)"
  printf 'lazygit_version=%s\n' "$(lazygit --version 2>/dev/null | head -n 1 || echo missing)"
  printf 'starship_version=%s\n' "$(starship --version 2>/dev/null | head -n 1 || echo missing)"
  printf 'httpie_version=%s\n' "$(http --version 2>/dev/null || echo missing)"
  printf 'hyperfine_version=%s\n' "$(hyperfine --version 2>/dev/null || echo missing)"
  printf 'mosh_version=%s\n' "$(mosh --version 2>/dev/null | head -n 1 || echo missing)"
  printf 'direnv_version=%s\n' "$(direnv version 2>/dev/null || echo missing)"
  printf 'btop_version=%s\n' "$(btop --version 2>/dev/null | head -n 1 || echo missing)"
  printf 'shellcheck_version=%s\n' "$(shellcheck --version 2>/dev/null | awk 'NR==2 {print $2}' || echo missing)"
  printf 'jq_version=%s\n' "$(jq --version 2>/dev/null || echo missing)"
}

verify_install() {
  log "Verification"
  verify_cmd gh_installed gh
  verify_cmd tmux_installed tmux
  verify_cmd rg_installed rg
  verify_cmd fd_installed fd
  verify_cmd fzf_installed fzf
  verify_cmd bat_installed bat
  verify_cmd eza_installed eza
  verify_cmd zoxide_installed zoxide
  verify_cmd delta_installed delta
  verify_cmd lazygit_installed lazygit
  verify_cmd starship_installed starship
  verify_cmd httpie_installed http
  verify_cmd hyperfine_installed hyperfine
  verify_cmd mosh_installed mosh
  verify_cmd direnv_installed direnv
  verify_cmd btop_installed btop
  verify_cmd shellcheck_installed shellcheck
  verify_cmd jq_installed jq
  verify_file_has_line starship_bash_init_configured "$TARGET_HOME/.bashrc" 'eval "$(starship init bash)"'
  verify_file_has_line starship_zsh_init_configured "$TARGET_HOME/.zshrc" 'eval "$(starship init zsh)"'
  verify_optional gh_authenticated 'gh auth status'
  verify_versions

  if [ "$CORE_FAILURE" -ne 0 ]; then
    return 1
  fi
}

print_notes() {
  cat <<EOF

Notes:
- Ubuntu packages install bat as batcat and fd as fdfind; this script creates /usr/local/bin/bat and /usr/local/bin/fd symlinks when needed.
- gh auth status is informational only and does not fail the script.
- zoxide and direnv still need shell init in your shell config to be fully useful.
- starship init is automatically added to ${TARGET_HOME}/.bashrc and ${TARGET_HOME}/.zshrc.
EOF
}

main() {
  require_ubuntu
  require_target_user
  map_arch
  install_prereqs
  add_github_cli_repo
  install_apt_cli_tools
  install_lazygit
  install_starship
  configure_starship_shell
  ensure_ubuntu_command_aliases
  verify_install
  print_notes
}

main "$@"
