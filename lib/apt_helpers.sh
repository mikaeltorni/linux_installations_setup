#!/usr/bin/env bash
# apt_helpers.sh — Package installation / system setup helpers (shim)
#
# This file now sources modular components:
#   - lib/apt_packages.sh: APT cache management and base package installation.
#   - lib/app_installer.sh: Application installers and specialized module loading.

source "$SCRIPT_DIR/lib/apt_packages.sh"
source "$SCRIPT_DIR/lib/app_installer.sh"
