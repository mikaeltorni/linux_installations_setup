#!/usr/bin/env bash
# test_bash_logging.sh — Regression tests for the centralized Bash logger.

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_SCRIPT_DIR")"

source "$PROJECT_DIR/lib/logging.sh"

output="$(INSTALLER_LOG_LEVEL=warn log info "hidden message" 2>&1 || true)"
if [[ -n "$output" ]]; then
  printf 'FAIL: info log should be filtered at warn level\n' >&2
  exit 1
fi

output="$(INSTALLER_LOG_LEVEL=debug log warn "visible warning" 2>&1)"
if [[ "$output" != *"[WARN] visible warning"* ]]; then
  printf 'FAIL: warn log was not emitted in text format\n' >&2
  exit 1
fi

output="$(INSTALLER_PRODUCTION=1 log error 'quoted "message"' 2>&1)"
if [[ "$output" != *'"level":"ERROR"'* || "$output" != *'quoted \"message\"'* ]]; then
  printf 'FAIL: production JSON log did not include escaped message\n' >&2
  exit 1
fi
