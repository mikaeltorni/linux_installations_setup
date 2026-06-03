#!/usr/bin/env bash
# system_services.sh — System service configuration (GitHub login, repo cloning)
#
# Components:
#   - ensure_github_login(): Check and prompt for GitHub CLI authentication.
#   - clone_repo(repo_name, dest_dir): Clone or update a single GitHub repo.
#   - clone_all_repos(): Clone all repos from CLONE_REPOS dictionary.

ensure_github_login() {
  msg "Checking GitHub CLI login for $TARGET_USER"
  if ! run_as_target bash -lc 'command -v gh >/dev/null 2>&1'; then
    echo "WARNING: gh is not available; phrase_automation clone will fall back to public git clone."
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

clone_repo() {
  local repo_name="$1" dest_dir="$2"
  if [ -z "$repo_name" ] || [ -z "$dest_dir" ]; then
    log "error" "clone_repo requires <repo_name> and <dest_dir>"
    return 1
  fi
  run_as_target mkdir -p "$(dirname "$dest_dir")"
  local repo_url="https://github.com/${repo_name}.git"
  if [ -d "$dest_dir/.git" ]; then
    msg "Updating existing $(basename "$dest_dir") repository..."
    run_as_target git -C "$dest_dir" pull || true
  else
    msg "Cloning $(basename "$dest_dir") repository..."
    run_as_target git clone "$repo_url" "$dest_dir" || {
      log "warn" "Failed to clone $repo_name; continuing anyway."
      return 0
    }
  fi
  chown -R "$TARGET_USER:$TARGET_USER" "$dest_dir"
}

clone_all_repos() {
  msg "=== Cloning configured repositories ==="
  for repo_name in "${!CLONE_REPOS[@]}"; do
    clone_repo "$repo_name" "${CLONE_REPOS[$repo_name]}"
  done
}
