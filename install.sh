#!/usr/bin/env bash
# install.sh — Linux Installation Setup (Phase 1 of 7)
#
# This is the master installer that:
#   1. Installs base system packages and utilities
#   2. Detects hardware (NVIDIA GPU) and installs drivers
#   3. Installs applications (Chrome, Etcher, snaps, GH CLI, Albert)
#   4. Clones and runs all subsequent setup repos in order:
#      - linux_configuration_setup
#      - linux_hotkey_setup
#      - agent_command_center
#      - linux_programming_setup
#      - ubuntu_2404_taskbar_system_status_monitor
#      - phrase_automation
#
# Usage: sudo bash install.sh

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/configs"
RUNTIME_DIR="/run/user/${TARGET_UID}"
DISPLAY_VAL="${DISPLAY:-:0}"
USER_BUS="unix:path=${RUNTIME_DIR}/bus"

ETCHER_VERSION="${ETCHER_VERSION:-2.1.4}"

declare -A CLONE_REPOS=(
  ["mikaeltorni/linux_configuration_setup"]="$TARGET_HOME/projects/linux_configuration_setup"
  ["mikaeltorni/linux_hotkey_setup"]="$TARGET_HOME/projects/linux_hotkey_setup"
  ["mikaeltorni/agent_command_center"]="$TARGET_HOME/projects/agent_command_center"
  ["mikaeltorni/linux_programming_setup"]="$TARGET_HOME/projects/linux_programming_setup"
  ["mikaeltorni/ubuntu_2404_taskbar_system_status_monitor"]="$TARGET_HOME/projects/ubuntu_2404_taskbar_system_status_monitor"
  ["mikaeltorni/phrase_automation"]="$TARGET_HOME/projects/phrase_automation"
)

source "$SCRIPT_DIR/lib/helpers.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/hardware.sh"
source "$SCRIPT_DIR/lib/system_services.sh"
source "$SCRIPT_DIR/lib/apt_helpers.sh"
source "$SCRIPT_DIR/lib/app_installer.sh"

APT_UPDATED=0
APT_BASE_PACKAGES=(
  gnome-shell-extension-manager chrome-gnome-shell make gettext kitty git curl gpg
  gnome-tweaks easyeffects vlc obs-studio pulseaudio-utils pipewire-audio
  speech-dispatcher espeak-ng sound-theme-freedesktop p7zip-full dconf-cli
  dconf-service build-essential pkg-config libx11-dev libxi-dev libev-dev
  xbindkeys jq gnome-shell-extension-prefs python3 python3-evdev
  gnome-screenshot x11-xserver-utils x11-apps icoutils desktop-file-utils
  remmina remmina-plugin-rdp remmina-plugin-secret tmux
)

SNAP_APPS=("gitkraken --classic" "spotify" "discord")

INSTALLER_APPLY_HOTKEYS_ONLY="${INSTALLER_APPLY_HOTKEYS_ONLY:-0}"
INSTALLER_NO_REBOOT="${INSTALLER_NO_REBOOT:-0}"

main_inner() {
  ensure_session_bus
  ensure_root

  msg "=== Linux Installation Setup ==="
  
  # Phase 1: Install base packages
  install_base_packages
  
  # Phase 2: Clone all dependent repos
  clone_all_repos
  
  # Phase 3: Run configuration setup (GNOME, GSettings, autostart)
  run_linux_configuration_setup
  
  # Phase 4: Run hotkey setup
  run_linux_hotkey_setup
  
  # Phase 5: Install applications
  install_google_chrome
  install_balena_etcher
  install_snaps
  install_gh_cli
  ensure_github_login
  install_albert
  
  # Phase 6: Hardware detection and drivers
  if nvidia_gpu_detected; then
    enable_nvidia_services
  else
    msg "No NVIDIA GPU detected — skipping driver installation"
  fi
  
  # Phase 7: Run remaining repo installers
  run_linux_programming_setup
  
  # Phase 8: Agent command center (desktop + runtime)
  local acc_dir="$TARGET_HOME/projects/agent_command_center"
  if [ -d "$acc_dir" ]; then
    msg "Running Agent Command Center setup..."
    if [ -f "$acc_dir/scripts/desktop_installer.sh" ]; then
      INSTALLATION_SCRIPTS_DIR="${SCRIPT_DIR}" \
        sudo -H -u "$TARGET_USER" bash "$acc_dir/scripts/desktop_installer.sh" || true
    fi
    if [ -f "$acc_dir/scripts/runtime_installer.sh" ]; then
      INSTALLATION_SCRIPTS_DIR="${SCRIPT_DIR}" \
        sudo -H -u "$TARGET_USER" bash "$acc_dir/scripts/runtime_installer.sh" || true
    fi
  else
    msg "WARN: Agent Command Center not cloned — skipping agent setup"
  fi
  
  # Phase 9: Taskbar system status monitor extension
  local tbm_dir="$TARGET_HOME/projects/ubuntu_2404_taskbar_system_status_monitor"
  if [ -d "$tbm_dir" ] && [ -x "$tbm_dir/install.sh" ]; then
    msg "Running taskbar system status monitor setup..."
    (cd "$tbm_dir" && sudo -H -u "$TARGET_USER" bash install.sh) || true
  else
    msg "WARN: Taskbar monitor not cloned — skipping extension setup"
  fi
  
  # Phase 10: Phrase automation tmux service
  configure_phrase_automation_tmux_service
  
  msg "=== Linux Installation Setup Complete ==="
}

run_linux_configuration_setup() {
  local lcs_dir="$TARGET_HOME/projects/linux_configuration_setup"
  if [ -d "$lcs_dir" ] && [ -f "$lcs_dir/install.sh" ]; then
    msg "Running linux_configuration_setup installer"
    (cd "$lcs_dir" && sudo -H -u "$TARGET_USER" bash install.sh) || \
      log "warn" "linux_configuration_setup installer failed (continuing)"
  else
    msg "WARN: linux_configuration_setup not found — skipping configuration setup"
  fi
}

run_linux_hotkey_setup() {
  local lhs_dir="$TARGET_HOME/projects/linux_hotkey_setup"
  if [ -d "$lhs_dir" ] && [ -f "$lhs_dir/install.sh" ]; then
    msg "Running linux_hotkey_setup installer"
    (cd "$lhs_dir" && sudo -H -u "$TARGET_USER" bash install.sh) || \
      log "warn" "linux_hotkey_setup installer failed (continuing)"
  else
    msg "WARN: linux_hotkey_setup not found — skipping hotkey setup"
  fi
}

configure_phrase_automation_tmux_service() {
  local phrasing_dir="${PHRASE_AUTOMATION_DIR:-$TARGET_HOME/projects/phrase_automation}"
  if [ ! -d "$phrasing_dir" ]; then
    msg "WARN: phrase_automation not cloned — skipping tmux service setup"
    return 0
  fi
  
  msg "Configuring phrase_automation tmux service"
  local service_file="$TARGET_HOME/.config/systemd/user/phrase-automation-tmux.service"
  
  run_as_target mkdir -p "$(dirname "$service_file")"
  run_as_target tee "$service_file" >/dev/null <<EOF
[Unit]
Description=Phrase Automation Tmux Session
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/tmux new-session -d -s phrase_automation "tmux attach -t phrase_automation"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
  
  run_as_target systemctl --user daemon-reload || true
  run_as_target systemctl --user enable phrase-automation-tmux.service || true
}

run_and_log_with_reboot() {
  local ts log_file
  ts=$(date +"%Y%m%d-%H%M%S")
  log_file="./linux_installations_setup-$ts.log"
  if ! touch "$log_file" 2>/dev/null; then
    log_file="/tmp/linux_installations_setup-$ts.log"
  fi
  
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
