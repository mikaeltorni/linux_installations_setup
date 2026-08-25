#!/usr/bin/env bash
# bluetooth.sh — opt-in Bluetooth kernel boot configuration.
#
# The author's MediaTek MT7922 adapter exposes Bluetooth correctly on the
# installed 6.17.0-40-generic kernel, while the current kernel does not. This
# component only prepares the next boot; it never reboots the machine.

# Defaults are overridable so the same component can be used on another system
# after inspecting that system's generated GRUB menu.
BLUETOOTH_KERNEL_VERSION="${BLUETOOTH_KERNEL_VERSION:-6.17.0-40-generic}"
BLUETOOTH_GRUB_CONFIG="${BLUETOOTH_GRUB_CONFIG:-/etc/default/grub}"
BLUETOOTH_GRUB_CFG="${BLUETOOTH_GRUB_CFG:-/boot/grub/grub.cfg}"
BLUETOOTH_GRUB_ENV="${BLUETOOTH_GRUB_ENV:-/boot/grub/grubenv}"

# find_bluetooth_kernel_menu_id — resolve the exact GRUB menu ID for the
# configured kernel from grub.cfg. Selecting the ID is stable across localized
# menu labels and avoids relying on a display title at boot time.
find_bluetooth_kernel_menu_id() {
  local kernel="${BLUETOOTH_KERNEL_VERSION:-6.17.0-40-generic}"
  local grub_cfg="${BLUETOOTH_GRUB_CFG:-/boot/grub/grub.cfg}"
  local menu_line menu_id

  [ -r "$grub_cfg" ] || {
    log error "Bluetooth kernel fix: GRUB configuration is not readable: $grub_cfg"
    return 1
  }

  menu_line="$(grep -F "menuentry 'Ubuntu, with Linux ${kernel}'" "$grub_cfg" | head -n 1 || true)"
  if [ -z "$menu_line" ]; then
    log error "Bluetooth kernel fix: kernel menu entry not found for $kernel in $grub_cfg"
    return 1
  fi

  menu_id="$(sed -n "s/.*menuentry_id_option[[:space:]]*'\([^']*\)'.*/\1/p" <<<"$menu_line")"
  if [ -z "$menu_id" ]; then
    log error "Bluetooth kernel fix: menu entry for $kernel has no GRUB ID"
    return 1
  fi

  printf '%s\n' "$menu_id"
}

# backup_grub_default_config — create a timestamped backup before touching
# one-time boot state. An identical existing backup is reused for idempotence.
backup_grub_default_config() {
  local config="${BLUETOOTH_GRUB_CONFIG:-/etc/default/grub}"
  local backup_dir="${BLUETOOTH_GRUB_BACKUP_DIR:-$(dirname "$config")}"
  local existing stamp backup suffix=0

  if [ ! -f "$config" ]; then
    log error "Bluetooth kernel fix: GRUB defaults file is missing: $config"
    return 1
  fi
  if [ ! -d "$backup_dir" ]; then
    log error "Bluetooth kernel fix: GRUB backup directory is missing: $backup_dir"
    return 1
  fi

  existing="$(find "$backup_dir" -maxdepth 1 -type f -name 'grub.backup.*' -print -quit 2>/dev/null || true)"
  if [ -n "$existing" ] && cmp -s "$config" "$existing"; then
    log info "Bluetooth kernel fix: reusing existing GRUB backup $existing"
    return 0
  fi

  stamp="$(date '+%Y%m%d-%H%M%S')"
  backup="$backup_dir/grub.backup.$stamp"
  while [ -e "$backup" ]; do
    suffix=$((suffix + 1))
    backup="$backup_dir/grub.backup.$stamp.$suffix"
  done

  install -m 0644 "$config" "$backup"
  log info "Bluetooth kernel fix: backed up $config to $backup"
}

# bluetooth_kernel_boot_configured — report whether the requested one-time
# next boot is already present in grubenv.
bluetooth_kernel_boot_configured() {
  local grub_env="${BLUETOOTH_GRUB_ENV:-/boot/grub/grubenv}"
  local menu_id

  need_cmd grub-editenv || return 1
  menu_id="$(find_bluetooth_kernel_menu_id 2>/dev/null)" || return 1
  grub-editenv "$grub_env" list 2>/dev/null |
    grep -Fxq "next_entry=$menu_id"
}

# configure_bluetooth_kernel_boot — back up GRUB defaults and select the
# requested kernel for the next boot. This function deliberately does not call
# reboot; the shared safe-system-action wrapper remains the only reboot path.
configure_bluetooth_kernel_boot() {
  local menu_id grub_env="${BLUETOOTH_GRUB_ENV:-/boot/grub/grubenv}"

  need_cmd grub-reboot || {
    log error "Bluetooth kernel fix: grub-reboot is unavailable"
    return 1
  }
  need_cmd grub-editenv || {
    log error "Bluetooth kernel fix: grub-editenv is unavailable"
    return 1
  }

  menu_id="$(find_bluetooth_kernel_menu_id)" || return 1
  backup_grub_default_config || return 1

  log info "Bluetooth kernel fix: selecting $menu_id for the next boot"
  grub-reboot "$menu_id" || {
    log error "Bluetooth kernel fix: failed to set the next GRUB entry"
    return 1
  }

  if ! grub-editenv "$grub_env" list 2>/dev/null | grep -Fxq "next_entry=$menu_id"; then
    log error "Bluetooth kernel fix: GRUB did not confirm next_entry=$menu_id"
    return 1
  fi

  msg "Bluetooth kernel fix configured for next boot ($menu_id); reboot was not requested"
}
