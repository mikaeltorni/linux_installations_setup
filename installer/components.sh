#!/usr/bin/env bash
# components.sh - Component manifest for linux_installations_setup.
#
# Maps each base-system component to the install_* function (defined in lib/)
# that performs it. install.sh sources the lib files first, then this manifest,
# then routes execution through component_main from component_runtime.sh.
#
# This repository hard-requires root: lis_preflight aborts the run if not root.
# The master installer skips it entirely in user mode.
#
# Entry format: "id|label|default(on/off)|function".

ISC_REPO_NAME="linux_installations_setup"
ISC_REPO_LABEL="Base packages, drivers and applications"

ISC_PREFLIGHT="lis_preflight"

ISC_COMPONENTS=(
  "base_packages|Base APT packages and utilities|on|install_base_packages"
  "chrome|Google Chrome|on|install_google_chrome"
  "etcher|balenaEtcher|on|install_balena_etcher"
  "snaps|Snap apps (GitKraken, Spotify, Discord)|on|install_snaps"
  "gh_cli|GitHub CLI|on|install_gh_cli"
  "github_login|GitHub login (gh auth)|on|ensure_github_login"
  "albert|Albert launcher|on|install_albert"
  "nvidia|NVIDIA drivers (if a GPU is detected)|on|lis_install_nvidia"
)

# lis_preflight - require root and a usable session bus before any component.
lis_preflight() {
  ensure_root
  ensure_session_bus
}

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
