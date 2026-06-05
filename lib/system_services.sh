#!/usr/bin/env bash
# system_services.sh — GitHub CLI authentication
#
# Components:
#   - ensure_github_login(): Check and prompt for GitHub CLI authentication.

ensure_github_login() {
  msg "Checking GitHub CLI login for $TARGET_USER"
  if ! run_as_target bash -lc 'command -v gh >/dev/null 2>&1'; then
    log "warn" "gh is not available; skipping GitHub authentication."
    return
  fi
  if run_as_target gh auth status >/dev/null 2>&1; then
    run_as_target gh auth setup-git || true
    return
  fi
  if [[ "${INSTALLER_REQUIRE_GITHUB_LOGIN:-0}" != "1" ]] && ! [ -t 0 ]; then
    msg "Skipping interactive GitHub login (no TTY). Set INSTALLER_REQUIRE_GITHUB_LOGIN=1 to force login."
    return 0
  fi
  cat <<EOF
GitHub login is required before cloning essential private or authenticated repos.
Follow the browser/device-code prompts from GitHub CLI for user: ${TARGET_USER}
EOF
  run_as_target gh auth login --git-protocol https --web
  run_as_target gh auth setup-git || true
}
