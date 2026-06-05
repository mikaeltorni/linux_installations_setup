#!/usr/bin/env bash
# install.sh — Linux Installation Setup (Phase 1 of 7)
#
# This installer handles base system setup:
#   - Installs base system packages and utilities
#   - Detects hardware (NVIDIA GPU) and installs drivers
#   - Installs applications (Chrome, Etcher, snaps, GH CLI, Albert)
#
# Note: Repository cloning and sub-repo orchestration is handled by the
# master installer at installation_scripts/install.sh. This script focuses
# only on base packages, hardware detection, and application installation.
#
# Usage: sudo bash install.sh

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="/run/user/${TARGET_UID}"
DISPLAY_VAL="${DISPLAY:-:0}"
USER_BUS="unix:path=${RUNTIME_DIR}/bus"

ETCHER_VERSION="${ETCHER_VERSION:-latest}"

source "$SCRIPT_DIR/lib/helpers.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/hardware.sh"
source "$SCRIPT_DIR/lib/apt_helpers.sh"
source "$SCRIPT_DIR/lib/system_services.sh"

APT_UPDATED=0
APT_BASE_PACKAGES=(
  gnome-shell-extension-manager chrome-gnome-shell make gettext kitty git curl gpg
  gnome-tweaks easyeffects vlc obs-studio pulseaudio-utils pipewire-audio
  speech-dispatcher espeak-ng sound-theme-freedesktop p7zip-full dconf-cli
  dconf-service build-essential pkg-config libx11-dev libxi-dev libev-dev
  xbindkeys jq gnome-shell-extension-prefs python3 python3-evdev python3-pil
  gnome-screenshot x11-xserver-utils x11-apps desktop-file-utils
  remmina remmina-plugin-rdp remmina-plugin-secret tmux
  virtinst virt-manager libvirt-daemon-system libvirt-clients bridge-utils
)

SNAP_APPS=("gitkraken --classic" "spotify" "discord")

INSTALLER_NO_REBOOT="${INSTALLER_NO_REBOOT:-0}"

main_inner() {
  ensure_root
  ensure_session_bus

  msg "=== Linux Installation Setup ==="

  install_base_packages

  install_google_chrome
  install_balena_etcher
  install_snaps
  install_gh_cli
  ensure_github_login
  install_albert

  if nvidia_gpu_detected; then
    install_nvidia_drivers
    enable_nvidia_services
  else
    msg "No NVIDIA GPU detected — skipping driver installation"
  fi

  msg "=== Linux Installation Setup Complete ==="
}

run_and_log_with_reboot() {
  local ts log_dir log_file
  ts=$(date +"%Y%m%d-%H%M%S")
  log_dir="$SCRIPT_DIR/.log"
  mkdir -p "$log_dir"
  log_file="$log_dir/linux_installations_setup-$ts.log"
  
  main_inner "$@" 2>&1 | tee "$log_file"
  msg "All done. Log file written to: $log_file"
  
  if [[ "${INSTALLER_NO_REBOOT:-0}" == "1" ]]; then
    msg "Skipping reboot due to INSTALLER_NO_REBOOT=1"
  else
    msg "Rebooting now in 10 seconds. Press Ctrl+C to cancel."
    sleep 10
    reboot
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_and_log_with_reboot "$@"
fi
