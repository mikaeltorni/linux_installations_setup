#!/usr/bin/env bash
# Focused tests for the NodeSource-backed Node.js 22 installer.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/nodejs_installer.sh"

calls=()
msg() { calls+=("msg:$*"); }
log() { calls+=("log:$*"); }
need_cmd() { [[ "$1" == node ]]; }
node() { printf 'v22.99.0\n'; }

detect_nodejs_22
[[ "$(nodejs_major_version)" == 22 ]]

need_cmd() { return 1; }
[[ "$(nodejs_major_version)" == 0 ]]
! detect_nodejs_22

printf 'Node.js installer tests passed\n'
