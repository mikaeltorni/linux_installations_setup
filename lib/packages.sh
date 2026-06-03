#!/usr/bin/env bash
# packages.sh — Package installation helpers (UV, Dash-to-Panel, .NET, installer wrapper)
#
# Components:
#   - install_uv(): Install the UV package manager.
#   - install_dash_to_panel_latest(): Install latest Dash-to-Panel GNOME extension.
#   - install_dotnet(): Install .NET runtime and SDK.
#   - install_installer_wrapper(): Install the installer wrapper script.
#
# Must be sourced after SCRIPT_DIR, CONFIG_DIR, TARGET_USER, TARGET_HOME are set.


install_uv() {
  timed_start "install_uv"
  msg "Installing UV for the user"
  run_as_target bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh || true'
  run_as_target mkdir -p "$TARGET_HOME/.config/autostart"
  run_as_target rm -f "$TARGET_HOME/.config/autostart/uv-python.desktop" || true
  timed_end "install_uv"
}

install_dash_to_panel_latest() {
  timed_start "install_dash_to_panel_latest"
  msg "Installing dash-to-panel (prefer distro package, fallback to latest upstream)"
  # Try distro package first; it's usually built for the current GNOME version
  local candidate
  candidate="$(apt-cache policy gnome-shell-extension-dash-to-panel 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
  if [ -n "$candidate" ] && [ "$candidate" != "(none)" ]; then
    if apt_install gnome-shell-extension-dash-to-panel; then
      msg "dash-to-panel installed from distro package."
      return
    else
      msg "distro package install failed; falling back to upstream zip."
    fi
  else
    msg "dash-to-panel package not found in apt; using upstream zip."
  fi
  # tools as root for the upstream path
  apt_install jq curl unzip
  local ext_id="dash-to-panel@jderose9.github.com"
  local ext_dir="$TARGET_HOME/.local/share/gnome-shell/extensions/$ext_id"
  local shell_ver=""
  if ! run_as_target bash -lc '
set -e
EXT_ID="dash-to-panel@jderose9.github.com"
EXT_ROOT="$HOME/.local/share/gnome-shell/extensions"
EXT_DIR="$EXT_ROOT/$EXT_ID"
mkdir -p "$EXT_ROOT"
tmp="$(mktemp -d)"
zipurl="$(curl -fsSL https://api.github.com/repos/home-sweet-gnome/dash-to-panel/releases/latest \
  | jq -r "(.assets[]? | select(.name|endswith(\"shell-extension.zip\")) | .browser_download_url) // empty")"
if [ -z "$zipurl" ]; then
  echo "Could not find dash-to-panel shell-extension.zip asset; falling back to any .zip asset."
  zipurl="$(curl -fsSL https://api.github.com/repos/home-sweet-gnome/dash-to-panel/releases/latest \
    | jq -r "(.assets[]? | select(.name|endswith(\".zip\")) | .browser_download_url) // empty")"
fi
if [ -z "$zipurl" ]; then
  echo "WARNING: no dash-to-panel zip asset found; skipping upstream install."
  rm -rf "$tmp"
  exit 1
fi
zipfile="$tmp/dash-to-panel.zip"
curl -fL "$zipurl" -o "$zipfile"
rm -rf "$EXT_DIR"
mkdir -p "$EXT_DIR"
unzip -oq "$zipfile" -d "$EXT_DIR"
rm -rf "$tmp"
[ -d "$EXT_DIR" ] || { echo "WARNING: dash-to-panel directory missing after unzip."; exit 1; }
echo "dash-to-panel extracted to $EXT_DIR"
'; then
    echo "WARNING: dash-to-panel upstream install failed; skipping."
    return 0
  fi
  shell_ver="$(run_as_target bash -lc 'gnome-shell --version 2>/dev/null' | grep -oE '[0-9]+' | head -n1 || true)"
  if [ -n "$shell_ver" ] && [ -f "$ext_dir/metadata.json" ]; then
    if run_as_target python3 "$SCRIPT_DIR/scripts/patch_extension_metadata.py" \
      "$ext_dir/metadata.json" "$shell_ver"; then
      msg "Patched dash-to-panel metadata for GNOME shell ${shell_ver}"
    else
      echo "WARNING: failed to patch dash-to-panel metadata.json"
    fi
  fi
  run_as_target gnome-extensions list 2>/dev/null | grep -i dash || \
    echo "NOTE: dash-to-panel may not appear in gnome-extensions until you log out and back in."
  timed_end "install_dash_to_panel_latest"
}

install_dotnet() {
  msg "Installing dotnet 9"
  wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
  chmod +x ./dotnet-install.sh
  ./dotnet-install.sh --version latest
  ./dotnet-install.sh --version latest --runtime aspnetcore
  ./dotnet-install.sh --channel 9.0
  install -d /usr/local/share/dotnet
  tee /usr/local/share/dotnet/env.sh >/dev/null << 'EOF'
# dotnet CLI env for installs under $HOME/.dotnet
if [ -d "$HOME/.dotnet" ]; then
  export DOTNET_ROOT="$HOME/.dotnet"
  case ":$PATH:" in
    *":$DOTNET_ROOT:"*) ;;
    *) PATH="$PATH:$DOTNET_ROOT" ;;
  esac
  case ":$PATH:" in
    *":$DOTNET_ROOT/tools:"*) ;;
    *) PATH="$PATH:$DOTNET_ROOT/tools" ;;
  esac
fi
EOF
  tee /etc/profile.d/dotnet.sh >/dev/null << 'EOF'
# dotnet env for login shells
[ -r /usr/local/share/dotnet/env.sh ] && . /usr/local/share/dotnet/env.sh
EOF
  if ! grep -q 'dotnet/env.sh' /etc/bash.bashrc 2>/dev/null; then
    tee -a /etc/bash.bashrc >/dev/null << 'EOF'
# dotnet env for interactive bash shells
[ -r /usr/local/share/dotnet/env.sh ] && . /usr/local/share/dotnet/env.sh
EOF
  fi
  if [ -d /etc/zsh ]; then
    if ! grep -q 'dotnet/env.sh' /etc/zsh/zshrc 2>/dev/null; then
      tee -a /etc/zsh/zshrc >/dev/null << 'EOF'
# dotnet env for interactive zsh shells
[ -r /usr/local/share/dotnet/env.sh ] && . /usr/local/share/dotnet/env.sh
EOF
    fi
  fi
  . /usr/local/share/dotnet/env.sh 2>/dev/null || true
  rm -rf dotnet-install.sh
}

install_installer_wrapper() {
  msg "Installing isc wrapper to /usr/local/bin"
  install -d -o "$TARGET_USER" -g "$TARGET_USER" /usr/local/bin
  cp -f "$SCRIPT_DIR/utilities/installer" /usr/local/bin/installer
  chmod +x /usr/local/bin/installer
}
