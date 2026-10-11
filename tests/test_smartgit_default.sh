#!/usr/bin/env bash
# Verify the public component listing marks SmartGit as opt-in.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
component_listing="$(bash "$SCRIPT_DIR/install.sh" --list-components)"
printf '%s\n' "$component_listing" | awk -F '\t' '
  $1 == "smartgit" {
    matches++
    default_state = $3
  }
  END {
    if (matches != 1 || default_state != "off") {
      printf "Expected one SmartGit row with default off, found %d row(s) with default %s\n", matches, default_state > "/dev/stderr"
      exit 1
    }
    printf "SmartGit public component default: %s\n", default_state
  }
'
