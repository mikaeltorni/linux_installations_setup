#!/usr/bin/env bash
# lifecycle.sh - Detection and uninstall functions for linux_installations_setup.
#
# detect_* report live install state for --detect (read-only; safe without root).
# Uninstall is provided only for the discrete application components (Chrome,
# Etcher, the snaps, GitHub CLI, Albert). The base package GROUPS (core_utils,
# build_tools, python_runtime, keyring, ...) intentionally ship NO uninstall
# function: apt-removing shared system toolchains is dangerous and could break
# the desktop, so their [u] action only clears the install record (the shared
# runtime's safe fallback). Detection still reports them accurately.

# lis_pkgs_installed - true only when every named dpkg package is installed.
lis_pkgs_installed() {
  local p
  for p in "$@"; do dpkg -s "$p" >/dev/null 2>&1 || return 1; done
  [ "$#" -gt 0 ]
}

# lis_snap_installed - true when the snap named in $1 (first token) is present.
lis_snap_installed() {
  local name="${1%% *}"
  command -v snap >/dev/null 2>&1 && snap list "$name" >/dev/null 2>&1
}

# --- Detection: base package groups -----------------------------------------
detect_core_utils()     { lis_pkgs_installed "${APT_CORE_UTILS[@]}"; }
detect_gnome_tooling()  { lis_pkgs_installed "${APT_GNOME_TOOLING[@]}"; }
detect_build_tools()    { lis_pkgs_installed "${APT_BUILD_TOOLS[@]}"; }
detect_terminal()       { lis_pkgs_installed "${APT_TERMINAL[@]}"; }
detect_python_runtime() { lis_pkgs_installed "${APT_PYTHON[@]}"; }
detect_desktop_utils()  { lis_pkgs_installed "${APT_DESKTOP_UTILS[@]}"; }
detect_audio_speech()   { lis_pkgs_installed "${APT_AUDIO_SPEECH[@]}"; }
detect_multimedia()     { lis_pkgs_installed "${APT_MULTIMEDIA[@]}"; }
detect_keyring()        { lis_pkgs_installed "${APT_KEYRING[@]}"; }
detect_remote_desktop() { lis_pkgs_installed "${APT_REMOTE_DESKTOP[@]}"; }
detect_tmux()           { lis_pkgs_installed "${APT_TMUX[@]}"; }
detect_virtualization() { lis_pkgs_installed "${APT_VIRTUALIZATION[@]}"; }

# --- Detection: applications -------------------------------------------------
detect_chrome()        { need_cmd google-chrome || need_cmd google-chrome-stable; }
detect_etcher()        { need_cmd balena-etcher; }
detect_snap_gitkraken(){ lis_snap_installed "${SNAP_GITKRAKEN[@]}"; }
detect_snap_spotify()  { lis_snap_installed "${SNAP_SPOTIFY[@]}"; }
detect_snap_discord()  { lis_snap_installed "${SNAP_DISCORD[@]}"; }
detect_gh_cli()        { need_cmd gh; }
detect_github_login()  { need_cmd gh && gh auth status >/dev/null 2>&1; }
detect_albert()        { need_cmd albert; }
detect_nvidia()        { need_cmd nvidia-smi; }

# --- Uninstall: applications only (root-guarded) -----------------------------
lis_require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    msg "SKIP (requires sudo): $1"
    return 1
  fi
}

uninstall_chrome() {
  lis_require_root "remove Google Chrome" || return 0
  msg "Removing Google Chrome"
  apt remove -y google-chrome-stable 2>/dev/null || true
  rm -f /etc/apt/sources.list.d/google-chrome.list /etc/apt/keyrings/google-chrome.gpg
}
uninstall_etcher() {
  lis_require_root "remove balenaEtcher" || return 0
  msg "Removing balenaEtcher"
  apt remove -y balena-etcher balena-etcher-electron 2>/dev/null || true
}
uninstall_gh_cli() {
  lis_require_root "remove GitHub CLI" || return 0
  msg "Removing GitHub CLI"
  apt remove -y gh 2>/dev/null || true
}
uninstall_albert() {
  lis_require_root "remove Albert" || return 0
  msg "Removing Albert launcher"
  apt remove -y albert 2>/dev/null || true
}
uninstall_snap_gitkraken() { msg "Removing GitKraken snap"; command -v snap >/dev/null 2>&1 && snap remove gitkraken 2>/dev/null || true; }
uninstall_snap_spotify()   { msg "Removing Spotify snap";   command -v snap >/dev/null 2>&1 && snap remove spotify  2>/dev/null || true; }
uninstall_snap_discord()   { msg "Removing Discord snap";   command -v snap >/dev/null 2>&1 && snap remove discord  2>/dev/null || true; }
