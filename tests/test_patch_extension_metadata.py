#!/usr/bin/env python3
"""Tests for scripts/patch_extension_metadata.py — temp files only, no system changes.

Exercises the patch_shell_version() helper across its branches (missing entry,
already-present entry, non-list field, missing file) so the GNOME extension
metadata patcher stays under regression coverage.
"""

import json
import sys
import tempfile
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR / "scripts"))

from patch_extension_metadata import patch_shell_version  # noqa: E402


def _write_metadata(data: dict) -> Path:
    """Write *data* as JSON to a temp file and return its path.

    Args:
        data: Metadata dictionary to serialize.

    Returns:
        Path to the created temporary metadata.json file.
    """
    tmp = tempfile.NamedTemporaryFile(suffix=".json", mode="w", delete=False)
    json.dump(data, tmp)
    tmp.close()
    return Path(tmp.name)


def test_appends_missing_version():
    """patch_shell_version should append a missing version and report modified."""
    path = _write_metadata({"uuid": "x@ext", "shell-version": ["45"]})
    assert patch_shell_version(path, "46") is True
    assert "46" in json.loads(path.read_text())["shell-version"]
    path.unlink()


def test_noop_when_present():
    """patch_shell_version should report no change when version already present."""
    path = _write_metadata({"uuid": "x@ext", "shell-version": ["46"]})
    assert patch_shell_version(path, "46") is False
    path.unlink()


def test_replaces_non_list_field():
    """patch_shell_version should replace a non-list shell-version with a list."""
    path = _write_metadata({"uuid": "x@ext", "shell-version": "broken"})
    assert patch_shell_version(path, "46") is True
    assert json.loads(path.read_text())["shell-version"] == ["46"]
    path.unlink()


def test_missing_file_raises():
    """patch_shell_version should raise FileNotFoundError for a missing file."""
    try:
        patch_shell_version("/nonexistent/metadata.json", "46")
    except FileNotFoundError:
        return
    raise AssertionError("expected FileNotFoundError")


if __name__ == "__main__":
    tests = [t for name, t in sorted(globals().items()) if name.startswith("test_") and callable(t)]
    passed = failed = 0
    for test_fn in tests:
        try:
            test_fn()
            print(f"  PASS: {test_fn.__doc__}")
            passed += 1
        except Exception as e:  # noqa: BLE001
            print(f"  FAIL: {test_fn.__doc__} — {e}")
            failed += 1
    print(f"\nResults: {passed} passed, {failed} failed")
    sys.exit(failed)
