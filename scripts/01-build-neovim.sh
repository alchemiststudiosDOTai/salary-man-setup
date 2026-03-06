#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

REPO_URL="${REPO_URL:-https://github.com/neovim/neovim.git}"
NEOVIM_REF="${NEOVIM_REF:-stable}"
SOURCE_DIR="${SOURCE_DIR:-${ROOT_DIR}/build/neovim-src}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-RelWithDebInfo}"
JOBS="${JOBS:-$(nproc)}"

SAVED_CONFIG_DIR="${SAVED_CONFIG_DIR:-${ROOT_DIR}/nvim-config}"
TARGET_CONFIG_DIR="${TARGET_CONFIG_DIR:-${HOME}/.config/nvim}"
BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/backups}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

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

install_deps_apt() {
  log "Installing Neovim build dependencies via apt"
  as_root apt-get update
  as_root apt-get install -y \
    ninja-build \
    gettext \
    cmake \
    unzip \
    curl \
    build-essential \
    git \
    pkg-config \
    rsync
}

ensure_dependencies() {
  if command -v apt-get >/dev/null 2>&1; then
    install_deps_apt
  else
    log "apt-get not found. Install Neovim build dependencies manually before running this script."
    exit 1
  fi
}

capture_current_config() {
  if [ -f "${SAVED_CONFIG_DIR}/init.lua" ]; then
    log "Saved Neovim config already exists at ${SAVED_CONFIG_DIR}"
    return
  fi

  if [ ! -d "$TARGET_CONFIG_DIR" ]; then
    log "No current Neovim config found at ${TARGET_CONFIG_DIR}; skipping capture"
    return
  fi

  mkdir -p "$SAVED_CONFIG_DIR"
  log "Copying current Neovim config into ${SAVED_CONFIG_DIR}"
  rsync -a "$TARGET_CONFIG_DIR/" "$SAVED_CONFIG_DIR/"
}

prepare_source() {
  mkdir -p "$(dirname "$SOURCE_DIR")"

  if [ ! -d "$SOURCE_DIR/.git" ]; then
    log "Cloning Neovim into $SOURCE_DIR"
    git clone "$REPO_URL" "$SOURCE_DIR"
  fi

  log "Fetching latest Neovim refs"
  git -C "$SOURCE_DIR" fetch --all --tags --prune
  git -C "$SOURCE_DIR" checkout "$NEOVIM_REF"
  git -C "$SOURCE_DIR" pull --ff-only || true
}

build_neovim() {
  log "Cleaning previous build artifacts"
  make -C "$SOURCE_DIR" distclean >/dev/null 2>&1 || true

  log "Building Neovim ($NEOVIM_REF)"
  make -C "$SOURCE_DIR" \
    CMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
    CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX" \
    -j"$JOBS"
}

install_neovim() {
  log "Installing Neovim to $INSTALL_PREFIX"
  as_root make -C "$SOURCE_DIR" \
    CMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
    CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX" \
    install
}

restore_saved_config() {
  if [ ! -f "${SAVED_CONFIG_DIR}/init.lua" ]; then
    log "Saved config not found at ${SAVED_CONFIG_DIR}; skipping restore"
    return
  fi

  mkdir -p "$BACKUP_DIR"

  if [ -d "$TARGET_CONFIG_DIR" ] || [ -L "$TARGET_CONFIG_DIR" ]; then
    local backup_target="${BACKUP_DIR}/nvim-config-${TIMESTAMP}"
    log "Backing up existing ${TARGET_CONFIG_DIR} to ${backup_target}"
    mv "$TARGET_CONFIG_DIR" "$backup_target"
  fi

  mkdir -p "$(dirname "$TARGET_CONFIG_DIR")"
  mkdir -p "$TARGET_CONFIG_DIR"
  log "Restoring saved Neovim config from ${SAVED_CONFIG_DIR} to ${TARGET_CONFIG_DIR}"
  rsync -a --delete "$SAVED_CONFIG_DIR/" "$TARGET_CONFIG_DIR/"
}

verify_install() {
  local binary_installed="no"
  local config_loaded="no"

  if command -v nvim >/dev/null 2>&1; then
    binary_installed="yes"
  fi

  printf 'binary_installed=%s\n' "$binary_installed"

  if [ "$binary_installed" = "yes" ]; then
    printf 'nvim_path=%s\n' "$(command -v nvim)"
    printf 'nvim_version=%s\n' "$(nvim --version | head -n 1)"

    if nvim --headless "+qa" >/tmp/nvim-config-check.log 2>&1; then
      config_loaded="yes"
    else
      config_loaded="no"
    fi
  fi

  printf 'config_loaded=%s\n' "$config_loaded"

  if [ "$config_loaded" = "no" ] && [ -f /tmp/nvim-config-check.log ]; then
    echo 'config_check_log=/tmp/nvim-config-check.log'
  fi

  if [ "$binary_installed" != "yes" ] || [ "$config_loaded" != "yes" ]; then
    return 1
  fi
}

main() {
  ensure_dependencies
  capture_current_config
  prepare_source
  build_neovim
  install_neovim
  restore_saved_config
  verify_install
}

main "$@"
