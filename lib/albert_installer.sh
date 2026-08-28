#!/usr/bin/env bash
# albert_installer.sh — Albert launcher repository detection and installation
#
# Components:
#   - detect_albert_obs_series(): Map the host Ubuntu release to an OBS series.
#   - install_albert(): Install Albert. Login startup is owned by the master [S]
#     selection and linux_configuration_setup. The native Applications provider
#     is enabled here so installed desktop entries are searchable immediately.

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

configure_albert_applications_plugin() {
  local config="$TARGET_HOME/.config/albert/config"

  msg "Enabling Albert Applications provider"
  if ! run_as_target bash -c '
    set -e
    config="$1"
    install -m 0755 -d "$(dirname "$config")"
    [ -f "$config" ] || : >"$config"

    tmp="$(mktemp "${config}.tmp.XXXXXX")"
    trap '\''rm -f -- "$tmp"'\'' EXIT
    awk '\''
      function add_enabled() {
        if (in_applications && !enabled_seen) {
          print "enabled=true"
          enabled_seen=1
        }
      }
      /^\[/ {
        if ($0 == "[applications]") {
          applications_seen=1
          in_applications=1
          print
          next
        }
        if (in_applications) {
          add_enabled()
          in_applications=0
        }
      }
      in_applications && /^[[:space:]]*enabled[[:space:]]*=/ {
        if (!enabled_seen) {
          print "enabled=true"
          enabled_seen=1
        }
        next
      }
      { print }
      END {
        if (in_applications) add_enabled()
        if (!applications_seen) {
          print ""
          print "[applications]"
          print "enabled=true"
        }
      }
    '\'' "$config" >"$tmp"
    install -m 0644 "$tmp" "$config"
  ' _ "$config"; then
    log "warn" "Could not enable Albert Applications provider in $config."
    return 1
  fi
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
  configure_albert_applications_plugin || true
  msg "Albert launcher installed"
}
