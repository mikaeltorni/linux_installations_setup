#!/usr/bin/env bash
# app_installer.sh — Application installers (Chrome, Etcher, SmartGit, GH CLI)
#
# Components:
#   - install_google_chrome(): Download and install Google Chrome stable from official repo.
#   - install_balena_etcher(): Download, extract, and install Balena Etcher portable.
#   - install_smartgit(): Download and install the pinned official SmartGit archive.
#   - install_gh_cli(): Add GitHub CLI APT repo and install gh.
#   - lib/albert_installer.sh: Albert repository detection and installation.
#   - lib/snap_installer.sh: Snap application installation.

_APP_INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_APP_INSTALLER_DIR/albert_installer.sh"
source "$_APP_INSTALLER_DIR/snap_installer.sh"
unset _APP_INSTALLER_DIR

GH_CLI_APT_KEYRING="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
GH_CLI_APT_SOURCE="/etc/apt/sources.list.d/github-cli.list"

# SmartGit is distributed as an official Linux archive rather than an Ubuntu
# repository. Keep the release URL and SHA-256 together so clean installs are
# reproducible and a changed upstream artifact cannot be installed silently.
: "${SMARTGIT_VERSION:=26.1.052}"
: "${SMARTGIT_ARCHIVE_URL:=https://download.smartgit.dev/smartgit/smartgit-26_1_052-linux-amd64.tar.gz}"
: "${SMARTGIT_ARCHIVE_SHA256:=1c1c8cca8623cb336a951f2084b4681608591515d186bab7ee3f503d55e7c273}"
: "${SMARTGIT_INSTALL_ROOT:=/opt}"
: "${SMARTGIT_DESKTOP_FILE:=/usr/share/applications/smartgit.desktop}"
: "${SMARTGIT_LAUNCHER:=/usr/local/bin/smartgit}"

smartgit_install_dir() {
  printf '%s/smartgit-%s\n' "$SMARTGIT_INSTALL_ROOT" "$SMARTGIT_VERSION"
}

smartgit_current_dir() {
  printf '%s/smartgit\n' "$SMARTGIT_INSTALL_ROOT"
}

smartgit_runtime_package() {
  if apt-cache show libgtk-3-0t64 >/dev/null 2>&1; then
    printf '%s\n' libgtk-3-0t64
  elif apt-cache show libgtk-3-0 >/dev/null 2>&1; then
    printf '%s\n' libgtk-3-0
  else
    return 1
  fi
}

# smartgit_installation_complete - Check the managed SmartGit files.
#
# Returns success only when the versioned archive, stable symlink, launcher,
# PNG desktop icon, and desktop entry are all present and point at the current
# stable path. This lets reinstall/reconfigure repair a partially completed or
# stale deployment without treating an unrelated `smartgit` command in PATH as
# a complete installation.
smartgit_installation_complete() {
  local current_dir desktop_file
  current_dir="$(smartgit_current_dir)"
  desktop_file="$SMARTGIT_DESKTOP_FILE"
  [ -x "$current_dir/bin/smartgit.sh" ] || return 1
  [ -f "$current_dir/bin/smartgit.svg" ] || return 1
  [ -f "$current_dir/bin/smartgit-256.png" ] || return 1
  [ -L "$current_dir" ] || return 1
  [ -L "$SMARTGIT_LAUNCHER" ] || return 1
  [ -x "$SMARTGIT_LAUNCHER" ] || return 1
  [ -f "$desktop_file" ] || return 1
  grep -Fxq "Exec=$current_dir/bin/smartgit.sh %U" "$desktop_file" || return 1
  grep -Fxq "Icon=$current_dir/bin/smartgit-256.png" "$desktop_file"
}

install_smartgit() {
  local install_dir current_dir desktop_file launcher gtk_package
  install_dir="$(smartgit_install_dir)"
  current_dir="$(smartgit_current_dir)"
  desktop_file="$SMARTGIT_DESKTOP_FILE"
  launcher="$SMARTGIT_LAUNCHER"

  if smartgit_installation_complete; then
    msg "SmartGit ${SMARTGIT_VERSION} already installed, skipping"
    return 0
  fi

  msg "Installing SmartGit ${SMARTGIT_VERSION} from the official archive"
  if gtk_package="$(smartgit_runtime_package)"; then
    apt_install "$gtk_package"
  else
    log "warn" "No GTK 3 runtime package is available in the current APT cache; continuing with SmartGit archive installation."
  fi

  local tmpdir archive extracted
  tmpdir="$(mktemp -d)" || {
    log "error" "Could not create a temporary directory for SmartGit installation."
    return 1
  }
  archive="$tmpdir/smartgit.tar.gz"
  if ! curl -fsSL -o "$archive" -- "$SMARTGIT_ARCHIVE_URL"; then
    log "error" "Failed to download SmartGit archive from $SMARTGIT_ARCHIVE_URL"
    rm -rf -- "$tmpdir"
    return 1
  fi
  if ! printf '%s  %s\n' "$SMARTGIT_ARCHIVE_SHA256" "$archive" | sha256sum -c - >/dev/null; then
    log "error" "SmartGit archive checksum verification failed; refusing installation."
    rm -rf -- "$tmpdir"
    return 1
  fi
  if ! tar -xzf "$archive" -C "$tmpdir"; then
    log "error" "Failed to extract the SmartGit archive."
    rm -rf -- "$tmpdir"
    return 1
  fi
  extracted="$tmpdir/smartgit"
  if [ ! -x "$extracted/bin/smartgit.sh" ] || \
     [ ! -f "$extracted/bin/smartgit.svg" ] || \
     [ ! -f "$extracted/bin/smartgit-256.png" ]; then
    log "error" "SmartGit archive did not contain the expected launcher and PNG icon."
    rm -rf -- "$tmpdir"
    return 1
  fi

  {
    printf '%s\n' '[Desktop Entry]' 'Version=1.0' 'Type=Application' 'Name=SmartGit'
    printf '%s\n' 'Comment=Git client' "Exec=$current_dir/bin/smartgit.sh %U"
    printf '%s\n' "Icon=$current_dir/bin/smartgit-256.png" 'Terminal=false'
    printf '%s\n' 'Categories=Development;RevisionControl;' 'StartupNotify=true'
    printf '%s\n' 'StartupWMClass=SmartGit'
  } >"$tmpdir/smartgit.desktop"
  if command -v desktop-file-validate >/dev/null 2>&1 && \
     ! desktop-file-validate "$tmpdir/smartgit.desktop"; then
    log "error" "Generated SmartGit desktop entry failed validation."
    rm -rf -- "$tmpdir"
    return 1
  fi

  if ! install -m 0755 -d "$SMARTGIT_INSTALL_ROOT" "$(dirname "$desktop_file")" "$(dirname "$launcher")"; then
    log "error" "Could not create SmartGit installation directories."
    rm -rf -- "$tmpdir"
    return 1
  fi
  if [ -e "$install_dir" ] || [ -L "$install_dir" ]; then
    rm -rf -- "$install_dir"
  fi
  if ! mv "$extracted" "$install_dir"; then
    log "error" "Could not move SmartGit into $install_dir"
    rm -rf -- "$tmpdir"
    return 1
  fi
  if ! ln -sfn "$install_dir" "$current_dir" || \
     ! ln -sfn "$current_dir/bin/smartgit.sh" "$launcher" || \
     ! install -m 0644 "$tmpdir/smartgit.desktop" "$desktop_file"; then
    log "error" "Could not finish SmartGit launcher or desktop-entry installation."
    rm -rf -- "$tmpdir"
    return 1
  fi
  if command -v update-desktop-database >/dev/null 2>&1 && \
     ! update-desktop-database "$(dirname "$desktop_file")" >/dev/null 2>&1; then
    log "warn" "Could not refresh the desktop application database after SmartGit installation."
  fi
  rm -rf -- "$tmpdir"
  log "info" "SmartGit ${SMARTGIT_VERSION} installed at $current_dir"
}

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
