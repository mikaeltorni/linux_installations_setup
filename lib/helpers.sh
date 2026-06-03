#!/usr/bin/env bash
# helpers.sh — Core utility functions sourced by install scripts
#
# Components:
#   - msg(msg): User-facing message with arrow prefix.
#   - need_cmd(cmd): Check if a command exists in PATH.
#   - toml_string_array(name): Format a bash array as a TOML string array.
#   - run_as_target(cmd...): Execute a command as the target user.
#   - ensure_root(): Exit with error if not running as root.
#   - ensure_session_bus(): Exit with error if session bus is missing.
#   - find_desktop_file_path(name): Find full path to a .desktop file.
#   - find_desktop_entry(candidates...): Find basename of first existing .desktop.
#
# Must be sourced after SCRIPT_DIR, CONFIG_DIR, TARGET_USER, TARGET_HOME,
# RUNTIME_DIR, DISPLAY_VAL, USER_BUS are set.

msg() { printf "\n==> %s\n" "$*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

toml_string_array() {
  local ref="$1" item result="[" sep="" arr=()
  eval "arr=(\"\${$ref[@]}\")" || return 1
  for item in "${arr[@]}"; do
    item="${item//\\/\\\\}"
    item="${item//\"/\\\"}"
    result+="${sep}\"${item}\""
    sep=", "
  done
  result+="]"
  printf '%s\n' "$result"
}

run_as_target() {
  sudo -H -u "$TARGET_USER" env \
    HOME="$TARGET_HOME" \
    USER="$TARGET_USER" \
    LOGNAME="$TARGET_USER" \
    XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$USER_BUS" \
    DISPLAY="$DISPLAY_VAL" \
    "$@"
}

ensure_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log "error" "Please run with sudo: sudo bash $0"
    echo "Please run with sudo: sudo bash $0"
    exit 1
  fi
}

ensure_session_bus() {
  if [ ! -S "${RUNTIME_DIR}/bus" ]; then
    log "error" "No user session bus at ${RUNTIME_DIR}/bus"
    cat <<EOF
No user session bus at ${RUNTIME_DIR}/bus.
Open a terminal in ${TARGET_USER}'s *logged-in desktop* session and run:
  sudo bash $0
EOF
    exit 1
  fi
}

DESKTOP_DIRS=(
  /usr/share/applications
  /var/lib/snapd/desktop/applications
  "$TARGET_HOME/.local/share/applications"
)

find_desktop_file_path() {
  local name="$1"
  local dir path="$name"
  if [[ "$name" != *.desktop ]]; then
    path="${name}.desktop"
  fi
  for dir in "${DESKTOP_DIRS[@]}"; do
    if [ -f "${dir}/${path}" ]; then
      printf '%s\n' "${dir}/${path}"
      return 0
    fi
  done
  return 1
}

find_desktop_entry() {
  local candidate
  for candidate in "$@"; do
    if find_desktop_file_path "$candidate" >/dev/null; then
      if [[ "$candidate" == *.desktop ]]; then
        printf '%s\n' "$candidate"
      else
        printf '%s\n' "${candidate}.desktop"
      fi
      return 0
    fi
  done
  return 1
}
