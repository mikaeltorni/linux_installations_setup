#!/usr/bin/env bash
# Install and detect the Node.js 22 system runtime from NodeSource.

NODEJS_MAJOR=22
NODEJS_SETUP_URL="https://deb.nodesource.com/setup_${NODEJS_MAJOR}.x"

# nodejs_major_version - Print the installed Node.js major version, or 0 when
# Node.js is unavailable or reports an unexpected version string.
nodejs_major_version() {
  if ! need_cmd node; then
    printf '0\n'
    return
  fi

  local version
  version="$(node --version 2>/dev/null || true)"
  if [[ "$version" =~ ^v([0-9]+)([.][0-9]+){2}$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '0\n'
  fi
}

# detect_nodejs_22 - Return success only when the active node binary is major
# version 22. This deliberately rejects newer majors because the component
# promises the Node.js 22 LTS release line.
detect_nodejs_22() {
  [[ "$(nodejs_major_version)" == "$NODEJS_MAJOR" ]]
}

# install_nodejs_22 - Configure NodeSource's signed Node.js 22 APT repository
# and install its nodejs package, which includes npm. Safe to rerun.
install_nodejs_22() {
  if detect_nodejs_22; then
    msg "Node.js 22 is already installed"
    return
  fi

  msg "Installing Node.js 22 and npm from NodeSource"
  apt_install ca-certificates curl gnupg

  local setup_script
  setup_script="$(mktemp)"
  if ! curl -fsSL --max-time 300 "$NODEJS_SETUP_URL" -o "$setup_script"; then
    rm -f "$setup_script"
    log "error" "Failed to download the NodeSource Node.js 22 repository setup script"
    return 1
  fi

  log "info" "Configuring the NodeSource Node.js 22 APT repository"
  if ! bash "$setup_script"; then
    rm -f "$setup_script"
    log "error" "NodeSource Node.js 22 repository setup failed"
    return 1
  fi
  rm -f "$setup_script"

  apt_install nodejs
  if ! detect_nodejs_22; then
    log "error" "Node.js 22 installation completed but the active node major is $(nodejs_major_version)"
    return 1
  fi
  msg "Installed Node.js $(node --version) with npm $(npm --version)"
}
