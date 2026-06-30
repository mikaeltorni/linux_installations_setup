#!/usr/bin/env python3
"""Characterization tests for the Albert installer shell functions."""

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


def albert_script(body: str) -> str:
    """Build an isolated shell harness around the current application module."""
    return "\n".join(
        [
            "set -euo pipefail",
            "TARGET_HOME=/home/test-user",
            "INSTALLER_LOG_LEVEL=debug",
            "source lib/logging.sh",
            "msg() { :; }",
            "need_cmd() { return 1; }",
            "apt_install() { :; }",
            "run_as_target() { printf 'user:%s\\n' \"$*\"; }",
            "source lib/app_installer.sh",
            body,
        ]
    )


def test_detects_noble_series():
    """Ubuntu noble should map to the matching OBS repository series."""
    proc = run_bash(
        albert_script(
            "\n".join(
                [
                    "lsb_release() {",
                    "  [ \"$1\" = \"-cs\" ] && printf 'noble\\n' || printf '24.04\\n'",
                    "}",
                    "detect_albert_obs_series",
                ]
            )
        )
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.strip() == "xUbuntu_24.04"


def test_unsupported_release_skips_install():
    """An unsupported Ubuntu release should be logged and skipped."""
    proc = run_bash(
        albert_script(
            "\n".join(
                [
                    "detect_albert_obs_series() { printf '\\n'; }",
                    "install_albert",
                ]
            )
        )
    )

    assert proc.returncode == 0, proc.stderr
    assert "Could not detect Ubuntu codename" in proc.stderr


def test_failed_install_removes_repository_files():
    """A failed package install should remove the newly configured repository."""
    proc = run_bash(
        albert_script(
            "\n".join(
                [
                    "detect_albert_obs_series() { printf 'xUbuntu_24.04\\n'; }",
                    "test() { return 1; }",
                    "curl() { printf 'key'; }",
                    "gpg() { cat >/dev/null; }",
                    "apt() { [ \"$1\" = update ]; }",
                    "rm() { printf 'rm:%s\\n' \"$*\"; }",
                    "install_albert",
                ]
            )
        )
    )

    assert proc.returncode == 0, proc.stderr
    assert "Failed to install albert" in proc.stderr
    assert "home:manuelschneid3r.list" in proc.stdout
    assert "home_manuelschneid3r.gpg" in proc.stdout


def test_successful_install_leaves_autostart_to_master_selection():
    """A successful install must leave login startup to the master [S] selector."""
    proc = run_bash(
        albert_script(
            "\n".join(
                [
                    "detect_albert_obs_series() { printf 'xUbuntu_24.04\\n'; }",
                    "test() { return 0; }",
                    "apt() { return 0; }",
                    "install_albert",
                ]
            )
        )
    )

    assert proc.returncode == 0, proc.stderr
    assert ".config/autostart" not in proc.stdout
    assert "albert.desktop" not in proc.stdout
