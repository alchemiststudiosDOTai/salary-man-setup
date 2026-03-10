#!/usr/bin/env bash
set -euo pipefail

REPO_URL_DEFAULT="https://github.com/alchemiststudiosDOTai/salary-man-setup.git"
REPO_REF_DEFAULT="main"
REPO_DIR_DEFAULT="${HOME}/salary-man-setup"

log() {
  printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Bootstrap salary-man-setup from GitHub and run setup.sh.

Usage:
  curl -fsSL <raw-install-url> | bash
  curl -fsSL <raw-install-url> | bash -s -- 04-install-cli-tools.sh 05-install-shell-config.sh

Options:
  --repo-url <url>   Git repo to clone/update
  --ref <ref>        Branch or tag to use (default: main)
  --repo-dir <dir>   Clone path (default: ~/salary-man-setup)
  --skip-run         Clone/update repo but do not run setup.sh
  -h, --help         Show this help

Environment:
  SALARYMAN_SETUP_REPO_URL  Override repo URL
  SALARYMAN_SETUP_REF       Override git ref
  SALARYMAN_SETUP_DIR       Override clone path
  TARGET_USER               Target user for the numbered setup scripts
EOF
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

require_target_context() {
  if [ "$(id -u)" -eq 0 ] && [ -z "${TARGET_USER:-${SUDO_USER:-}}" ]; then
    die "Do not run this bootstrap as a plain root shell. Run it as your normal user, or set TARGET_USER=<user> when running as root."
  fi
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    die "git is required, and automatic installation is only supported on apt-based systems."
  fi

  log "git not found; installing git"
  as_root apt-get update
  as_root apt-get install -y git
}

repo_is_clean() {
  local repo_dir="$1"

  git -C "$repo_dir" diff --quiet && \
    git -C "$repo_dir" diff --cached --quiet && \
    [ -z "$(git -C "$repo_dir" ls-files --others --exclude-standard)" ]
}

clone_or_update_repo() {
  local repo_url="$1"
  local repo_ref="$2"
  local repo_dir="$3"

  if [ -d "$repo_dir/.git" ]; then
    log "Using existing clone at ${repo_dir}"

    if repo_is_clean "$repo_dir"; then
      log "Updating clone to ${repo_ref}"
      git -C "$repo_dir" fetch --depth 1 origin "$repo_ref"
      git -C "$repo_dir" checkout --quiet FETCH_HEAD
    else
      log "Existing clone has local changes; skipping automatic update"
    fi

    return
  fi

  if [ -e "$repo_dir" ]; then
    die "Path exists but is not a git clone: ${repo_dir}"
  fi

  mkdir -p "$(dirname "$repo_dir")"
  log "Cloning ${repo_url} (${repo_ref}) into ${repo_dir}"
  git clone --depth 1 --branch "$repo_ref" "$repo_url" "$repo_dir"
}

run_setup() {
  local repo_dir="$1"
  shift || true

  log "Running ${repo_dir}/setup.sh"
  (
    cd "$repo_dir"
    bash ./setup.sh "$@"
  )
}

main() {
  local repo_url="${SALARYMAN_SETUP_REPO_URL:-$REPO_URL_DEFAULT}"
  local repo_ref="${SALARYMAN_SETUP_REF:-$REPO_REF_DEFAULT}"
  local repo_dir="${SALARYMAN_SETUP_DIR:-$REPO_DIR_DEFAULT}"
  local skip_run="no"
  local -a setup_args=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --repo-url)
        [ "$#" -ge 2 ] || die "Missing value for --repo-url"
        repo_url="$2"
        shift 2
        ;;
      --ref)
        [ "$#" -ge 2 ] || die "Missing value for --ref"
        repo_ref="$2"
        shift 2
        ;;
      --repo-dir)
        [ "$#" -ge 2 ] || die "Missing value for --repo-dir"
        repo_dir="$2"
        shift 2
        ;;
      --skip-run)
        skip_run="yes"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        while [ "$#" -gt 0 ]; do
          setup_args+=("$1")
          shift
        done
        ;;
      *)
        setup_args+=("$1")
        shift
        ;;
    esac
  done

  require_target_context
  ensure_git
  clone_or_update_repo "$repo_url" "$repo_ref" "$repo_dir"

  if [ "$skip_run" = "yes" ]; then
    log "Bootstrap repo is ready at ${repo_dir}"
    if [ "${#setup_args[@]}" -gt 0 ]; then
      printf 'next_command=cd %s && ./setup.sh %s\n' "$repo_dir" "${setup_args[*]}"
    else
      printf 'next_command=cd %s && ./setup.sh\n' "$repo_dir"
    fi
    exit 0
  fi

  run_setup "$repo_dir" "${setup_args[@]}"
}

main "$@"
