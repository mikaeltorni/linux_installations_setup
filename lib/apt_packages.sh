#!/usr/bin/env bash
# apt_packages.sh — APT package management utilities
#
# Components:
#   - apt_update_once(): Update apt cache once per session.
#   - apt_install(packages...): Install packages (triggers apt_update_once).
#   - install_base_packages(): Install all packages in APT_BASE_PACKAGES array.

: "${APT_UPDATED:=0}"
: "${APT_BASE_PACKAGES:=()}"

apt_update_once() {
  if [ "$APT_UPDATED" -eq 0 ]; then
    msg "Updating apt cache (ignoring transient repo errors)"
    if ! apt update -y; then
      log "warn" "apt update returned non-zero, but continuing anyway."
      echo "WARNING: apt update returned non-zero, but continuing anyway."
    fi
    APT_UPDATED=1
  fi
}

# apt_install — Install one or more APT packages non-interactively.
#
# Parameters:
#   $@ (packages...): Package names (and apt options) to pass to `apt install`.
#
# Ensures the apt cache has been refreshed once this session before installing.
apt_install() {
  apt_update_once
  log "debug" "apt install: $*"
  DEBIAN_FRONTEND=noninteractive apt install -y "$@"
}

install_base_packages() {
  msg "Installing base utilities and desktop tools"
  if [ ${#APT_BASE_PACKAGES[@]} -gt 0 ]; then
    apt_install "${APT_BASE_PACKAGES[@]}"
  else
    log "warn" "APT_BASE_PACKAGES is empty, skipping base package install"
  fi
}

# install_pkg_group — install a labelled group of APT packages.
#
# Parameters:
#   $1 (label):       Human-readable description for the progress message.
#   $@ (packages...): Package names to install.
#
# Used by the per-feature components so each selectable group installs through
# the shared apt_install path (single apt-update, idempotent).
install_pkg_group() {
  local label="$1"
  shift
  msg "Installing ${label}"
  if [ "$#" -gt 0 ]; then
    apt_install "$@"
  else
    log "warn" "No packages for ${label}, skipping"
  fi
}
