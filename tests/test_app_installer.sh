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
  check "install_smartgit defined" grep -q '^install_smartgit()' "$APP_INSTALLER"
  check "install_gh_cli defined" grep -q '^install_gh_cli()' "$APP_INSTALLER"
  check "SmartGit archive is checksum pinned" grep -q 'SMARTGIT_ARCHIVE_SHA256' "$APP_INSTALLER"
  check "SmartGit archive checksum is verified" grep -q 'sha256sum -c' "$APP_INSTALLER"
  check "SmartGit desktop entry is installed" grep -q 'smartgit.desktop' "$APP_INSTALLER"
  check "SmartGit detection is defined" grep -q '^detect_smartgit()' "$LIFECYCLE"
  check "SmartGit uninstall is defined" grep -q '^uninstall_smartgit()' "$LIFECYCLE"
  check "gh source file ends in .list" grep -q 'sources.list.d/github-cli\.list' "$APP_INSTALLER"
  check "no extensionless gh source file" bash -c "! grep -q 'github-cli-list' '$APP_INSTALLER'"
  check "gh keyring is not truncated" bash -c "! grep -q 'bs=128 count=1' '$APP_INSTALLER'"
  check "gh keyring is installed atomically" grep -q 'mv "$tmp_keyring" "$keyring"' "$APP_INSTALLER"
  check "gh apt update failure is logged" grep -q 'apt update failed after adding GitHub CLI repo' "$APP_INSTALLER"
  check "gh detection validates apt source keyring" grep -q 'detect_gh_cli().*gh_cli_apt_source_has_readable_keyring' "$LIFECYCLE"

  check "SmartGit archive installs a launchable desktop entry" smartgit_installer_round_trip

  echo ""
  echo "Results: $passed passed, $failed failed ($total total)"
  [ "$failed" -eq 0 ]
}

smartgit_installer_round_trip() (
  set -euo pipefail

  local tmpdir fixture_dir archive sha256
  tmpdir="$(mktemp -d)"
  fixture_dir="$tmpdir/smartgit"
  mkdir -p "$fixture_dir/bin"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$fixture_dir/bin/smartgit.sh"
  chmod 0755 "$fixture_dir/bin/smartgit.sh"
  printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg"/>' > "$fixture_dir/bin/smartgit.svg"
  printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' | base64 -d > "$fixture_dir/bin/smartgit-256.png"
  archive="$tmpdir/smartgit.tar.gz"
  tar -czf "$archive" -C "$tmpdir" smartgit
  sha256="$(sha256sum "$archive" | cut -d' ' -f1)"

  SMARTGIT_INSTALL_ROOT="$tmpdir/opt"
  SMARTGIT_DESKTOP_FILE="$tmpdir/applications/smartgit.desktop"
  SMARTGIT_LAUNCHER="$tmpdir/bin/smartgit"
  SMARTGIT_ARCHIVE_URL="file://$archive"
  SMARTGIT_ARCHIVE_SHA256="$sha256"
  source "$APP_INSTALLER"
  source "$LIFECYCLE"
  apt_install() { :; }
  msg() { :; }
  log() { :; }

  install_smartgit || return 1
  detect_smartgit || return 1
  [ -L "$SMARTGIT_INSTALL_ROOT/smartgit" ] || return 1
  [ -L "$SMARTGIT_LAUNCHER" ] || return 1
  grep -Fxq "Exec=$SMARTGIT_INSTALL_ROOT/smartgit/bin/smartgit.sh %U" "$SMARTGIT_DESKTOP_FILE" || return 1
  grep -Fxq "Icon=$SMARTGIT_INSTALL_ROOT/smartgit/bin/smartgit-256.png" "$SMARTGIT_DESKTOP_FILE" || return 1

  # A second pass must keep the complete installation intact and remain
  # idempotent without downloading or overwriting the managed files.
  install_smartgit || return 1
  detect_smartgit || return 1
  rm -rf "$tmpdir"
)

run_tests
