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
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  if [[ "${INSTALLER_PRODUCTION}" == "1" ]]; then
    printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' \
      "$timestamp" "$level_upper" "$(echo "$msg" | sed 's/"/\\"/g')" >&2
  else
    printf "[%s] [%s] %s\n" "$timestamp" "$level_upper" "$msg" >&2
  fi
}
