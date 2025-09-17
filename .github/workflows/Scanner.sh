#!/usr/bin/env bash
# script_safety.sh
# Menu-driven script scanner + basic safety system
# Usage: save as script_safety.sh, chmod +x script_safety.sh, ./script_safety.sh

set -o errexit
set -o pipefail
set -o nounset

# --- config ---
LOGDIR="${HOME}/.script_safety"
LOGFILE="${LOGDIR}/safety_scan.log"
QUARANTINE_DIR="${LOGDIR}/quarantine"
SANDBOX_DIR="${LOGDIR}/sandbox"
SAFE_RUN_TIMEOUT=10   # seconds; used by timeout for safe runs

# Dangerous patterns (extended regex strings for grep -E)
DANGEROUS_PATTERNS=(
  "rm\s+-rf"                    # remove recursively, force
  ":\\(\\)\\s*\\{\\s*:\\|\\s*:\\s*&\\s*\\};:"   # fork bomb
  "mkfs\\."                     # format disks
  "dd\\s+if="                   # direct disk writes
  "chmod\\s+[0-7]{3,4}\\s+/"    # chmod 777 /
  "chown\\s+root"               # change ownership to root
  "wget\\s+http"                # download via http
  "curl\\s+http"                # download via http
  "nc\\s+-l"                    # netcat listener
  "socat\\s+"                   # socat usage
  "iptables\\s+"                # firewall/packet rules
  ">>\\s*/etc/|>\\s*/etc/"      # overwrite/append to system files
  "sshpass"                     # credential helper
  "eval\\s+\\$\\("              # eval of command substitution
  "base64\\s+-d"                # decoding payloads
  "python\\s+-c"                # inline python execution
  "perl\\s+-e"                  # inline perl execution
  "openssl\\s+enc\\s+-d"        # decrypt payloads
)

# create dirs
mkdir -p "$LOGDIR" "$QUARANTINE_DIR" "$SANDBOX_DIR"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

log() {
  # append to logfile and echo
  echo "[$(timestamp)] $*" | tee -a "$LOGFILE"
}

prompt_file() {
  local file
  read -r -p "Enter path to script: " file
  echo "$file"
}

_quick_grep_patterns() {
  # Build a single grep -E pattern joining all array entries with |
  local joined
  joined="$(printf "%s|" "${DANGEROUS_PATTERNS[@]}")"
  # remove trailing |
  joined="${joined%|}"
  printf '%s' "$joined"
}

scan_script() {
  local script="$1"
  if [[ -z "$script" ]]; then
    script="$(prompt_file)"
  fi

  if [[ ! -f "$script" ]]; then
    echo "File not found: $script"
    return 1
  fi

  log "SCAN START: $script"
  echo "Scanning $script for dangerous patterns..."

  local pattern
  pattern="$(_quick_grep_patterns)"

  # grep for matches (line numbers). Use LC_ALL=C for predictable behavior.
  if LC_ALL=C grep -nE -- "$pattern" "$script" >"${LOGDIR}/last_scan_matches.tmp" 2>/dev/null; then
    echo "Potentially dangerous lines found:"
    cat "${LOGDIR}/last_scan_matches.tmp" | tee -a "$LOGFILE"
    log "SCAN RESULT: DANGEROUS patterns found in $script"
    rm -f "${LOGDIR}/last_scan_matches.tmp"
    return 0
  else
    echo "No dangerous patterns matched."
    log "SCAN RESULT: clean: $script"
    rm -f "${LOGDIR}/last_scan_matches.tmp" 2>/dev/null || true
    return 0
  fi
}

quarantine_script() {
  local script="$1"
  if [[ -z "$script" ]]; then
    script="$(prompt_file)"
  fi
  if [[ ! -f "$script" ]]; then
    echo "File not found: $script"
    return 1
  fi
  local base
  base="$(basename "$script")"
  local dest="${QUARANTINE_DIR}/${base}.$(date +%s)"
  mv -- "$script" "$dest"
  log "QUARANTINE: moved $script -> $dest"
  echo "Moved to quarantine: $dest"
}

safe_run() {
  local script="$1"
  if [[ -z "$script" ]]; then
    script="$(prompt_file)"
  fi

  if [[ ! -f "$script" ]]; then
    echo "File not found: $script"
    return 1
  fi

  # do a quick scan first
  echo "Running quick scan before execution..."
  if scan_script "$script"; then
    echo "Quick scan finished (see logs). Proceeding to safe run."
  else
    echo "Scan had errors; aborting safe run."
    return 1
  fi

  # copy script into sandbox to avoid accidental path usage
  local sb_script="${SANDBOX_DIR}/$(basename "$script")"
  cp -- "$script" "$sb_script"
  chmod 700 "$sb_script"

  log "SAFE RUN START: $script (sandbox: $sb_script)"

  # If timeout available, use it; else run directly with a background watchdog
  if command -v timeout >/dev/null 2>&1; then
    # Use restricted bash to limit some capabilities
    # Note: restricted bash still allows some actions; this is not perfect isolation.
    if timeout "${SAFE_RUN_TIMEOUT}"s bash --restricted "$sb_script"; then
      log "SAFE RUN OK: $script"
    else
      log "SAFE RUN ERROR/TIMEOUT: $script"
      echo "Safe run failed or timed out (timeout=${SAFE_RUN_TIMEOUT}s)."
    fi
  else
    # fallback: run and background kill after SAFE_RUN_TIMEOUT seconds
    bash --restricted "$sb_script" &
    local pid=$!
    ( sleep "${SAFE_RUN_TIMEOUT}"; kill -TERM "$pid" 2>/dev/null ) &
    local killer=$!
    wait "$pid" 2>/dev/null || true
    kill -0 "$killer" 2>/dev/null && kill -9 "$killer" 2>/dev/null || true
    log "SAFE RUN (no timeout tool) finished for $script"
  fi

  # cleanup sandbox script
  rm -f "$sb_script"
}

view_logs() {
  if [[ -f "$LOGFILE" ]]; then
    echo "---- Safety Log: $LOGFILE ----"
    tail -n 200 "$LOGFILE"
  else
    echo "No log file yet: $LOGFILE"
  fi
}

menu() {
  while true; do
    cat <<'EOF'

=============================
  Script Safety System Menu
=============================
1) Scan a script
2) Run a script in safe mode (restricted + timeout)
3) Quarantine a script (move to quarantine folder)
4) View logs (tail 200 lines)
5) Show quarantine directory
6) Exit
EOF
    read -r -p "Choose an option [1-6]: " choice
    case "${choice:-}" in
      1)
        scan_script ""
        ;;
      2)
        safe_run ""
        ;;
      3)
        quarantine_script ""
        ;;
      4)
        view_logs
        ;;
      5)
        echo "Quarantine dir: $QUARANTINE_DIR"
        ls -la "$QUARANTINE_DIR" || true
        ;;
      6)
        echo "Goodbye."
        exit 0
        ;;
      *)
        echo "Invalid choice. Pick 1-6."
        ;;
    esac
  done
}

# If script invoked with args, provide non-interactive helpers:
# ./script_safety.sh --scan /path/to/file
# ./script_safety.sh --safe-run /path/to/file
# ./script_safety.sh --quarantine /path/to/file
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -gt 0 ]]; then
    case "$1" in
      --scan)
        if [[ -z "${2:-}" ]]; then echo "Usage: $0 --scan /path/to/script"; exit 2; fi
        scan_script "$2"
        exit $?
        ;;
      --safe-run)
        if [[ -z "${2:-}" ]]; then echo "Usage: $0 --safe-run /path/to/script"; exit 2; fi
        safe_run "$2"
        exit $?
        ;;
      --quarantine)
        if [[ -z "${2:-}" ]]; then echo "Usage: $0 --quarantine /path/to/script"; exit 2; fi
        quarantine_script "$2"
        exit $?
        ;;
      --help|-h)
        echo "Usage:"
        echo "  $0             # interactive menu"
        echo "  $0 --scan file"
        echo "  $0 --safe-run file"
        echo "  $0 --quarantine file"
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        exit 2
        ;;
    esac
  else
    menu
  fi
fi
