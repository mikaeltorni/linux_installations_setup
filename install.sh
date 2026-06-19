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
  gnome-screenshot x11-xserver-utils x11-apps xdotool desktop-file-utils
  remmina remmina-plugin-rdp remmina-plugin-secret tmux
  virtinst virt-manager libvirt-daemon-system libvirt-clients bridge-utils
)

SNAP_APPS=("gitkraken --classic" "spotify" "discord")

# Component selection runtime and this repository's component manifest. The
# manifest maps each component id to an install_* step from the lib files above.
# Load the shared installer component framework. Its single source of truth is
# the linux_installation_scripts_functions repository (cloned as a sibling by
# installation_scripts, or downloaded on demand) -- no per-repo vendored copy.
for __isc_d in "${ISC_FUNCTIONS_DIR:-}" \
               "$SCRIPT_DIR/../linux_installation_scripts_functions" \
               "$HOME/projects/linux_installation_scripts_functions"; do
  [ -n "$__isc_d" ] && [ -f "$__isc_d/component_loader.sh" ] && { source "$__isc_d/component_loader.sh"; break; }
done
declare -F isc_activate_components >/dev/null 2>&1 || \
  source <(curl -fsSL "https://raw.githubusercontent.com/mikaeltorni/linux_installation_scripts_functions/${ISC_FUNCTIONS_REF:-master}/component_loader.sh")
isc_activate_components
source "$SCRIPT_DIR/installer/components.sh"

INSTALLER_NO_REBOOT="${INSTALLER_NO_REBOOT:-0}"

# main_inner — install the selected base-system components. Selection (root
# preflight, NVIDIA detection, etc.) is resolved by component_main.
main_inner() {
  msg "=== Linux Installation Setup ==="
  component_main "$@"
  local rc=$?
  msg "=== Linux Installation Setup Complete ==="
  return $rc
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
    # Listing/help must print only their own output (the master installer parses
    # --list-components) and must not require root or trigger a reboot.
    case "${1:-}" in
      --list-components|--help|-h) component_main "$@"; exit $? ;;
    esac
    run_and_log_with_reboot "$@"
fi
