#!/usr/bin/env bash
# logging.sh — Centralized logging utility for all project scripts.
#
# Components:
#   - log(level, msg): Timestamped logging with levels (debug/info/warn/error)

_LOG_LEVEL_DEBUG=10
_LOG_LEVEL_INFO=20
_LOG_LEVEL_WARN=30
_LOG_LEVEL_ERROR=40

INSTALLER_LOG_LEVEL="${INSTALLER_LOG_LEVEL:-info}"
INSTALLER_PRODUCTION="${INSTALLER_PRODUCTION:-0}"

# _installer_log_timestamp — Return the current local timestamp for log records.
#
# Behavior:
#   Tests and installer probes may deliberately run with a stripped PATH. Prefer
#   date from PATH, then common absolute locations, and finally emit a stable
#   sentinel instead of failing the caller's workflow.
#
# Returns: 0 always.
_installer_log_timestamp() {
  if command -v date >/dev/null 2>&1; then
    date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || printf 'unknown-time'
  elif [[ -x /usr/bin/date ]]; then
    /usr/bin/date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || printf 'unknown-time'
  elif [[ -x /bin/date ]]; then
    /bin/date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || printf 'unknown-time'
  else
    printf 'unknown-time'
  fi
}

# log — Emit a timestamped, level-filtered log line to stderr.
#
# Parameters:
#   $1 (level): Severity — one of debug | info | warn/warning | error.
#               Unknown values are treated as info.
#   $2..$N (msg): Message text; remaining args are joined with spaces.
#
# Behavior:
#   Lines below INSTALLER_LOG_LEVEL are dropped. When INSTALLER_PRODUCTION=1 the
#   line is emitted as a JSON object; otherwise as "[ts] [LEVEL] message".
#
# Returns: 0 always.
log() {
  local level="${1:-info}" msg="${*:2}"
  local threshold current_threshold
  case "${level,,}" in
    debug)   threshold=$_LOG_LEVEL_DEBUG   ;;
    info)    threshold=$_LOG_LEVEL_INFO     ;;
    warn|warning) threshold=$_LOG_LEVEL_WARN ;;
    error)   threshold=$_LOG_LEVEL_ERROR    ;;
    *)       threshold=$_LOG_LEVEL_INFO     ;;
  esac
  case "${INSTALLER_LOG_LEVEL,,}" in
    debug) current_threshold=$_LOG_LEVEL_DEBUG ;;
    warn|warning) current_threshold=$_LOG_LEVEL_WARN ;;
    error) current_threshold=$_LOG_LEVEL_ERROR ;;
    *) current_threshold=$_LOG_LEVEL_INFO ;;
  esac
  if (( threshold < current_threshold )); then return 0; fi
  local timestamp level_upper="${level^^}"
  timestamp="$(_installer_log_timestamp)"
  if [[ "${INSTALLER_PRODUCTION}" == "1" ]]; then
    msg="${msg//\\/\\\\}"
    msg="${msg//\"/\\\"}"
    printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' \
      "$timestamp" "$level_upper" "$msg" >&2
  else
    printf "[%s] [%s] %s\n" "$timestamp" "$level_upper" "$msg" >&2
  fi
}
