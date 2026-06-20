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

install_google_chrome() {
  if need_cmd google-chrome; then
    msg "Google Chrome already installed, skipping"
    return 0
  fi
  msg "Installing Google Chrome (stable)"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
  apt update -y
  apt install -y google-chrome-stable
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
  url="$(curl -fsSL "$release_api" |
    jq -r '.assets[]? | select(.name | test("_amd64[.]deb$")) | .browser_download_url' |
    head -n 1)"
  if [ -z "$url" ]; then
    log "error" "No amd64 Debian package found for Balena Etcher ${ETCHER_VERSION}."
    rm -rf "$tmpdir"
    return 1
  fi
  curl -fL "$url" -o "$tmpdir/balena-etcher.deb"
  apt install -y "$tmpdir/balena-etcher.deb"
  rm -rf "$tmpdir"
  msg "Balena Etcher installed"
}

install_gh_cli() {
  if need_cmd gh; then
    msg "GitHub CLI already installed, skipping"
    return 0
  fi
  msg "Installing GitHub CLI (gh)"
  apt_install curl apt-transport-https gnupg
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg bs=128 count=1 status=none
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  apt update -y
  apt install -y gh
}
