#!/usr/bin/env bash
# components.sh - Component manifest for linux_installations_setup.
#
# Maps each base-system feature to the install_* function that performs it.
# Every user-visible feature is its own independently selectable component.
# Components are default-on unless an installation is intentionally opt-in.
# install.sh sources the lib files first, then this manifest, then routes
# execution through component_main from
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
  "inotify_limits|Raise inotify instances/watches (desktop agents/tmux)|on|lis_configure_inotify_limits|detect_inotify_limits|uninstall_inotify_limits|System dependencies"
  "audio_speech|Audio stack & speech synthesis|on|lis_install_audio_speech|detect_audio_speech||System dependencies"
  # GUI applications. Every row in this section exposes [S] startup metadata.
  "terminal|Kitty terminal emulator|on|lis_install_terminal|detect_terminal||Desktop applications"
  "vlc|VLC media player|on|lis_install_vlc|detect_vlc|uninstall_vlc|Desktop applications"
  "obs|OBS Studio|on|lis_install_obs|detect_obs|uninstall_obs|Desktop applications"
  "easyeffects|EasyEffects audio effects|on|lis_install_easyeffects|detect_easyeffects|uninstall_easyeffects|Desktop applications"
  "remote_desktop|Remmina remote desktop client|on|lis_install_remote_desktop|detect_remote_desktop||Desktop applications"
  "baobab|Baobab disk usage analyzer|on|lis_install_baobab|detect_baobab||Desktop applications"
  "gparted|GParted partition editor|on|lis_install_gparted|detect_gparted||Desktop applications"
  "virtualization|KVM/libvirt virtualization stack|on|lis_install_virtualization|detect_virtualization||Desktop applications"
  "chrome|Google Chrome|on|install_google_chrome|detect_chrome|uninstall_chrome|Desktop applications"
  "etcher|balenaEtcher|on|install_balena_etcher|detect_etcher|uninstall_etcher|Desktop applications"
  "smartgit|SmartGit|off|install_smartgit|detect_smartgit|uninstall_smartgit|Desktop applications"
  "snap_gitkraken|GitKraken (snap)|on|lis_install_snap_gitkraken|detect_snap_gitkraken|uninstall_snap_gitkraken|Desktop applications"
  "snap_spotify|Spotify (snap)|on|lis_install_snap_spotify|detect_snap_spotify|uninstall_snap_spotify|Desktop applications"
  "snap_discord|Discord (snap)|on|lis_install_snap_discord|detect_snap_discord|uninstall_snap_discord|Desktop applications"
  "albert|Albert launcher|on|install_albert|detect_albert|uninstall_albert|Desktop applications"
  "essential_drivers|Essential hardware drivers (Linux firmware + Bluetooth)|off|lis_install_essential_drivers|detect_essential_drivers||Drivers & hardware"
  "bluetooth_kernel_fix|Bluetooth MT7922 kernel fix (author's system; selects 6.17.0-40)|off|lis_configure_bluetooth_kernel_boot|detect_bluetooth_kernel_boot||Drivers & hardware|essential_drivers"
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
lis_configure_inotify_limits() { configure_inotify_limits; }
lis_install_audio_speech()    { install_pkg_group "audio & speech"                "${APT_AUDIO_SPEECH[@]}"; }
lis_install_essential_drivers() { install_pkg_group "essential hardware drivers (Linux firmware + Bluetooth)" "${APT_ESSENTIAL_DRIVERS[@]}"; }
lis_configure_bluetooth_kernel_boot() { configure_bluetooth_kernel_boot; }
lis_install_vlc()             { install_pkg_group "VLC"                           "${APT_VLC[@]}"; }
lis_install_baobab()          { install_pkg_group "Baobab disk usage analyzer"  "${APT_BAOBAB[@]}"; }
lis_install_gparted() {
  # Install GParted through the shared package-group path.
  # Parameters: none.
  # Returns: the shared APT package installer status.
  printf '%s\n' 'parameters=none'
  local result=0
  install_pkg_group "GParted partition editor" "${APT_GPARTED[@]}" || result=$?
  printf '%s\n' "$result"
  return "$result"
}
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
  # Delegate NVIDIA setup and propagate policy deployment failures.
  # Parameters: none.
  # Returns: driver setup status, or zero when no hardware is detected.
  printf '%s\n' 'parameters=none'
  local result=0
  if nvidia_gpu_detected; then
    install_nvidia_drivers || result=$?
    if [ "$result" -eq 0 ]; then
      enable_nvidia_services || result=$?
    fi
  else
    msg "No NVIDIA GPU detected — skipping driver installation"
  fi
  printf '%s\n' "$result"
  return "$result"
}

# LIS_DESKTOP_APPS - Single desktop-application action-metadata table.
#
# One row per component that owns a launchable .desktop entry, covering every
# "Desktop applications" manifest row (plus nvidia, whose settings panel is a
# desktop app even though the component lives under "Drivers & hardware").
# Both lis_list_favorite_components and lis_list_startup_components derive
# from this table, so an app can never be eligible for one master-menu action
# ([f]/[s]/[1-9]/[p]) but silently excluded from another, and the .desktop
# candidates cannot drift between the lists.
#
# Row format:
#   "id|desktop candidates|startup default|favorite default|monitor default".
# Candidates are pipe-free here — use "&" between alternatives for the same
# application (converted to "|" for startup and "," for favourites output).
# Startup defaults preserve the setup chain's existing Spotify, GitKraken,
# SmartGit, EasyEffects, and Albert login behavior; favourite defaults keep the dock of
# a clean install unchanged (apps that were not favourite-eligible before the
# lists were unified default to off).
#
# The monitor default is the display number ([m] action, matching the numbering
# in GNOME Settings → Displays) an app's windows are pinned to. 0 means "no
# pin": the window opens wherever the session would place it anyway (on the
# monitor holding the pointer). Spotify and Discord default to monitor 1 —
# the requested media/chat screen — and every other app stays unpinned.
LIS_DESKTOP_APPS=(
  "terminal|kitty.desktop|off|on|0"
  "vlc|vlc.desktop|off|off|0"
  "obs|com.obsproject.Studio.desktop|off|on|0"
  "easyeffects|com.github.wwmm.easyeffects.desktop&org.gnome.EasyEffects.desktop|on|on|0"
  "remote_desktop|org.remmina.Remmina.desktop&remmina.desktop|off|on|0"
  "baobab|org.gnome.baobab.desktop|off|on|0"
  "gparted|gparted.desktop|off|off|0"
  "chrome|google-chrome.desktop&com.google.Chrome.desktop|off|on|0"
  "etcher|balena-etcher.desktop&balenaEtcher.desktop|off|off|0"
  "smartgit|smartgit.desktop|on|on|0"
  "snap_gitkraken|gitkraken.desktop&gitkraken_gitkraken.desktop|on|on|0"
  "snap_spotify|spotify.desktop&spotify_spotify.desktop|on|off|1"
  "snap_discord|discord.desktop&discord_discord.desktop|on|off|1"
  "albert|albert.desktop|on|off|0"
  "nvidia|nvidia-settings.desktop|off|on|0"
  "virtualization|virt-manager.desktop|off|on|0"
)

# lis_list_favorite_components - Print app components that can be pinned to the
# GNOME dock from the master program-installation menu.
#
# Output format is id<TAB>comma-separated .desktop ids<TAB>default(on/off).
# The master installer consumes this optional side-channel and passes the
# selected desktop ids to linux_configuration_setup's favorites component as
# SELECTED_FAVORITE_APPS. Derived from LIS_DESKTOP_APPS (see above).
lis_list_favorite_components() {
  local row id desktops _startup_default favorite_default _monitor_default
  for row in "${LIS_DESKTOP_APPS[@]}"; do
    IFS='|' read -r id desktops _startup_default favorite_default _monitor_default <<<"$row"
    printf '%s\t%s\t%s\n' "$id" "${desktops//&/,}" "$favorite_default"
  done
}

# lis_list_startup_components - Print app components that the master installer
# can configure to launch at desktop login with its [s] menu action. The same
# rows advertise workspace ([1-9]) and all-workspaces ([p]) eligibility.
#
# Output is id<TAB>desktop candidates<TAB>startup default<TAB>monitor default.
# Pipe-separated filenames are alternatives for the same application. The
# fourth column is the default display number for the [m] action (0 = none);
# masters that predate it simply ignore the extra column. Derived from
# LIS_DESKTOP_APPS.
lis_list_startup_components() {
  local row id desktops startup_default _favorite_default monitor_default
  for row in "${LIS_DESKTOP_APPS[@]}"; do
    IFS='|' read -r id desktops startup_default _favorite_default monitor_default <<<"$row"
    printf '%s\t%s\t%s\t%s\n' "$id" "${desktops//&/|}" "$startup_default" "${monitor_default:-0}"
  done
}
