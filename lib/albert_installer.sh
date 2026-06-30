#!/usr/bin/env bash
# albert_installer.sh — Albert launcher repository detection and installation
#
# Components:
#   - detect_albert_obs_series(): Map the host Ubuntu release to an OBS series.
#   - install_albert(): Install Albert. Login startup is owned by the master [S]
#     selection and linux_configuration_setup.

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
    log "error" "Failed to install albert from OBS (${series})."
    rm -f /etc/apt/sources.list.d/home:manuelschneid3r.list /etc/apt/trusted.gpg.d/home_manuelschneid3r.gpg
    return 0
  fi
  msg "Albert launcher installed"
}
