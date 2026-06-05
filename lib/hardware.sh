#!/usr/bin/env bash
# hardware.sh — Hardware detection and driver installation (NVIDIA, GPU)
#
# Components:
#   - nvidia_gpu_detected(): Check if an NVIDIA GPU is present.
#   - choose_nvidia_driver_package(): Select the preferred NVIDIA driver package.
#   - install_nvidia_drivers(): Install NVIDIA drivers and CUDA toolkit.
#   - enable_nvidia_services(): Enable NVIDIA persistence and DRM services.

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

install_nvidia_drivers() {
  msg "Installing NVIDIA drivers and CUDA toolkit"
  local driver_package
  driver_package="$(choose_nvidia_driver_package)"
  if [ -n "$driver_package" ]; then
    msg "Installing NVIDIA driver package: $driver_package"
    apt_install "$driver_package" || true
  else
    log "warn" "No suitable NVIDIA driver package found."
  fi
  apt_install cuda-toolkit || true
  apt_install nvidia-cuda-dev nvidia-cuda-toolkit || true
}

enable_nvidia_services() {
  msg "Enabling NVIDIA persistence and DRM services"
  systemctl enable nvidia-persistenced.service 2>/dev/null || true
  systemctl daemon-reload
}
