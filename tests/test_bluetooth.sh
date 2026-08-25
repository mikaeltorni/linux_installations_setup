#!/usr/bin/env bash
# test_bluetooth.sh — Tests for the opt-in Bluetooth kernel/GRUB fix.
# Run with: bash tests/test_bluetooth.sh

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_SCRIPT_DIR")"
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf -- "$FIXTURE_DIR"' EXIT

export BLUETOOTH_KERNEL_VERSION="6.17.0-40-generic"
export BLUETOOTH_GRUB_CONFIG="$FIXTURE_DIR/grub"
export BLUETOOTH_GRUB_CFG="$FIXTURE_DIR/grub.cfg"
export BLUETOOTH_GRUB_ENV="$FIXTURE_DIR/grubenv"
export BLUETOOTH_GRUB_BACKUP_DIR="$FIXTURE_DIR"

msg() { :; }
log() { :; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

source "$PROJECT_DIR/lib/bluetooth.sh"

printf '%s\n' 'GRUB_DEFAULT=0' > "$BLUETOOTH_GRUB_CONFIG"
printf '%s\n' \
  "menuentry 'Ubuntu, with Linux 6.17.0-40-generic' --class ubuntu \$menuentry_id_option 'gnulinux-6.17.0-40-generic-advanced-test' {" \
  > "$BLUETOOTH_GRUB_CFG"
: > "$BLUETOOTH_GRUB_ENV"

grub-editenv() {
  case "${2:-}" in
    list) [ -f "$1" ] && sed -n 'p' "$1" ;;
    *) return 1 ;;
  esac
}

grub-reboot() {
  printf 'next_entry=%s\n' "$1" > "$BLUETOOTH_GRUB_ENV"
}

run_tests() {
  local passed=0 failed=0 total=0

  check() {
    local description="$1"
    shift
    ((total++)) || true
    echo -n "  $description... "
    if "$@"; then
      echo "PASS"
      ((passed++)) || true
    else
      echo "FAIL"
      ((failed++)) || true
    fi
  }

  finds_exact_kernel_menu_id() {
    [ "$(find_bluetooth_kernel_menu_id)" = "gnulinux-6.17.0-40-generic-advanced-test" ]
  }

  backs_up_grub_config_once() {
    backup_grub_default_config
    backup_grub_default_config
    local backup_count
    backup_count="$(find "$FIXTURE_DIR" -maxdepth 1 -type f -name 'grub.backup.*' | wc -l)"
    [ "$backup_count" -eq 1 ]
    cmp -s "$BLUETOOTH_GRUB_CONFIG" "$(find "$FIXTURE_DIR" -maxdepth 1 -type f -name 'grub.backup.*' -print -quit)"
  }

  selects_next_boot_without_rebooting() {
    configure_bluetooth_kernel_boot
    [ "$(sed -n 's/^next_entry=//p' "$BLUETOOTH_GRUB_ENV")" = "gnulinux-6.17.0-40-generic-advanced-test" ]
    [ -f "$BLUETOOTH_GRUB_CONFIG" ]
    bluetooth_kernel_boot_configured
  }

  check "finds the exact installed kernel menu ID" finds_exact_kernel_menu_id
  check "backs up the GRUB defaults once and preserves its contents" backs_up_grub_config_once
  check "selects the next GRUB boot without rebooting" selects_next_boot_without_rebooting

  echo
  echo "Bluetooth tests: $passed passed, $failed failed ($total total)"
  [ "$failed" -eq 0 ]
}

run_tests
