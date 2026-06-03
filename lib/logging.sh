#!/usr/bin/env bash
# logging.sh — Centralized logging utility for all project scripts.
#
# Components:
#   - log(level, msg): Timestamped logging with levels (verbose/debug/info/warn/error)
#   - setup_logging(level): Configure global INSTALLER_LOG_LEVEL and threshold
#   - timed_start(label): Record start time for performance timing
#   - timed_end([label]): Log elapsed time since last timed_start
#   - try_operation operation_name cmd...: Run a command with success/failure logging
#   - graceful_fail operation_name msg: Log error and return 0 (non-critical failure)

_LOG_LEVEL_VERBOSE=0
_LOG_LEVEL_DEBUG=10
_LOG_LEVEL_INFO=20
_LOG_LEVEL_WARN=30
_LOG_LEVEL_ERROR=40

INSTALLER_LOG_LEVEL="${INSTALLER_LOG_LEVEL:-info}"
_LOG_CURRENT_THRESHOLD=$_LOG_LEVEL_INFO
INSTALLER_PRODUCTION="${INSTALLER_PRODUCTION:-0}"

setup_logging() {
  local level="${1:-info}"
  case "${level,,}" in
    verbose) _LOG_CURRENT_THRESHOLD=$_LOG_LEVEL_VERBOSE ;;
    debug)   _LOG_CURRENT_THRESHOLD=$_LOG_LEVEL_DEBUG   ;;
    info)    _LOG_CURRENT_THRESHOLD=$_LOG_LEVEL_INFO     ;;
    warn|warning) _LOG_CURRENT_THRESHOLD=$_LOG_LEVEL_WARN ;;
    error)   _LOG_CURRENT_THRESHOLD=$_LOG_LEVEL_ERROR    ;;
    *)       _LOG_CURRENT_THRESHOLD=$_LOG_LEVEL_INFO     ;;
  esac
  export INSTALLER_LOG_LEVEL="${level^^}"
}

log() {
  local level="${1:-info}" msg="${*:2}"
  local threshold=0
  case "${level,,}" in
    verbose) threshold=$_LOG_LEVEL_VERBOSE ;;
    debug)   threshold=$_LOG_LEVEL_DEBUG   ;;
    info)    threshold=$_LOG_LEVEL_INFO     ;;
    warn|warning) threshold=$_LOG_LEVEL_WARN ;;
    error)   threshold=$_LOG_LEVEL_ERROR    ;;
    *)       threshold=$_LOG_LEVEL_INFO     ;;
  esac
  if (( threshold < _LOG_CURRENT_THRESHOLD )); then return 0; fi
  local timestamp level_upper="${level^^}"
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  if [[ "${INSTALLER_PRODUCTION}" == "1" ]]; then
    printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' \
      "$timestamp" "$level_upper" "$(echo "$msg" | sed 's/"/\\"/g')" >&2
  else
    printf "[%s] [%s] %s\n" "$timestamp" "$level_upper" "$msg" >&2
  fi
}

log_verbose() { log "verbose" "$@"; }
log_debug()   { log "debug" "$@"; }
log_info()    { log "info" "$@"; }
log_warn()    { log "warn" "$@"; }
log_error()   { log "error" "$@"; }

_timed_start_time=0
_timed_start_label=""

timed_start() {
  local label="${1:-operation}"
  _timed_start_label="$label"
  _timed_start_time=$(date +%s%N)
}

timed_end() {
  if [[ -z "${_timed_start_time:-}" ]]; then
    log "warn" "timed_end called without timed_start"
    return 1
  fi
  local end_time label elapsed_ms
  label="${1:-$_timed_start_label}"
  end_time=$(date +%s%N)
  elapsed_ms=$(( (end_time - _timed_start_time) / 1000000 ))
  log "info" "${label} completed in ${elapsed_ms}ms"
  _timed_start_time=0
  _timed_start_label=""
}

TRY_OP_RC=0
try_operation() {
  local operation_name="$1"; shift
  log_info "Starting ${operation_name}"
  "$@"
  TRY_OP_RC=$?
  if [[ ${TRY_OP_RC} -ne 0 ]]; then
    log_error "${operation_name} failed with exit code ${TRY_OP_RC}"
  else
    log_info "${operation_name} succeeded"
  fi
}

graceful_fail() {
  local operation_name="$1"; shift
  local msg="${*:-$operation_name failed}"
  log_error "Graceful failure in ${operation_name}: ${msg}"
  return 0
}
