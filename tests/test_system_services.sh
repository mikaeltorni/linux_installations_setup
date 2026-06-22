#!/usr/bin/env bash
# test_system_services.sh — Tests for lib/system_services.sh functions
# Run with: bash tests/test_system_services.sh

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_SCRIPT_DIR")"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "/home/$TARGET_USER")"
SCRIPT_DIR="$PROJECT_DIR"
RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")"
DISPLAY_VAL="${DISPLAY:-:0}"
USER_BUS="unix:path=${RUNTIME_DIR}/bus"
log() { :; }  # silence shared-helper debug logging in this harness
source "$PROJECT_DIR/../linux_installation_scripts_functions/installer_helpers.sh"
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

  echo ""
  echo "Results: $passed passed, $failed failed ($total total)"
}

run_tests
