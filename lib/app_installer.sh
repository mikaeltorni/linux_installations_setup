#!/usr/bin/env bash
# app_installer.sh — Application installers (Chrome, Etcher, snaps, GH CLI, Albert)
#
# Components:
#   - install_google_chrome(): Download and install Google Chrome stable from official repo.
#   - install_balena_etcher(): Download, extract, and install Balena Etcher portable.
#   - install_snaps(): Install snap applications (installs snapd if missing).
#   - install_gh_cli(): Add GitHub CLI APT repo and install gh.
#   - detect_albert_obs_series(): Detect Ubuntu codename for Albert OBS repo.
#   - install_albert(): Install Albert from OBS and enable autostart.

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
  msg "Installing Balena Etcher (portable linux-x64, ${ETCHER_VERSION})"
  apt_install curl unzip
  local tmpdir="/tmp/balena-etcher-install"
  rm -rf "$tmpdir"
  mkdir -p "$tmpdir"
  local url="https://github.com/balena-io/etcher/releases/download/v${ETCHER_VERSION}/balenaEtcher-${ETCHER_VERSION}-linux-x64.AppImage"
  curl -fL "$url" -o "$tmpdir/balena-etcher.AppImage"
  install -m 0755 -d /opt/balena-etcher
  cp "$tmpdir/balena-etcher.AppImage" /opt/balena-etcher/balena-etcher.AppImage
  ln -sf /opt/balena-etcher/balena-etcher.AppImage /usr/local/bin/balena-etcher
  rm -rf "$tmpdir"
  msg "Balena Etcher installed to /opt/balena-etcher"
}

install_snaps() {
  if [ ${#SNAP_APPS[@]} -eq 0 ]; then
    log "warn" "SNAP_APPS is empty, skipping snap installation"
    return 0
  fi
  msg "Installing snap applications"
  apt_install snapd
  if command -v snap >/dev/null 2>&1; then
    for app_spec in "${SNAP_APPS[@]}"; do
      read -r snap_name snap_options <<< "$app_spec"
      if [ -z "${snap_options:-}" ]; then
        msg "  Installing snap: $snap_name"
        snap install "$snap_name" || log "warn" "Failed to install snap: $snap_name"
      else
        msg "  Installing snap: $snap_name with options: $snap_options"
        snap install "$snap_name" $snap_options || log "warn" "Failed to install snap: $snap_name $snap_options"
      fi
    done
  else
    log "error" "snapd installed but snap command not available; skipping snap apps"
  fi
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
    tee /etc/apt/sources.list.d/github-cli-list > /dev/null
  apt update -y
  apt install -y gh
}

detect_albert_obs_series() {
  if [ -n "${ALBERT_OBS_SERIES:-}" ]; then
    printf '%s\n' "$ALBERT_OBS_SERIES"
    return 0
  fi
  local codename="" version_id="" os_release=""
  if command -v lsb_release >/dev/null 2>&1; then
    codename="$(lsb_release -cs 2>/dev/null || true)"
    version_id="$(lsb_release -rs 2>/dev/null || true)"
  fi
  if [ -r /etc/os-release ]; then
    os_release="$(cat /etc/os-release)"
    codename="${codename:-$(printf '%s\n' "$os_release" | awk -F= '$1=="VERSION_CODENAME"{gsub(/"/, "", $2); print $2; exit}')}"
    codename="${codename:-$(printf '%s\n' "$os_release" | awk -F= '$1=="UBUNTU_CODENAME"{gsub(/"/, "", $2); print $2; exit}')}"
    version_id="${version_id:-$(printf '%s\n' "$os_release" | awk -F= '$1=="VERSION_ID"{gsub(/"/, "", $2); print $2; exit}')}"
  fi
  case "${codename}:${version_id}" in
    noble:*|*:24.04*) echo "xUbuntu_24.04" ;;
    jammy:*|*:22.04*) echo "xUbuntu_22.04" ;;
    focal:*|*:20.04*) echo "xUbuntu_20.04" ;;
    *) echo "" ;;
  esac
}

install_albert() {
  local series
  series="$(detect_albert_obs_series)" || true
  if [ -z "$series" ]; then
    log "warn" "Could not detect Ubuntu codename for Albert OBS repo; skipping Albert install."
    return 0
  fi
  msg "Installing Albert launcher from OBS (${series})"
  if [ ! -f /etc/apt/sources.list.d/home:manuelschneid3r.list ]; then
    echo "deb http://download.opensuse.org/repositories/home:/manuelschneid3r/${series}/ /" \
      > /etc/apt/sources.list.d/home:manuelschneid3r.list
    curl -fsSL "https://download.opensuse.org/repositories/home:/manuelschneid3r/${series}/Release.key" \
      | gpg --dearmor > /etc/apt/trusted.gpg.d/home_manuelschneid3r.gpg
    if ! apt update -y; then
      log "error" "apt update failed while adding Albert OBS repo; skipping Albert install."
      return 0
    fi
  fi
  if ! apt install -y albert; then
    log "error" "Failed to install albert from OBS (${series}); skipping Albert autostart."
    rm -f /etc/apt/sources.list.d/home:manuelschneid3r.list /etc/apt/trusted.gpg.d/home_manuelschneid3r.gpg
    return 0
  fi
  run_as_target mkdir -p "$TARGET_HOME/.config/autostart"
  cp /usr/share/applications/albert.desktop "$TARGET_HOME/.config/autostart/" || true
  msg "Albert launcher installed and enabled for autostart"
}
