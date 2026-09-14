#!/usr/bin/env bash
# test_inotify_limits.sh — Tests for lib/inotify_limits.sh
# Run with: bash tests/test_inotify_limits.sh

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_SCRIPT_DIR")"
SCRIPT_DIR="$PROJECT_DIR"
INSTALLER_LOG_LEVEL=error

source "$PROJECT_DIR/lib/logging.sh"
source "$PROJECT_DIR/lib/inotify_limits.sh"

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

  writes_sysctl_drop_in_without_touching_host() {
    local tmp
    tmp="$(mktemp -d)"
    (
      export LIS_SYSCTL_D="$tmp"
      PATH="$tmp/bin:$PATH"
      mkdir -p "$tmp/bin"
      cat >"$tmp/bin/sysctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${LIS_SYSCTL_D}/sysctl.argv"
exit 0
EOF
      chmod +x "$tmp/bin/sysctl"
      source "$PROJECT_DIR/lib/inotify_limits.sh"
      configure_inotify_limits
      grep -q "fs.inotify.max_user_instances = 1024" "$tmp/99-inotify-desktop.conf" || exit 1
      grep -q "fs.inotify.max_user_watches = 524288" "$tmp/99-inotify-desktop.conf" || exit 1
      grep -q "fs.inotify.max_queued_events = 65536" "$tmp/99-inotify-desktop.conf" || exit 1
      grep -q -- "-p $tmp/99-inotify-desktop.conf" "$tmp/sysctl.argv" || exit 1
      inotify_limits_configured || exit 1
      remove_inotify_limits
      ! inotify_limits_configured || exit 1
      [ ! -f "$tmp/99-inotify-desktop.conf" ]
    )
    local status=$?
    rm -rf "$tmp"
    return "$status"
  }

  check "writes sysctl drop-in and applies via sysctl -p" \
    writes_sysctl_drop_in_without_touching_host

  echo ""
  echo "Results: $passed passed, $failed failed ($total total)"
  [ "$failed" -eq 0 ]
}

run_tests
