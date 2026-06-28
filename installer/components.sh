#!/usr/bin/env bash
# components.sh - Component manifest for linux_installations_setup.
#
# Maps each base-system feature to the install_* function that performs it.
# Every user-visible feature is its own independently selectable component, all
# default-on, so a clean install reproduces the full setup while the user can
# deselect any feature. install.sh sources the lib files first, then this
# manifest, then routes execution through component_main from
# component_runtime.sh.
#
# This repository hard-requires root: lis_preflight aborts the run if not root.
# The master installer skips it entirely in user mode.
#
# Entry format: "id|label|default(on/off)|function".

ISC_REPO_NAME="linux_installations_setup"
ISC_REPO_LABEL="Base packages, drivers and applications"

ISC_PREFLIGHT="lis_preflight"

ISC_COMPONENTS=(
  # Base package groups — every feature is independently selectable, all on by
  # default so a clean install reproduces the full set.
  "core_utils|Core CLI utilities (git, curl, gpg, jq, 7zip)|on|lis_install_core_utils|detect_core_utils"
  "gnome_tooling|GNOME Shell extension & tweak tooling|on|lis_install_gnome_tooling|detect_gnome_tooling"
  "build_tools|Build toolchain & development headers|on|lis_install_build_tools|detect_build_tools"
  "terminal|Kitty terminal emulator|on|lis_install_terminal|detect_terminal"
  "python_runtime|Python runtime & libraries|on|lis_install_python_runtime|detect_python_runtime"
  "desktop_utils|X11 & desktop utilities (xdotool, screenshot)|on|lis_install_desktop_utils|detect_desktop_utils"
  "audio_speech|Audio stack & speech synthesis|on|lis_install_audio_speech|detect_audio_speech"
  "multimedia|Multimedia apps (VLC, OBS, EasyEffects)|on|lis_install_multimedia|detect_multimedia"
  "remote_desktop|Remmina remote desktop client|on|lis_install_remote_desktop|detect_remote_desktop"
  "tmux|tmux terminal multiplexer|on|lis_install_tmux|detect_tmux"
  "virtualization|KVM/libvirt virtualization stack|on|lis_install_virtualization|detect_virtualization"
  # Applications. Detection plus a safe per-app uninstall (root-guarded). Base
  # package groups above intentionally have no destructive uninstall.
  "chrome|Google Chrome|on|install_google_chrome|detect_chrome|uninstall_chrome"
  "etcher|balenaEtcher|on|install_balena_etcher|detect_etcher|uninstall_etcher"
  "snap_gitkraken|GitKraken (snap)|on|lis_install_snap_gitkraken|detect_snap_gitkraken|uninstall_snap_gitkraken"
  "snap_spotify|Spotify (snap)|on|lis_install_snap_spotify|detect_snap_spotify|uninstall_snap_spotify"
  "snap_discord|Discord (snap)|on|lis_install_snap_discord|detect_snap_discord|uninstall_snap_discord"
  "gh_cli|GitHub CLI|on|install_gh_cli|detect_gh_cli|uninstall_gh_cli"
  "github_login|GitHub login (gh auth)|on|ensure_github_login|detect_github_login"
  "albert|Albert launcher|on|install_albert|detect_albert|uninstall_albert"
  "nvidia|NVIDIA drivers (if a GPU is detected)|on|lis_install_nvidia|detect_nvidia"
)

# lis_preflight - require root and a usable session bus before any component.
lis_preflight() {
  ensure_root
  ensure_session_bus
}

# Per-feature package-group installers. Each wraps install_pkg_group with the
# corresponding APT_* array declared in install.sh so the shared single
# apt-update/idempotent path is reused.
lis_install_core_utils()      { install_pkg_group "core CLI utilities"            "${APT_CORE_UTILS[@]}"; }
lis_install_gnome_tooling()   { install_pkg_group "GNOME Shell tooling"           "${APT_GNOME_TOOLING[@]}"; }
lis_install_build_tools()     { install_pkg_group "build toolchain"               "${APT_BUILD_TOOLS[@]}"; }
lis_install_terminal()        { install_pkg_group "Kitty terminal"                "${APT_TERMINAL[@]}"; }
lis_install_python_runtime()  { install_pkg_group "Python runtime & libraries"    "${APT_PYTHON[@]}"; }
lis_install_desktop_utils()   { install_pkg_group "X11 & desktop utilities"       "${APT_DESKTOP_UTILS[@]}"; }
lis_install_audio_speech()    { install_pkg_group "audio & speech"                "${APT_AUDIO_SPEECH[@]}"; }
lis_install_multimedia()      { install_pkg_group "multimedia apps"               "${APT_MULTIMEDIA[@]}"; }
lis_install_remote_desktop()  { install_pkg_group "Remmina remote desktop"        "${APT_REMOTE_DESKTOP[@]}"; }
lis_install_tmux()            { install_pkg_group "tmux"                          "${APT_TMUX[@]}"; }
lis_install_virtualization()  { install_pkg_group "KVM/libvirt virtualization"    "${APT_VIRTUALIZATION[@]}"; }

# Per-application snap installers.
lis_install_snap_gitkraken()  { install_snap_apps "${SNAP_GITKRAKEN[@]}"; }
lis_install_snap_spotify()    { install_snap_apps "${SNAP_SPOTIFY[@]}"; }
lis_install_snap_discord()    { install_snap_apps "${SNAP_DISCORD[@]}"; }

# lis_install_nvidia - install NVIDIA drivers and enable their services only
# when an NVIDIA GPU is present; otherwise report and skip.
lis_install_nvidia() {
  if nvidia_gpu_detected; then
    install_nvidia_drivers
    enable_nvidia_services
  else
    msg "No NVIDIA GPU detected — skipping driver installation"
  fi
}

# lis_list_favorite_components - Print app components that can be pinned to the
# GNOME dock from the master program-installation menu.
#
# Output format is id<TAB>comma-separated .desktop ids. The master installer
# consumes this optional side-channel and passes the selected desktop ids to
# linux_configuration_setup's favorites component as SELECTED_FAVORITE_APPS.
lis_list_favorite_components() {
  printf 'terminal\tkitty.desktop\n'
  printf 'multimedia\tcom.obsproject.Studio.desktop,com.github.wwmm.easyeffects.desktop\n'
  printf 'remote_desktop\torg.remmina.Remmina.desktop,remmina.desktop\n'
  printf 'chrome\tgoogle-chrome.desktop,com.google.Chrome.desktop\n'
  printf 'snap_gitkraken\tgitkraken.desktop,gitkraken_gitkraken.desktop\n'
  printf 'snap_spotify\tspotify.desktop,spotify_spotify.desktop\n'
  printf 'snap_discord\tdiscord.desktop,discord_discord.desktop\n'
  printf 'nvidia\tnvidia-settings.desktop\n'
  printf 'virtualization\tvirt-manager.desktop\n'
}
