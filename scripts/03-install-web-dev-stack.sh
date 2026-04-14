#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
NODE_MAJOR="${NODE_MAJOR:-22}"
INSTALL_PYTHON_DEBUG_TOOLS="${INSTALL_PYTHON_DEBUG_TOOLS:-yes}"
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
  log "Installing prerequisite packages"
  as_root apt-get update
  as_root apt-get install -y \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    gcc \
    git \
    gpg \
    jq \
    libffi-dev \
    liblzma-dev \
    libsqlite3-dev \
    libssl-dev \
    make \
    pkg-config \
    software-properties-common \
    unzip \
    xz-utils \
    zlib1g-dev
}

install_python_stack() {
  log "Installing Python 3 toolchain"
  as_root apt-get install -y \
    pipx \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv

  if [ "$INSTALL_PYTHON_DEBUG_TOOLS" = "yes" ]; then
    as_root apt-get install -y \
      ipython3 \
      python3-rich \
      python3-httpx
  fi
}

add_nodesource_repo() {
  log "Adding NodeSource repo for Node.js ${NODE_MAJOR}"
  mkdir -p "$TMP_DIR/nodesource"
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | as_root gpg --batch --yes --dearmor -o /etc/apt/keyrings/nodesource.gpg
  as_root chmod a+r /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | as_root tee /etc/apt/sources.list.d/nodesource.list >/dev/null
}

install_node_stack() {
  add_nodesource_repo
  log "Installing Node.js and TypeScript tools"
  as_root apt-get update
  # Remove any standalone npm package to prevent conflicts with NodeSource's bundled npm
  as_root apt-get remove -y npm || true
  as_root apt-get autoremove -y || true
  as_root apt-get install -y nodejs

  # NodeSource packages sometimes ship with a broken npm; fix if needed
  if ! npm --version >/dev/null 2>&1 || [ ! -d /usr/lib/node_modules/npm/node_modules/promise-retry ]; then
    log "npm is broken after NodeSource install; reinstalling npm"
    as_root rm -rf /usr/lib/node_modules/npm /usr/bin/npm /usr/bin/npx
    as_root bash -lc 'curl -qL https://www.npmjs.com/install.sh | sh'
  fi

  as_root npm install -g \
    @biomejs/biome \
    npm \
    pnpm \
    typescript \
    typescript-language-server \
    yarn
}

install_rust_stack() {
  if run_as_target test -x "$TARGET_HOME/.cargo/bin/rustup"; then
    log "rustup already installed for ${TARGET_USER}"
  else
    log "Installing rustup for ${TARGET_USER}"
    run_as_target bash -lc 'curl https://sh.rustup.rs -sSf | sh -s -- -y'
  fi

  log "Updating stable Rust toolchain"
  run_as_target bash -lc 'export PATH="$HOME/.cargo/bin:$PATH" && rustup toolchain install stable && rustup default stable && rustup component add rustfmt clippy'
}

install_uv_and_ruff() {
  if run_as_target test -x "$TARGET_HOME/.local/bin/uv"; then
    log "uv already installed for ${TARGET_USER}"
  else
    log "Installing uv for ${TARGET_USER}"
    run_as_target bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  fi

  log "Installing ruff with uv tool"
  run_as_target bash -lc 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH" && uv tool install --force ruff'
}

verify_cmd() {
  local label="$1"
  local cmd="$2"
  local status="no"

  if command -v "$cmd" >/dev/null 2>&1; then
    status="yes"
  elif run_as_target bash -lc "command -v $cmd >/dev/null 2>&1"; then
    status="yes"
  fi

  printf '%s=%s\n' "$label" "$status"

  if [ "$status" != "yes" ]; then
    CORE_FAILURE=1
  fi
}

verify_versions() {
  printf 'python3_version=%s\n' "$(python3 --version 2>/dev/null || echo missing)"
  printf 'pip_version=%s\n' "$(python3 -m pip --version 2>/dev/null || echo missing)"
  printf 'node_version=%s\n' "$(node --version 2>/dev/null || echo missing)"
  printf 'npm_version=%s\n' "$(npm --version 2>/dev/null || echo missing)"
  printf 'tsc_version=%s\n' "$(tsc --version 2>/dev/null || echo missing)"
  printf 'biome_version=%s\n' "$(biome --version 2>/dev/null || echo missing)"
  printf 'rustc_version=%s\n' "$(run_as_target bash -lc 'export PATH="$HOME/.cargo/bin:$PATH" && rustc --version' 2>/dev/null || echo missing)"
  printf 'cargo_version=%s\n' "$(run_as_target bash -lc 'export PATH="$HOME/.cargo/bin:$PATH" && cargo --version' 2>/dev/null || echo missing)"
  printf 'uv_version=%s\n' "$(run_as_target bash -lc 'export PATH="$HOME/.local/bin:$PATH" && uv --version' 2>/dev/null || echo missing)"
  printf 'ruff_version=%s\n' "$(run_as_target bash -lc 'export PATH="$HOME/.local/bin:$PATH" && ruff --version' 2>/dev/null || echo missing)"
}

verify_install() {
  log "Verification"
  verify_cmd python3_installed python3
  verify_cmd pip_installed pip3
  verify_cmd node_installed node
  verify_cmd npm_installed npm
  verify_cmd tsc_installed tsc
  verify_cmd biome_installed biome
  verify_cmd rustc_installed rustc
  verify_cmd cargo_installed cargo
  verify_cmd uv_installed uv
  verify_cmd ruff_installed ruff
  verify_versions

  if [ "$CORE_FAILURE" -ne 0 ]; then
    return 1
  fi
}

print_notes() {
  cat <<EOF

Next steps:
- Open a new shell so cargo and uv paths are available in your normal session
- Verify npm global bin is on PATH if your shell customizations override defaults
- Python projects: use python3 -m venv .venv or uv for env/package management
- Rust user install path: ${TARGET_HOME}/.cargo/bin
- Astral user install path: ${TARGET_HOME}/.local/bin
EOF
}

main() {
  require_ubuntu
  require_target_user
  install_prereqs
  install_python_stack
  install_node_stack
  install_rust_stack
  install_uv_and_ruff
  verify_install
  print_notes
}

main "$@"
