#!/usr/bin/env bash
# hardware.sh — Hardware detection and driver installation (NVIDIA, GPU)
#
# Components:
#   - nvidia_gpu_detected(): Check if an NVIDIA GPU is present.
#   - choose_nvidia_driver_package(): Select the preferred NVIDIA driver package.
#   - install_nvidia_drivers(): Install NVIDIA drivers and CUDA toolkit.
#   - enable_nvidia_services(): Enable the NVIDIA persistence daemon service.

nvidia_gpu_detected() {
  command -v nvidia-smi >/dev/null 2>&1 ||
    { command -v lspci >/dev/null 2>&1 && lspci -nn | grep -qi 'NVIDIA'; }
}

choose_nvidia_driver_package() {
  local recommended_driver
  recommended_driver="$(
    ubuntu-drivers devices 2>/dev/null |
      awk '/^driver[[:space:]]*:.*recommended/ {print $3; exit}' || true
  )"
  if [ -n "${NVIDIA_DRIVER_PACKAGE:-}" ]; then
    printf '%s\n' "$NVIDIA_DRIVER_PACKAGE"
  elif [ -n "$recommended_driver" ]; then
    printf '%s\n' "$recommended_driver"
  else
    local fallback_versions=("nvidia-driver-595-open" "nvidia-driver-595" "nvidia-driver-590" "nvidia-driver-580" "nvidia-driver-570")
    for version in "${fallback_versions[@]}"; do
      if apt-cache show "$version" >/dev/null 2>&1; then
        printf '%s\n' "$version"
        return 0
      fi
    done
  fi
}

configure_nvidia_update_policy() {
  # Install the additive NVIDIA unattended-update exclusion.
  # Parameters: none.
  # Returns: zero on deployment or privilege deferral, otherwise install status.
  printf '%s\n' 'parameters=none'
  local source_file="$SCRIPT_DIR/assets/apt/52nvidia-session-safety"
  local destination="${LIS_NVIDIA_APT_CONFIG_DIR:-/etc/apt/apt.conf.d}/52nvidia-session-safety"
  local result=0 command_text
  if is_root; then
    install -D -m 0644 "$source_file" "$destination" || result=$?
  else
    printf -v command_text 'sudo install -D -m 0644 %q %q' "$source_file" "$destination"
    note_sudo_required "$command_text"
  fi
  printf '%s\n' "$result"
  return "$result"
}

check_nvidia_driver_health() {
  # Report NVML failures without disrupting a running desktop.
  # Parameters: none.
  # Returns: zero; newly installed drivers may need user-controlled activation.
  printf '%s\n' 'parameters=none'
  local output
  if command -v nvidia-smi >/dev/null 2>&1; then
    if output="$(nvidia-smi -L 2>&1)"; then
      msg "NVIDIA GPU query succeeded: $output"
    else
      msg "NVIDIA GPU query failed: $output"
      if [[ "$output" == *"Driver/library version mismatch"* ]]; then
        msg "The loaded NVIDIA kernel driver differs from its updated libraries. Save your work and reboot when ready to restore nvidia-smi and taskbar GPU readings."
      else
        msg "Check NVIDIA driver installation and kernel logs before relying on GPU readings."
      fi
    fi
  fi
  printf '%s\n' 0
  return 0
}

install_nvidia_drivers() {
  # Install the driver and CUDA packages after applying update protection.
  # Parameters: none.
  # Returns: policy deployment status, or zero after best-effort package setup.
  printf '%s\n' 'parameters=none'
  local result=0
  configure_nvidia_update_policy || result=$?
  if [ "$result" -ne 0 ]; then
    printf '%s\n' "$result"
    return "$result"
  fi
  msg "Installing NVIDIA drivers and CUDA toolkit"
  local driver_package
  driver_package="$(choose_nvidia_driver_package)"
  log "debug" "Selected NVIDIA driver package: ${driver_package:-<none>}"
  if [ -n "$driver_package" ]; then
    msg "Installing NVIDIA driver package: $driver_package"
    apt_install "$driver_package" || true
  else
    log "warn" "No suitable NVIDIA driver package found."
  fi
  apt_install cuda-toolkit || true
  apt_install nvidia-cuda-dev nvidia-cuda-toolkit || true
  check_nvidia_driver_health
  printf '%s\n' 0
  return 0
}

enable_nvidia_services() {
  # Enable the NVIDIA persistence daemon so the driver state is kept warm
  # across application start/stop cycles. Best-effort: the unit is absent on
  # some driver packages / Ubuntu releases, so failures are tolerated.
  #
  # Returns: 0 always (enablement is non-fatal to the overall install).
  msg "Enabling NVIDIA persistence daemon service"
  if systemctl enable nvidia-persistenced.service 2>/dev/null; then
    msg "Enabled nvidia-persistenced.service"
  else
    log "warn" "nvidia-persistenced.service not available; skipping enable"
  fi
  systemctl daemon-reload
}
