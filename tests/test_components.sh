#!/usr/bin/env bash
# test_components.sh — Tests for the modular component manifest.
#
# Guards that every user-visible feature is exposed as an independently
# selectable, default-on component, that each component maps to a defined
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
    eval "$(awk '/^(APT|SNAP)_[A-Z_]*=\(/{p=1} p{print} /\)/{if(p)p=0}' install.sh)"
    source lib/hardware.sh
    source lib/apt_helpers.sh
    source lib/system_services.sh
    source installer/components.sh
  }

  every_component_default_on() {
    ( load_env
      for entry in "${ISC_COMPONENTS[@]}"; do
        IFS='|' read -r _id _label default _fn <<< "$entry"
        [ "$default" = "on" ] || exit 1
      done
    )
  }

  every_component_function_defined() {
    ( load_env
      for entry in "${ISC_COMPONENTS[@]}"; do
        local fn="${entry##*|}"
        declare -F "$fn" >/dev/null 2>&1 || exit 1
      done
    )
  }

  groups_cover_base_packages() {
    ( load_env
      local union=(
        "${APT_CORE_UTILS[@]}" "${APT_GNOME_TOOLING[@]}" "${APT_BUILD_TOOLS[@]}"
        "${APT_TERMINAL[@]}" "${APT_PYTHON[@]}" "${APT_DESKTOP_UTILS[@]}"
        "${APT_AUDIO_SPEECH[@]}" "${APT_MULTIMEDIA[@]}" "${APT_REMOTE_DESKTOP[@]}"
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
      for want in core_utils multimedia virtualization remote_desktop tmux \
                  snap_gitkraken snap_spotify snap_discord chrome etcher \
                  gh_cli github_login albert nvidia; do
        grep -qx "$want" <<< "$ids" || exit 1
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

  check "every component is default-on" every_component_default_on
  check "every component maps to a defined function" every_component_function_defined
  check "package groups reproduce APT_BASE_PACKAGES" groups_cover_base_packages
  check "all expected feature components are present" feature_components_present
  check "keyring libraries are hidden in python runtime dependencies" keyring_hidden_dependency

  echo
  echo "Components tests: $passed passed, $failed failed, $total total"
  [ "$failed" -eq 0 ]
}

run_tests
