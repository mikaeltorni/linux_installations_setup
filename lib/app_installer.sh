#!/usr/bin/env bash
# app_installer.sh — Application installers (Chrome, Etcher, GH CLI)
#
# Components:
#   - install_google_chrome(): Download and install Google Chrome stable from official repo.
#   - install_balena_etcher(): Download, extract, and install Balena Etcher portable.
#   - install_gh_cli(): Add GitHub CLI APT repo and install gh.
#   - lib/albert_installer.sh: Albert repository detection and installation.
#   - lib/snap_installer.sh: Snap application installation.

_APP_INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_APP_INSTALLER_DIR/albert_installer.sh"
source "$_APP_INSTALLER_DIR/snap_installer.sh"
unset _APP_INSTALLER_DIR

GH_CLI_APT_KEYRING="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
GH_CLI_APT_SOURCE="/etc/apt/sources.list.d/github-cli.list"

# gh_cli_apt_source_has_readable_keyring - validate the configured gh apt key.
#
# Returns success when no GitHub CLI source is configured, or when its
# signed-by keyring exists and is non-empty. A missing key leaves apt update
# broken even if the gh binary is already installed, so detection uses this to
# force a repair pass.
gh_cli_apt_source_has_readable_keyring() {
  [ -f "$GH_CLI_APT_SOURCE" ] || return 0
  local signed_by
  signed_by="$(sed -n 's/.*signed-by=\([^] ]*\).*/\1/p' "$GH_CLI_APT_SOURCE" | head -n 1)"
  [ -n "$signed_by" ] && [ -s "$signed_by" ]
}

install_google_chrome() {
  if need_cmd google-chrome; then
    msg "Google Chrome already installed, skipping"
    return 0
  fi
  msg "Installing Google Chrome (stable)"
  install -m 0755 -d /etc/apt/keyrings
  if ! curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg; then
    log "error" "Failed to download Google signing key; skipping Chrome installation."
    return 0
  fi
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
  if ! apt update -y; then
    log "error" "apt update failed while adding Google Chrome repository."
    return 0
  fi
  if ! apt install -y google-chrome-stable; then
    log "error" "Failed to install google-chrome-stable package."
    rm -f /etc/apt/sources.list.d/google-chrome.list
    return 0
  fi
}

install_balena_etcher() {
  if need_cmd balena-etcher; then
    msg "balena-etcher already in PATH, skipping"
    return 0
  fi
  msg "Installing Balena Etcher (${ETCHER_VERSION})"
  apt_install curl jq
  local tmpdir="/tmp/balena-etcher-install"
  local release_api
  if [[ "$ETCHER_VERSION" == "latest" ]]; then
    release_api="https://api.github.com/repos/balena-io/etcher/releases/latest"
  else
    release_api="https://api.github.com/repos/balena-io/etcher/releases/tags/v${ETCHER_VERSION#v}"
  fi
  rm -rf "$tmpdir"
  mkdir -p "$tmpdir"
  local url
  url="$(curl -fsSL "$release_api" | jq -r '.assets[]? | select(.name | test("_amd64[.]deb$")) | .browser_download_url' | head -n 1)" || { log "error" "Failed to query Etcher release API"; rm -rf "$tmpdir"; return 0; }
  if [ -z "$url" ]; then
    log "error" "No amd64 Debian package found for Balena Etcher ${ETCHER_VERSION}."
    rm -rf "$tmpdir"
    return 0
  fi
  if ! curl -fL "$url" -o "$tmpdir/balena-etcher.deb"; then
    log "error" "Failed to download Etcher package from $url"
    rm -rf "$tmpdir"
    return 0
  fi
  if ! apt install -y "$tmpdir/balena-etcher.deb"; then
    log "error" "Failed to install balena-etcher .deb package."
    rm -rf "$tmpdir"
    return 0
  fi
  rm -rf "$tmpdir"
  msg "Balena Etcher installed successfully"
}

install_gh_cli() {
  if need_cmd gh && gh_cli_apt_source_has_readable_keyring; then
    msg "GitHub CLI already installed, skipping"
    return 0
  fi
  if need_cmd gh; then
    log "warn" "GitHub CLI binary exists but its apt source keyring is missing or empty; repairing repository configuration."
  fi
  msg "Installing GitHub CLI (gh)"
  apt_install curl apt-transport-https gnupg
  local keyring="$GH_CLI_APT_KEYRING"
  local tmp_keyring="${keyring}.tmp"
  local source_list="$GH_CLI_APT_SOURCE"
  install -m 0755 -d /etc/apt/keyrings /etc/apt/sources.list.d
  log "info" "Downloading GitHub CLI apt keyring to ${keyring}"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$tmp_keyring"
  chmod 0644 "$tmp_keyring"
  mv "$tmp_keyring" "$keyring"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=${keyring}] https://cli.github.com/packages stable main" > "$source_list"
  if ! apt update -y; then
    log "error" "apt update failed after adding GitHub CLI repo; removing that source and falling back to Ubuntu gh package."
    rm -f "$source_list" "$keyring" "$tmp_keyring"
    apt update -y || log "warn" "apt update still failed after removing GitHub CLI repo; attempting gh install from existing package indexes."
  fi
  apt install -y gh
}
