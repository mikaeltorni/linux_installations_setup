"""Static safety checks for the installer's final reboot path.

The test deliberately does not execute install.sh or any reboot helper.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_installer_delegates_reboot_to_guarded_helper():
    content = (ROOT / "install.sh").read_text(encoding="utf-8")

    assert "safe_system_action reboot" in content
    assert "\n    reboot\n" not in content
    assert "\n    sleep 10\n" not in content
