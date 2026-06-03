#!/usr/bin/env bash
# test_system_services.sh — Tests for lib/system_services.sh functions
# Run with: sudo bash tests/test_system_services.sh

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_SCRIPT_DIR")"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "/home/$TARGET_USER")"
SCRIPT_DIR="$PROJECT_DIR"
CONFIG_DIR="$PROJECT_DIR/configs"
RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")"
DISPLAY_VAL="${DISPLAY:-:0}"
USER_BUS="unix:path=${RUNTIME_DIR}/bus"
PHRASE_AUTOMATION_REPO="mikaeltorni/phrase_automation"
PHRASE_AUTOMATION_DIR="$TARGET_HOME/projects/phrase_automation"
PHRASE_AUTOMATION_TMUX_SESSION="phrase_automation"
PHRASE_AUTOMATION_SERVICE_NAME="phrase-automation-tmux.service"

source "$PROJECT_DIR/lib/helpers.sh"
source "$PROJECT_DIR/lib/apt_helpers.sh"
source "$PROJECT_DIR/lib/system_services.sh"

run_tests() {
  local passed=0 failed=0 total=0

  check_func_exists() {
    local func_name="$1"
    ((total++)) || true
    echo -n "  $func_name... "
    if grep -q "^${func_name}()" "$PROJECT_DIR/lib/system_services.sh"; then
      echo "PASS"
      ((passed++)) || true
    else
      echo "FAIL: not found in system_services.sh"
      ((failed++)) || true
    fi
  }

  check_func_exists ensure_github_login
  check_func_exists clone_all_repos
  check_func_exists clone_repo
  check_func_exists configure_phrase_automation_tmux_service
  check_func_exists configure_phrase_automation_shell_environment

  echo ""
  echo "Results: $passed passed, $failed failed ($total total)"
}

run_tests
