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
