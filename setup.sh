#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
LOG_ROOT="${ROOT_DIR}/logs"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_LOG_DIR="${LOG_ROOT}/setup-${TIMESTAMP}"
SUMMARY_FILE="${RUN_LOG_DIR}/summary.txt"

log() {
  printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

list_scripts() {
  find "$SCRIPTS_DIR" -maxdepth 1 -type f -name '[0-9][0-9]-*.sh' | sort | xargs -n1 basename
}

resolve_script() {
  local arg="$1"

  if [ -f "$arg" ]; then
    printf '%s\n' "$arg"
    return
  fi

  if [ -f "$SCRIPTS_DIR/$arg" ]; then
    printf '%s\n' "$SCRIPTS_DIR/$arg"
    return
  fi

  echo "Could not find script: $arg" >&2
  return 1
}

collect_scripts() {
  if [ "$#" -eq 0 ]; then
    find "$SCRIPTS_DIR" -maxdepth 1 -type f -name '[0-9][0-9]-*.sh' | sort
    return
  fi

  local arg
  for arg in "$@"; do
    resolve_script "$arg"
  done
}

run_script() {
  local script="$1"
  local name logfile

  name="$(basename "$script")"
  logfile="${RUN_LOG_DIR}/${name%.sh}.log"

  log "Running ${name}"
  printf 'START %s\n' "$name" | tee -a "$SUMMARY_FILE"

  if bash "$script" 2>&1 | tee "$logfile"; then
    printf 'PASS  %s\n' "$name" | tee -a "$SUMMARY_FILE"
    log "Completed ${name}"
  else
    printf 'FAIL  %s\n' "$name" | tee -a "$SUMMARY_FILE"
    echo "log_file=${logfile}" | tee -a "$SUMMARY_FILE"
    log "Failed ${name}"
    exit 1
  fi
}

main() {
  if [ "${1:-}" = "--list" ]; then
    list_scripts
    exit 0
  fi

  mkdir -p "$RUN_LOG_DIR"

  log "Run logs will be written to ${RUN_LOG_DIR}"

  mapfile -t scripts < <(collect_scripts "$@")

  if [ "${#scripts[@]}" -eq 0 ]; then
    echo "No setup scripts found in ${SCRIPTS_DIR}" >&2
    exit 1
  fi

  printf 'salary-man-setup run %s\n' "$TIMESTAMP" > "$SUMMARY_FILE"

  local script
  for script in "${scripts[@]}"; do
    run_script "$script"
  done

  log "All setup scripts completed successfully"
  echo "summary_file=${SUMMARY_FILE}"
}

main "$@"
