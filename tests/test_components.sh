#!/usr/bin/env bash
# test_components.sh — Tests for the modular component manifest.
#
# Guards that every user-visible feature is exposed as an independently
# selectable component with an explicit default state, that each component maps to a defined
# install function, and that the per-feature package groups together reproduce
# the full APT_BASE_PACKAGES set (so a clean install installs everything unless
# the user deselects a feature).
#
# Run with: bash tests/test_components.sh

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_SCRIPT_DIR")"

run_tests() {
  local passed=0 failed=0 total=0

  check() {
    local description="$1"
    shift
    ((total++)) || true
    echo -n "  $description... "
    if "$@"; then
      echo "PASS"
      ((passed++)) || true
    else
      echo "FAIL"
      ((failed++)) || true
    fi
  }

  # Load install.sh's package/snap arrays and the component manifest in a
  # subshell with stubbed helpers (no system changes).
  load_env() {
    cd "$PROJECT_DIR"
    SCRIPT_DIR="$PROJECT_DIR"
    source lib/logging.sh
    msg() { :; }
    need_cmd() { command -v "$1" >/dev/null 2>&1; }
    run_as_target() { "$@"; }
    ensure_root() { :; }
    ensure_session_bus() { :; }
    nvidia_gpu_detected() { return 1; }
    # Extract just the APT_*/SNAP_* array declarations from install.sh. Capture
    # starts at an array assignment and ends at the line carrying its closing
    # ")" — handles both single-line and multi-line array literals.
    eval "$(awk '/^(APT|SNAP)_[A-Z0-9_]*=\(/{p=1} p{print} /\)/{if(p)p=0}' install.sh)"
    source lib/hardware.sh
    source lib/apt_helpers.sh
    source lib/system_services.sh
    source lib/nodejs_installer.sh
    source lib/bluetooth.sh
    source installer/components.sh
  }

  every_component_default_state_is_explicit() {
    ( load_env
      for entry in "${ISC_COMPONENTS[@]}"; do
        IFS='|' read -r _id _label default _fn <<< "$entry"
        [ "$default" = "on" ] || [ "$default" = "off" ] || exit 1
      done
    )
  }

  every_component_function_defined() {
    ( load_env
      for entry in "${ISC_COMPONENTS[@]}"; do
        local _id _label _default fn
        IFS='|' read -r _id _label _default fn _ <<<"$entry"
        declare -F "$fn" >/dev/null 2>&1 || exit 1
      done
    )
  }

  groups_cover_base_packages() {
    ( load_env
      local union=(
        "${APT_GIT[@]}" "${APT_CURL[@]}" "${APT_GPG[@]}" "${APT_JQ[@]}"
        "${APT_7ZIP[@]}" "${APT_GNOME_TOOLING[@]}" "${APT_BUILD_TOOLS[@]}"
        "${APT_TERMINAL[@]}" "${APT_PYTHON[@]}" "${APT_DESKTOP_UTILS[@]}"
        "${APT_AUDIO_SPEECH[@]}" "${APT_VLC[@]}" "${APT_OBS[@]}"
        "${APT_EASYEFFECTS[@]}" "${APT_REMOTE_DESKTOP[@]}"
        "${APT_TMUX[@]}" "${APT_VIRTUALIZATION[@]}"
      )
      local a b
      a="$(printf '%s\n' "${union[@]}" | sort)"
      b="$(printf '%s\n' "${APT_BASE_PACKAGES[@]}" | sort)"
      [ "$a" = "$b" ]
    )
  }

  feature_components_present() {
    ( load_env
      local ids
      ids="$(printf '%s\n' "${ISC_COMPONENTS[@]}" | cut -d'|' -f1)"
      for want in git curl gpg jq p7zip vlc obs easyeffects \
                  virtualization remote_desktop tmux \
                  snap_gitkraken snap_spotify snap_discord chrome etcher \
                  gh_cli github_login albert essential_drivers bluetooth_kernel_fix nvidia; do
        grep -qx "$want" <<< "$ids" || exit 1
      done
      ! grep -Eq '^(core_utils|multimedia)$' <<<"$ids"
    )
  }

  essential_driver_component_is_opt_in_and_complete() {
    ( load_env
      local entry actual
      entry="$(printf '%s\n' "${ISC_COMPONENTS[@]}" | awk -F'|' '$1 == "essential_drivers"')"
      [ "$entry" = "essential_drivers|Essential hardware drivers (Linux firmware + Bluetooth)|off|lis_install_essential_drivers|detect_essential_drivers||Drivers & hardware" ] || exit 1
      printf '%s\n' "${APT_ESSENTIAL_DRIVERS[@]}" | grep -qx linux-firmware
      printf '%s\n' "${APT_ESSENTIAL_DRIVERS[@]}" | grep -qx bluez
      apt_install() { printf '%s\n' "$*"; }
      actual="$(lis_install_essential_drivers)"
      [ "$actual" = "linux-firmware bluez" ] || exit 1
      declare -F detect_essential_drivers >/dev/null 2>&1
    )
  }

  bluetooth_kernel_fix_component_is_opt_in_and_depends_on_essential_drivers() {
    ( load_env
      local entry
      entry="$(printf '%s\n' "${ISC_COMPONENTS[@]}" | awk -F'|' '$1 == "bluetooth_kernel_fix"')"
      [ "$entry" = "bluetooth_kernel_fix|Bluetooth MT7922 kernel fix (author's system; selects 6.17.0-40)|off|lis_configure_bluetooth_kernel_boot|detect_bluetooth_kernel_boot||Drivers & hardware|essential_drivers" ] || exit 1
      declare -F lis_configure_bluetooth_kernel_boot >/dev/null 2>&1 || exit 1
      declare -F detect_bluetooth_kernel_boot >/dev/null 2>&1 || exit 1
      [ "${BLUETOOTH_KERNEL_VERSION:-6.17.0-40-generic}" = "6.17.0-40-generic" ]
    )
  }

  discrete_components_install_one_package_each() {
    ( load_env
      local entry id fn expected actual
      for entry in \
        'git|git' 'curl|curl' 'gpg|gpg' 'jq|jq' 'p7zip|p7zip-full' \
        'vlc|vlc' 'obs|obs-studio' 'easyeffects|easyeffects'; do
        IFS='|' read -r id expected <<<"$entry"
        fn="$(printf '%s\n' "${ISC_COMPONENTS[@]}" | awk -F'|' -v id="$id" '$1 == id { print $4 }')"
        apt_install() { printf '%s\n' "$*"; }
        actual="$($fn)"
        [ "$actual" = "$expected" ] || exit 1
      done
    )
  }

  keyring_hidden_dependency() {
    ( load_env
      local ids
      ids="$(printf '%s\n' "${ISC_COMPONENTS[@]}" | cut -d'|' -f1)"
      ! grep -qx keyring <<< "$ids" || exit 1
      printf '%s\n' "${APT_PYTHON[@]}" | grep -qx gnome-keyring
      printf '%s\n' "${APT_PYTHON[@]}" | grep -qx gir1.2-secret-1
      printf '%s\n' "${APT_PYTHON[@]}" | grep -qx dbus-daemon
    )
  }

  nodejs_22_component_contract() {
    ( load_env
      printf '%s\n' "${ISC_COMPONENTS[@]}" |
        grep -q '^nodejs|Node.js 22 runtime (includes npm)|on|install_nodejs_22|detect_nodejs_22||Core CLI utilities$' || exit 1
      declare -F install_nodejs_22 >/dev/null || exit 1
      declare -F detect_nodejs_22 >/dev/null || exit 1
    )
  }

  startup_metadata_covers_installed_desktop_apps() {
    ( load_env
      local output ids
      output="$(lis_list_startup_components)"
      ids="$(cut -f1 <<<"$output")"
      for want in terminal vlc obs easyeffects remote_desktop chrome etcher \
                  snap_gitkraken snap_spotify snap_discord albert nvidia \
                  virtualization; do
        grep -qx "$want" <<<"$ids" || exit 1
      done
      grep -qx $'vlc\tvlc.desktop\toff' <<<"$output"
      grep -qx $'obs\tcom.obsproject.Studio.desktop\toff' <<<"$output"
      grep -qx $'easyeffects\tcom.github.wwmm.easyeffects.desktop|org.gnome.EasyEffects.desktop\ton' <<<"$output"
      grep -qx $'snap_spotify\tspotify.desktop|spotify_spotify.desktop\ton' <<<"$output"
      grep -qx $'snap_discord\tdiscord.desktop|discord_discord.desktop\ton' <<<"$output"
      grep -qx $'chrome\tgoogle-chrome.desktop|com.google.Chrome.desktop\toff' <<<"$output"
    )
  }

  desktop_application_components_are_startup_capable() {
    ( load_env
      local startup_ids id label default fn detect uninstall section
      startup_ids="$(lis_list_startup_components | cut -f1)"
      for entry in "${ISC_COMPONENTS[@]}"; do
        IFS='|' read -r id label default fn detect uninstall section _ <<<"$entry"
        [ "$section" = "Desktop applications" ] || continue
        grep -qx "$id" <<<"$startup_ids" || exit 1
      done
    )
  }

  desktop_application_components_are_favorite_capable() {
    # Every "Desktop applications" component must be pinnable as a dock
    # favourite from the master menu — no hand-maintained exclusions (the old
    # split lists silently dropped vlc, etcher, and albert from favourites).
    ( load_env
      local favorite_ids id label default fn detect uninstall section
      favorite_ids="$(lis_list_favorite_components | cut -f1)"
      for entry in "${ISC_COMPONENTS[@]}"; do
        IFS='|' read -r id label default fn detect uninstall section _ <<<"$entry"
        [ "$section" = "Desktop applications" ] || continue
        grep -qx "$id" <<<"$favorite_ids" || exit 1
      done
    )
  }

  favorite_and_startup_lists_share_desktop_metadata() {
    # Both action lists are derived from LIS_DESKTOP_APPS, so an app can never
    # again be eligible for one action but not the other, and the .desktop
    # candidates can never drift apart between the two lists.
    ( load_env
      local fav_row start_row id fav_desktops start_desktops _default
      while IFS=$'\t' read -r id fav_desktops _default; do
        start_row="$(lis_list_startup_components | awk -F'\t' -v id="$id" '$1 == id')"
        [ -n "$start_row" ] || exit 1
        start_desktops="$(cut -f2 <<<"$start_row")"
        [ "${fav_desktops//,/|}" = "$start_desktops" ] || exit 1
      done < <(lis_list_favorite_components)
    )
  }

  favorite_defaults_preserve_existing_dock() {
    # Newly favourite-eligible apps must default OFF so unifying the metadata
    # does not change which icons a clean install pins to the dock.
    ( load_env
      local output
      output="$(lis_list_favorite_components)"
      grep -qx $'vlc\tvlc.desktop\toff' <<<"$output"
      grep -qx $'etcher\tbalena-etcher.desktop,balenaEtcher.desktop\toff' <<<"$output"
      grep -qx $'albert\talbert.desktop\toff' <<<"$output"
      grep -qx $'terminal\tkitty.desktop\ton' <<<"$output"
      grep -qx $'chrome\tgoogle-chrome.desktop,com.google.Chrome.desktop\ton' <<<"$output"
      grep -qx $'snap_spotify\tspotify.desktop,spotify_spotify.desktop\ton' <<<"$output"
    )
  }

  component_sections_are_contiguous() {
    ( load_env
      local entry section previous="" closed="" _id _label _default _fn _detect _uninstall
      for entry in "${ISC_COMPONENTS[@]}"; do
        IFS='|' read -r _id _label _default _fn _detect _uninstall section _ <<<"$entry"
        [ -n "$section" ] || exit 1
        if [ "$section" != "$previous" ]; then
          grep -Fxq "$section" <<<"$closed" && exit 1
          [ -n "$previous" ] && closed="${closed}${closed:+$'\n'}${previous}"
          previous="$section"
        fi
      done
    )
  }

  application_installers_do_not_bypass_startup_selection() {
    # The master [S] selector and linux_configuration_setup are the only
    # authority allowed to create per-application login launchers. Package
    # installers must not write ~/.config/autostart directly.
    ! grep -R -n -E '\.config/autostart|X-GNOME-Autostart-enabled' \
      "$PROJECT_DIR/lib" --include='*.sh'
  }

  check "every component has an explicit default state" every_component_default_state_is_explicit
  check "every component maps to a defined function" every_component_function_defined
  check "package groups reproduce APT_BASE_PACKAGES" groups_cover_base_packages
  check "all expected feature components are present" feature_components_present
  check "essential drivers are opt-in and install firmware plus BlueZ" essential_driver_component_is_opt_in_and_complete
  check "Bluetooth kernel fix is opt-in and depends on essential drivers" bluetooth_kernel_fix_component_is_opt_in_and_depends_on_essential_drivers
  check "discrete CLI and multimedia components install one package each" discrete_components_install_one_package_each
  check "keyring libraries are hidden in python runtime dependencies" keyring_hidden_dependency
  check "Node.js 22 is a default-on component" nodejs_22_component_contract
  check "startup metadata covers installed desktop apps" startup_metadata_covers_installed_desktop_apps
  check "every desktop application component supports [S]" desktop_application_components_are_startup_capable
  check "every desktop application component supports [f]" desktop_application_components_are_favorite_capable
  check "favorite and startup lists derive from one metadata table" favorite_and_startup_lists_share_desktop_metadata
  check "favorite defaults preserve the existing dock selection" favorite_defaults_preserve_existing_dock
  check "component menu sections are contiguous" component_sections_are_contiguous
  check "application installers do not bypass [S] startup selection" application_installers_do_not_bypass_startup_selection

  echo
  echo "Components tests: $passed passed, $failed failed, $total total"
  [ "$failed" -eq 0 ]
}

run_tests
