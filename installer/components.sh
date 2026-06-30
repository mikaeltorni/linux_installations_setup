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
  # CLI utilities and runtimes.
  "git|Git version-control CLI|on|lis_install_git|detect_git||Core CLI utilities"
  "curl|curl data-transfer CLI|on|lis_install_curl|detect_curl||Core CLI utilities"
  "gpg|GnuPG encryption/signing CLI|on|lis_install_gpg|detect_gpg||Core CLI utilities"
  "jq|jq JSON-processing CLI|on|lis_install_jq|detect_jq||Core CLI utilities"
  "p7zip|7-Zip archive CLI|on|lis_install_p7zip|detect_p7zip||Core CLI utilities"
  "nodejs|Node.js 22 runtime (includes npm)|on|install_nodejs_22|detect_nodejs_22||Core CLI utilities"
  "tmux|tmux terminal multiplexer|on|lis_install_tmux|detect_tmux||Core CLI utilities"
  "gh_cli|GitHub CLI|on|install_gh_cli|detect_gh_cli|uninstall_gh_cli|Core CLI utilities"
  "github_login|GitHub login (gh auth)|on|ensure_github_login|detect_github_login||Core CLI utilities"
  # Shared platform dependencies that are not login applications.
  "gnome_tooling|GNOME Shell extension & tweak tooling|on|lis_install_gnome_tooling|detect_gnome_tooling||System dependencies"
  "build_tools|Build toolchain & development headers|on|lis_install_build_tools|detect_build_tools||System dependencies"
  "python_runtime|Python runtime & libraries|on|lis_install_python_runtime|detect_python_runtime||System dependencies"
  "desktop_utils|X11 & desktop utilities (xdotool, screenshot)|on|lis_install_desktop_utils|detect_desktop_utils||System dependencies"
  "audio_speech|Audio stack & speech synthesis|on|lis_install_audio_speech|detect_audio_speech||System dependencies"
  # GUI applications. Every row in this section exposes [S] startup metadata.
  "terminal|Kitty terminal emulator|on|lis_install_terminal|detect_terminal||Desktop applications"
  "vlc|VLC media player|on|lis_install_vlc|detect_vlc|uninstall_vlc|Desktop applications"
  "obs|OBS Studio|on|lis_install_obs|detect_obs|uninstall_obs|Desktop applications"
  "easyeffects|EasyEffects audio effects|on|lis_install_easyeffects|detect_easyeffects|uninstall_easyeffects|Desktop applications"
  "remote_desktop|Remmina remote desktop client|on|lis_install_remote_desktop|detect_remote_desktop||Desktop applications"
  "virtualization|KVM/libvirt virtualization stack|on|lis_install_virtualization|detect_virtualization||Desktop applications"
  "chrome|Google Chrome|on|install_google_chrome|detect_chrome|uninstall_chrome|Desktop applications"
  "etcher|balenaEtcher|on|install_balena_etcher|detect_etcher|uninstall_etcher|Desktop applications"
  "snap_gitkraken|GitKraken (snap)|on|lis_install_snap_gitkraken|detect_snap_gitkraken|uninstall_snap_gitkraken|Desktop applications"
  "snap_spotify|Spotify (snap)|on|lis_install_snap_spotify|detect_snap_spotify|uninstall_snap_spotify|Desktop applications"
  "snap_discord|Discord (snap)|on|lis_install_snap_discord|detect_snap_discord|uninstall_snap_discord|Desktop applications"
  "albert|Albert launcher|on|install_albert|detect_albert|uninstall_albert|Desktop applications"
  "nvidia|NVIDIA drivers (if a GPU is detected)|on|lis_install_nvidia|detect_nvidia||Drivers & hardware"
)

# lis_preflight - require root and a usable session bus before any component.
lis_preflight() {
  ensure_root
  ensure_session_bus
}

# Per-feature package-group installers. Each wraps install_pkg_group with the
# corresponding APT_* array declared in install.sh so the shared single
# apt-update/idempotent path is reused.
lis_install_git()             { install_pkg_group "git"                           "${APT_GIT[@]}"; }
lis_install_curl()            { install_pkg_group "curl"                          "${APT_CURL[@]}"; }
lis_install_gpg()             { install_pkg_group "GnuPG"                         "${APT_GPG[@]}"; }
lis_install_jq()              { install_pkg_group "jq"                            "${APT_JQ[@]}"; }
lis_install_p7zip()          { install_pkg_group "7-Zip"                         "${APT_7ZIP[@]}"; }
lis_install_gnome_tooling()   { install_pkg_group "GNOME Shell tooling"           "${APT_GNOME_TOOLING[@]}"; }
lis_install_build_tools()     { install_pkg_group "build toolchain"               "${APT_BUILD_TOOLS[@]}"; }
lis_install_terminal()        { install_pkg_group "Kitty terminal"                "${APT_TERMINAL[@]}"; }
lis_install_python_runtime()  { install_pkg_group "Python runtime & libraries"    "${APT_PYTHON[@]}"; }
lis_install_desktop_utils()   { install_pkg_group "X11 & desktop utilities"       "${APT_DESKTOP_UTILS[@]}"; }
lis_install_audio_speech()    { install_pkg_group "audio & speech"                "${APT_AUDIO_SPEECH[@]}"; }
lis_install_vlc()             { install_pkg_group "VLC"                           "${APT_VLC[@]}"; }
lis_install_obs()             { install_pkg_group "OBS Studio"                    "${APT_OBS[@]}"; }
lis_install_easyeffects()     { install_pkg_group "EasyEffects"                   "${APT_EASYEFFECTS[@]}"; }
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
  printf 'obs\tcom.obsproject.Studio.desktop\n'
  printf 'easyeffects\tcom.github.wwmm.easyeffects.desktop\n'
  printf 'remote_desktop\torg.remmina.Remmina.desktop,remmina.desktop\n'
  printf 'chrome\tgoogle-chrome.desktop,com.google.Chrome.desktop\n'
  printf 'snap_gitkraken\tgitkraken.desktop,gitkraken_gitkraken.desktop\n'
  printf 'snap_spotify\tspotify.desktop,spotify_spotify.desktop\n'
  printf 'snap_discord\tdiscord.desktop,discord_discord.desktop\n'
  printf 'nvidia\tnvidia-settings.desktop\n'
  printf 'virtualization\tvirt-manager.desktop\n'
}

# lis_list_startup_components - Print app components that the master installer
# can configure to launch at desktop login with its [s] menu action.
#
# Output is id<TAB>desktop candidates<TAB>default. Pipe-separated filenames are
# alternatives for the same application. Defaults preserve the setup chain's
# existing Spotify, GitKraken, EasyEffects, and Albert startup behavior.
lis_list_startup_components() {
  printf 'terminal\tkitty.desktop\toff\n'
  printf 'vlc\tvlc.desktop\toff\n'
  printf 'obs\tcom.obsproject.Studio.desktop\toff\n'
  printf 'easyeffects\tcom.github.wwmm.easyeffects.desktop|org.gnome.EasyEffects.desktop\ton\n'
  printf 'remote_desktop\torg.remmina.Remmina.desktop|remmina.desktop\toff\n'
  printf 'chrome\tgoogle-chrome.desktop|com.google.Chrome.desktop\toff\n'
  printf 'etcher\tbalena-etcher.desktop|balenaEtcher.desktop\toff\n'
  printf 'snap_gitkraken\tgitkraken.desktop|gitkraken_gitkraken.desktop\ton\n'
  printf 'snap_spotify\tspotify.desktop|spotify_spotify.desktop\ton\n'
  printf 'snap_discord\tdiscord.desktop|discord_discord.desktop\toff\n'
  printf 'albert\talbert.desktop\ton\n'
  printf 'nvidia\tnvidia-settings.desktop\toff\n'
  printf 'virtualization\tvirt-manager.desktop\toff\n'
}
