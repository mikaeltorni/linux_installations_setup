#!/usr/bin/env bash
# inotify_limits.sh — raise fs.inotify limits for desktop agent/tmux workloads.
#
# systemd user logs "Failed to add control inotify watch ... No space left on
# device" when fs.inotify.max_user_instances (default 128) is exhausted. That
# stalls cgroup watches and feels like input lag even when the disk is not full.

INOTIFY_SYSCTL_DIR="${LIS_SYSCTL_D:-/etc/sysctl.d}"
INOTIFY_SYSCTL_FILE="${INOTIFY_SYSCTL_DIR}/99-inotify-desktop.conf"
INOTIFY_MAX_USER_INSTANCES="${LIS_INOTIFY_MAX_USER_INSTANCES:-1024}"
INOTIFY_MAX_USER_WATCHES="${LIS_INOTIFY_MAX_USER_WATCHES:-524288}"
INOTIFY_MAX_QUEUED_EVENTS="${LIS_INOTIFY_MAX_QUEUED_EVENTS:-65536}"

# configure_inotify_limits — write the sysctl drop-in and apply it live.
#   Args: none. Returns: 0 (sysctl apply failures are logged, not fatal).
configure_inotify_limits() {
  log info "configure_inotify_limits: writing $INOTIFY_SYSCTL_FILE"
  mkdir -p "$INOTIFY_SYSCTL_DIR"
  cat >"$INOTIFY_SYSCTL_FILE" <<EOF
# Desktop agents/tmux spawn many inotify instances. Default 128 is exhausted
# (journal: "Failed to add control inotify watch ... No space left on device")
# which stalls systemd user units and feels like input lag.
fs.inotify.max_user_instances = ${INOTIFY_MAX_USER_INSTANCES}
fs.inotify.max_user_watches = ${INOTIFY_MAX_USER_WATCHES}
fs.inotify.max_queued_events = ${INOTIFY_MAX_QUEUED_EVENTS}
EOF
  if command -v sysctl >/dev/null 2>&1; then
    if ! sysctl -p "$INOTIFY_SYSCTL_FILE" >/dev/null; then
      log warn "configure_inotify_limits: sysctl -p failed for $INOTIFY_SYSCTL_FILE"
    fi
  fi
}

# inotify_limits_configured — true when the drop-in has the expected instances.
inotify_limits_configured() {
  [ -f "$INOTIFY_SYSCTL_FILE" ] && \
    grep -q "fs.inotify.max_user_instances = ${INOTIFY_MAX_USER_INSTANCES}" \
      "$INOTIFY_SYSCTL_FILE"
}

# remove_inotify_limits — delete the drop-in. Live kernel values are left as-is
# until reboot unless sysctl is invoked by the caller.
remove_inotify_limits() {
  rm -f "$INOTIFY_SYSCTL_FILE"
}
