#!/usr/bin/env bash
# test_app_installer.sh — Tests for lib/app_installer.sh
#
# Guards that the application installers expose the expected functions and that
# the GitHub CLI APT source is written with a readable full keyring.
# APT only reads files in /etc/apt/sources.list.d/ that end in ``.list`` (or
# ``.sources``); a name without that extension is silently ignored, so the
# regression below pins the correct filename.
#
# Run with: bash tests/test_app_installer.sh

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_SCRIPT_DIR")"
APP_INSTALLER="$PROJECT_DIR/lib/app_installer.sh"
LIFECYCLE="$PROJECT_DIR/lib/lifecycle.sh"

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

  check "install_google_chrome defined" grep -q '^install_google_chrome()' "$APP_INSTALLER"
  check "install_balena_etcher defined" grep -q '^install_balena_etcher()' "$APP_INSTALLER"
  check "install_gh_cli defined" grep -q '^install_gh_cli()' "$APP_INSTALLER"
  check "gh source file ends in .list" grep -q 'sources.list.d/github-cli\.list' "$APP_INSTALLER"
  check "no extensionless gh source file" bash -c "! grep -q 'github-cli-list' '$APP_INSTALLER'"
  check "gh keyring is not truncated" bash -c "! grep -q 'bs=128 count=1' '$APP_INSTALLER'"
  check "gh keyring is installed atomically" grep -q 'mv "$tmp_keyring" "$keyring"' "$APP_INSTALLER"
  check "gh apt update failure is logged" grep -q 'apt update failed after adding GitHub CLI repo' "$APP_INSTALLER"
  check "gh detection validates apt source keyring" grep -q 'detect_gh_cli().*gh_cli_apt_source_has_readable_keyring' "$LIFECYCLE"

  echo ""
  echo "Results: $passed passed, $failed failed ($total total)"
  [ "$failed" -eq 0 ]
}

run_tests
