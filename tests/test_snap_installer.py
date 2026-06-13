#!/usr/bin/env python3
"""Characterization tests for Snap application installation."""

import subprocess
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent


def run_bash(script: str) -> subprocess.CompletedProcess[str]:
    """Run a Bash snippet from the project root."""
    return subprocess.run(
        ["bash", "-c", script],
        cwd=ROOT_DIR,
        text=True,
        capture_output=True,
        check=False,
    )


def snap_script(body: str) -> str:
    """Build an isolated shell harness around the application installer."""
    return "\n".join(
        [
            "set -euo pipefail",
            "msg() { printf 'msg:%s\\n' \"$*\"; }",
            "log() { printf 'log:%s:%s\\n' \"$1\" \"$2\"; }",
            "need_cmd() { return 1; }",
            "apt_install() { printf 'apt:%s\\n' \"$*\"; }",
            "run_as_target() { :; }",
            "source lib/app_installer.sh",
            body,
        ]
    )


def test_empty_app_list_skips_snapd_installation():
    """An empty Snap list should log a warning without installing snapd."""
    proc = run_bash(
        snap_script(
            "\n".join(
                [
                    "SNAP_APPS=()",
                    "install_snaps",
                ]
            )
        )
    )

    assert proc.returncode == 0, proc.stderr
    assert "SNAP_APPS is empty" in proc.stdout
    assert "apt:snapd" not in proc.stdout


def test_missing_snap_command_is_reported_after_snapd_installation():
    """A missing snap command should be logged after requesting snapd."""
    proc = run_bash(
        snap_script(
            "\n".join(
                [
                    "SNAP_APPS=(spotify)",
                    "PATH=/nonexistent",
                    "install_snaps",
                ]
            )
        )
    )

    assert proc.returncode == 0, proc.stderr
    assert "apt:snapd" in proc.stdout
    assert "snap command not available" in proc.stdout


def test_installs_snap_specs_with_their_options():
    """Snap names and optional flags should be forwarded to snap install."""
    proc = run_bash(
        snap_script(
            "\n".join(
                [
                    'SNAP_APPS=("gitkraken --classic" "spotify")',
                    "snap() { printf 'snap:%s\\n' \"$*\"; }",
                    "install_snaps",
                ]
            )
        )
    )

    assert proc.returncode == 0, proc.stderr
    assert "apt:snapd" in proc.stdout
    assert "snap:install gitkraken --classic" in proc.stdout
    assert "snap:install spotify" in proc.stdout


def test_failed_snap_does_not_stop_remaining_installs():
    """A failed Snap install should be warned about and the loop should continue."""
    proc = run_bash(
        snap_script(
            "\n".join(
                [
                    'SNAP_APPS=("broken" "spotify")',
                    "snap() {",
                    "  printf 'snap:%s\\n' \"$*\"",
                    "  [ \"$2\" != broken ]",
                    "}",
                    "install_snaps",
                ]
            )
        )
    )

    assert proc.returncode == 0, proc.stderr
    assert "Failed to install snap: broken" in proc.stdout
    assert "snap:install spotify" in proc.stdout
