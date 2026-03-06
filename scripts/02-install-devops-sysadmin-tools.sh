#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
INSTALL_POSTGRES_SERVER="${INSTALL_POSTGRES_SERVER:-no}"
KUBECTL_VERSION="${KUBECTL_VERSION:-}"
HELM_VERSION="${HELM_VERSION:-}"
K9S_VERSION="${K9S_VERSION:-}"
KIND_VERSION="${KIND_VERSION:-}"
YQ_VERSION="${YQ_VERSION:-}"

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

require_apt() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script currently supports apt-based systems only."
    exit 1
  fi
}

load_os_release() {
  # shellcheck disable=SC1091
  source /etc/os-release
  OS_ID="$ID"
  OS_CODENAME="${VERSION_CODENAME:-}"

  if [ -z "$OS_CODENAME" ] && command -v lsb_release >/dev/null 2>&1; then
    OS_CODENAME="$(lsb_release -cs)"
  fi

  if [ "$OS_ID" != "ubuntu" ]; then
    echo "This script assumes Ubuntu. Detected: $OS_ID"
    exit 1
  fi
}

map_arch() {
  local arch
  arch="$(dpkg --print-architecture)"

  case "$arch" in
    amd64)
      BIN_ARCH="amd64"
      ;;
    arm64)
      BIN_ARCH="arm64"
      ;;
    *)
      echo "Unsupported architecture: $arch"
      exit 1
      ;;
  esac
}

install_prereqs() {
  log "Installing prerequisite packages"
  as_root apt-get update
  as_root apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    fd-find \
    fzf \
    git \
    gnupg \
    jq \
    lsb-release \
    rsync \
    software-properties-common \
    tar \
    tmux \
    unzip \
    zip
}

ensure_keyrings_dir() {
  as_root mkdir -p /etc/apt/keyrings
  as_root chmod 0755 /etc/apt/keyrings
}

add_docker_repo() {
  log "Adding Docker apt repo"
  ensure_keyrings_dir
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | as_root gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  as_root chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${OS_CODENAME} stable" | as_root tee /etc/apt/sources.list.d/docker.list >/dev/null
}

add_hashicorp_repo() {
  log "Adding HashiCorp apt repo"
  ensure_keyrings_dir
  curl -fsSL https://apt.releases.hashicorp.com/gpg | as_root gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
  as_root chmod a+r /etc/apt/keyrings/hashicorp.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com ${OS_CODENAME} main" | as_root tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
}

install_apt_toolchain() {
  log "Installing devops/sysadmin packages"
  as_root apt-get update
  as_root apt-get install -y \
    ansible \
    btop \
    build-essential \
    direnv \
    dnsutils \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    htop \
    iputils-ping \
    libpq-dev \
    make \
    mtr-tiny \
    ncdu \
    netcat-openbsd \
    nmap \
    openssh-client \
    pipx \
    pkg-config \
    postgresql-client \
    redis-tools \
    ripgrep \
    shellcheck \
    sqlite3 \
    tcpdump \
    terraform \
    traceroute \
    tree

  if [ "$INSTALL_POSTGRES_SERVER" = "yes" ]; then
    log "Installing local PostgreSQL server packages"
    as_root apt-get install -y postgresql postgresql-contrib
  fi
}

fetch_latest_github_tag() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name'
}

install_kubectl() {
  local version url
  version="$KUBECTL_VERSION"
  if [ -z "$version" ]; then
    version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  fi

  url="https://dl.k8s.io/release/${version}/bin/linux/${BIN_ARCH}/kubectl"
  log "Installing kubectl ${version}"
  curl -fsSL "$url" -o "$TMP_DIR/kubectl"
  chmod +x "$TMP_DIR/kubectl"
  as_root install -m 0755 "$TMP_DIR/kubectl" /usr/local/bin/kubectl
}

install_helm() {
  local version tarball_dir tarball
  version="$HELM_VERSION"
  if [ -z "$version" ]; then
    version="$(fetch_latest_github_tag helm/helm)"
  fi

  tarball="helm-${version}-linux-${BIN_ARCH}.tar.gz"
  log "Installing helm ${version}"
  curl -fsSL "https://get.helm.sh/${tarball}" -o "$TMP_DIR/$tarball"
  tar -xzf "$TMP_DIR/$tarball" -C "$TMP_DIR"
  as_root install -m 0755 "$TMP_DIR/linux-${BIN_ARCH}/helm" /usr/local/bin/helm
}

install_k9s() {
  local version tarball
  version="$K9S_VERSION"
  if [ -z "$version" ]; then
    version="$(fetch_latest_github_tag derailed/k9s)"
  fi

  tarball="k9s_Linux_${BIN_ARCH}.tar.gz"
  log "Installing k9s ${version}"
  curl -fsSL "https://github.com/derailed/k9s/releases/download/${version}/${tarball}" -o "$TMP_DIR/$tarball"
  tar -xzf "$TMP_DIR/$tarball" -C "$TMP_DIR"
  as_root install -m 0755 "$TMP_DIR/k9s" /usr/local/bin/k9s
}

install_kind() {
  local version
  version="$KIND_VERSION"
  if [ -z "$version" ]; then
    version="$(fetch_latest_github_tag kubernetes-sigs/kind)"
  fi

  log "Installing kind ${version}"
  curl -fsSL "https://kind.sigs.k8s.io/dl/${version}/kind-linux-${BIN_ARCH}" -o "$TMP_DIR/kind"
  chmod +x "$TMP_DIR/kind"
  as_root install -m 0755 "$TMP_DIR/kind" /usr/local/bin/kind
}

install_yq() {
  local version binary_name
  version="$YQ_VERSION"
  if [ -z "$version" ]; then
    version="$(fetch_latest_github_tag mikefarah/yq)"
  fi

  binary_name="yq_linux_${BIN_ARCH}"
  log "Installing yq ${version}"
  curl -fsSL "https://github.com/mikefarah/yq/releases/download/${version}/${binary_name}" -o "$TMP_DIR/yq"
  chmod +x "$TMP_DIR/yq"
  as_root install -m 0755 "$TMP_DIR/yq" /usr/local/bin/yq
}

configure_docker_user() {
  if ! id "$TARGET_USER" >/dev/null 2>&1; then
    log "Target user ${TARGET_USER} does not exist; skipping docker group setup"
    return
  fi

  log "Adding ${TARGET_USER} to docker group"
  as_root groupadd -f docker
  as_root usermod -aG docker "$TARGET_USER"

  if command -v systemctl >/dev/null 2>&1; then
    as_root systemctl enable --now docker >/dev/null 2>&1 || true
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

verify_docker_daemon() {
  local status="no"
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    status="yes"
  fi
  printf 'docker_daemon_reachable=%s\n' "$status"
}

verify_versions() {
  printf 'docker_version=%s\n' "$(docker --version 2>/dev/null || echo missing)"
  printf 'kubectl_version=%s\n' "$(kubectl version --client=true --output=yaml 2>/dev/null | awk '/gitVersion:/ {print $2; exit}' || echo missing)"
  printf 'helm_version=%s\n' "$(helm version --short 2>/dev/null || echo missing)"
  printf 'k9s_version=%s\n' "$(k9s version -s 2>/dev/null | head -n 1 || echo missing)"
  printf 'kind_version=%s\n' "$(kind --version 2>/dev/null || echo missing)"
  printf 'terraform_version=%s\n' "$(terraform version 2>/dev/null | head -n 1 || echo missing)"
  printf 'psql_version=%s\n' "$(psql --version 2>/dev/null || echo missing)"
  printf 'ansible_version=%s\n' "$(ansible --version 2>/dev/null | head -n 1 || echo missing)"
  printf 'yq_version=%s\n' "$(yq --version 2>/dev/null || echo missing)"
}

verify_install() {
  log "Verification"
  verify_cmd docker_installed docker
  verify_cmd kubectl_installed kubectl
  verify_cmd helm_installed helm
  verify_cmd k9s_installed k9s
  verify_cmd kind_installed kind
  verify_cmd terraform_installed terraform
  verify_cmd psql_installed psql
  verify_cmd ansible_installed ansible
  verify_cmd yq_installed yq
  verify_docker_daemon
  verify_versions

  if [ "$CORE_FAILURE" -ne 0 ]; then
    return 1
  fi
}

print_notes() {
  cat <<EOF

Next steps:
- Open a new shell so docker group membership applies to ${TARGET_USER}
- Confirm kubectl context before use: kubectl config get-contexts
- If you want local Postgres server too, rerun with:
  INSTALL_POSTGRES_SERVER=yes ./scripts/02-install-devops-sysadmin-tools.sh
EOF
}

main() {
  require_apt
  load_os_release
  map_arch
  install_prereqs
  add_docker_repo
  add_hashicorp_repo
  install_apt_toolchain
  install_kubectl
  install_helm
  install_k9s
  install_kind
  install_yq
  configure_docker_user
  verify_install
  print_notes
}

main "$@"
