#!/usr/bin/env bash
# test_hardware.sh — Tests for lib/hardware.sh functions
# Run with: sudo bash tests/test_hardware.sh

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

source "$PROJECT_DIR/lib/helpers.sh"
source "$PROJECT_DIR/lib/apt_helpers.sh"
source "$PROJECT_DIR/lib/hardware.sh"

run_tests() {
  local passed=0 failed=0 total=0

  check_func_exists() {
    local func_name="$1"
    ((total++)) || true
    echo -n "  $func_name... "
    if grep -q "^${func_name}()" "$PROJECT_DIR/lib/hardware.sh"; then
      echo "PASS"
      ((passed++)) || true
    else
      echo "FAIL: not found in hardware.sh"
      ((failed++)) || true
    fi
  }

  check_func_exists nvidia_gpu_detected
  check_func_exists choose_nvidia_driver_package
  check_func_exists install_nvidia_drivers
  check_func_exists enable_nvidia_services

  ((total++)) || true
  echo -n "  modern NVIDIA fallback order... "
  if grep -q 'nvidia-driver-595-open.*nvidia-driver-595.*nvidia-driver-590.*nvidia-driver-580.*nvidia-driver-570' "$PROJECT_DIR/lib/hardware.sh"; then
    echo "PASS"
    ((passed++)) || true
  else
    echo "FAIL: fallback order should prefer 595 before older drivers"
    ((failed++)) || true
  fi

  ((total++)) || true
  echo -n "  no 535 fallback... "
  if ! grep -q 'fallback_versions=.*nvidia-driver-535' "$PROJECT_DIR/lib/hardware.sh"; then
    echo "PASS"
    ((passed++)) || true
  else
    echo "FAIL: 535 should not be a fallback driver"
    ((failed++)) || true
  fi

  echo ""
  echo "Results: $passed passed, $failed failed ($total total)"
}

run_tests
