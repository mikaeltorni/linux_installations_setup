#!/usr/bin/env bash
# Verify the GParted component through the public list command and isolated package-manager mocks.

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_SCRIPT_DIR")"
MOCK_DIR="$(mktemp -d)"
MOCK_BIN="$MOCK_DIR/bin"
MOCK_APT_LOG="$MOCK_DIR/apt.log"
FAILURES=0

trap 'rm -rf "$MOCK_DIR"' EXIT
mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/apt" <<'MOCK_APT'
#!/usr/bin/env bash
case "${1:-}" in
  update)
    printf 'apt %s\n' "$*" >> "$MOCK_APT_LOG"
    exit 0
    ;;
  install)
    printf 'apt %s\n' "$*" >> "$MOCK_APT_LOG"
    exit "${MOCK_APT_INSTALL_STATUS:-0}"
    ;;
  *)
    exit 64
    ;;
esac
MOCK_APT

cat > "$MOCK_BIN/dpkg" <<'MOCK_DPKG'
#!/usr/bin/env bash
if [[ "${1:-}" == "-s" && "${2:-}" == "gparted" ]]; then
  [[ "${MOCK_DPKG_GPARTED_INSTALLED:-0}" == "1" ]]
else
  exit 64
fi
MOCK_DPKG

cat > "$MOCK_BIN/msg" <<'MOCK_MSG'
#!/usr/bin/env bash
exit 0
MOCK_MSG

chmod +x "$MOCK_BIN/apt" "$MOCK_BIN/dpkg" "$MOCK_BIN/msg"

component_listing="$(bash "$PROJECT_DIR/install.sh" --list-components)"
if grep -Fxq $'gparted\tGParted partition editor\ton\tDesktop applications' <<< "$component_listing"; then
  printf '%s\n' 'PASS public component listing exposes default-on GParted'
else
  printf '%s\n' 'FAIL public component listing exposes default-on GParted'
  FAILURES=$((FAILURES + 1))
fi

SCRIPT_DIR="$PROJECT_DIR"
INSTALLER_LOG_LEVEL=error
export SCRIPT_DIR INSTALLER_LOG_LEVEL MOCK_APT_LOG
source "$PROJECT_DIR/lib/logging.sh"
eval "$(awk '/^(APT|SNAP)_[A-Z0-9_]*=\(/{printing=1} printing{print} /\)/{if (printing) printing=0}' "$PROJECT_DIR/install.sh")"
source "$PROJECT_DIR/lib/apt_helpers.sh"
source "$PROJECT_DIR/installer/components.sh"

if declare -p APT_GPARTED >/dev/null 2>&1 && [[ "${APT_GPARTED[*]}" == "gparted" ]]; then
  printf '%s\n' 'PASS APT_GPARTED contains only gparted'
else
  printf '%s\n' 'FAIL APT_GPARTED contains only gparted'
  FAILURES=$((FAILURES + 1))
fi

if printf '%s\n' "${APT_BASE_PACKAGES[@]}" | grep -Fxq gparted; then
  printf '%s\n' 'PASS APT_BASE_PACKAGES includes gparted'
else
  printf '%s\n' 'FAIL APT_BASE_PACKAGES includes gparted'
  FAILURES=$((FAILURES + 1))
fi

component_row="$(printf '%s\n' "${ISC_COMPONENTS[@]}" | awk -F'|' '$1 == "gparted"')"
if [[ "$component_row" == 'gparted|GParted partition editor|on|lis_install_gparted|detect_gparted||Desktop applications' ]]; then
  printf '%s\n' 'PASS component maps default-on GParted to installer and detection'
else
  printf '%s\n' 'FAIL component maps default-on GParted to installer and detection'
  FAILURES=$((FAILURES + 1))
fi

favorite_row="$(lis_list_favorite_components | awk -F'\t' '$1 == "gparted"')"
startup_row="$(lis_list_startup_components | awk -F'\t' '$1 == "gparted"')"
if [[ "$favorite_row" == $'gparted\tgparted.desktop\toff' && "$startup_row" == $'gparted\tgparted.desktop\toff\t0' ]]; then
  printf '%s\n' 'PASS GParted desktop metadata is available with startup and favorite defaults off'
else
  printf '%s\n' 'FAIL GParted desktop metadata is available with startup and favorite defaults off'
  FAILURES=$((FAILURES + 1))
fi

export PATH="$MOCK_BIN:$PATH"
if declare -F lis_install_gparted >/dev/null 2>&1; then
  : > "$MOCK_APT_LOG"
  APT_UPDATED=0
  MOCK_APT_INSTALL_STATUS=0
  export MOCK_APT_INSTALL_STATUS
  if lis_install_gparted && grep -Fxq 'apt update -y' "$MOCK_APT_LOG" && grep -Fxq 'apt install -y gparted' "$MOCK_APT_LOG"; then
    printf '%s\n' 'PASS GParted installer requests exactly the gparted package through mocked APT'
  else
    printf '%s\n' 'FAIL GParted installer requests exactly the gparted package through mocked APT'
    FAILURES=$((FAILURES + 1))
  fi

  : > "$MOCK_APT_LOG"
  APT_UPDATED=0
  MOCK_APT_INSTALL_STATUS=23
  if lis_install_gparted; then
    INSTALL_STATUS=0
  else
    INSTALL_STATUS=$?
  fi
  if [[ "$INSTALL_STATUS" == 23 ]] && grep -Fxq 'apt install -y gparted' "$MOCK_APT_LOG"; then
    printf '%s\n' 'PASS GParted installer propagates mocked APT failure status 23'
  else
    printf '%s\n' 'FAIL GParted installer propagates mocked APT failure status 23'
    FAILURES=$((FAILURES + 1))
  fi
else
  printf '%s\n' 'FAIL GParted installer function exists for mocked success and failure checks'
  FAILURES=$((FAILURES + 1))
fi

if declare -F detect_gparted >/dev/null 2>&1; then
  MOCK_DPKG_GPARTED_INSTALLED=1
  export MOCK_DPKG_GPARTED_INSTALLED
  if detect_gparted; then
    printf '%s\n' 'PASS GParted detection succeeds when mocked dpkg reports installed'
  else
    printf '%s\n' 'FAIL GParted detection succeeds when mocked dpkg reports installed'
    FAILURES=$((FAILURES + 1))
  fi

  MOCK_DPKG_GPARTED_INSTALLED=0
  if detect_gparted; then
    printf '%s\n' 'FAIL GParted detection rejects a missing package'
    FAILURES=$((FAILURES + 1))
  else
    printf '%s\n' 'PASS GParted detection rejects a missing package'
  fi
else
  printf '%s\n' 'FAIL GParted detection function exists for mocked package-state checks'
  FAILURES=$((FAILURES + 1))
fi

printf 'GParted checks: %s failure(s)\n' "$FAILURES"
if [[ "$FAILURES" -ne 0 ]]; then
  exit 1
fi
