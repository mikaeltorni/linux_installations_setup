#!/usr/bin/env bash
# snap_installer.sh — Snap application installation
#
# Components:
#   - install_snaps(): Install configured SNAP_APPS entries and their options.
#
# Requires SNAP_APPS, msg(), log(), and apt_install() from the main installer.

install_snaps() {
  install_snap_apps "${SNAP_APPS[@]}"
}

# install_snap_apps — install one or more snap specs ("name [options]").
#
# Parameters:
#   $@ (specs...): Snap specs, each a name optionally followed by snap options.
#
# Ensures snapd is present, then installs each spec. Used by the per-app snap
# components so GitKraken, Spotify, and Discord are independently selectable.
install_snap_apps() {
  if [ "$#" -eq 0 ]; then
    log "warn" "SNAP_APPS is empty; no snap apps requested, skipping snap installation"
    return 0
  fi
  msg "Installing snap applications"
  apt_install snapd
  if command -v snap >/dev/null 2>&1; then
    for app_spec in "$@"; do
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
