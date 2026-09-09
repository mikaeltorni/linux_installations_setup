#!/usr/bin/env python3
"""README module-layout list must match shipped lib/*.sh files once each."""

from collections import Counter
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]


def test_readme_lists_each_lib_script_once():
    """Module Layout must name every lib/*.sh exactly once."""
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    mentioned = re.findall(r"`(lib/[^`]+\.sh)`", readme)
    counts = Counter(mentioned)
    duplicates = sorted(name for name, count in counts.items() if count > 1)
    assert not duplicates, f"README lists lib scripts more than once: {duplicates}"
    shipped = sorted(path.name for path in (ROOT / "lib").glob("*.sh"))
    mentioned_names = {Path(name).name for name in mentioned}
    missing = [name for name in shipped if name not in mentioned_names]
    assert not missing, f"README omits shipped lib scripts: {missing}"


if __name__ == "__main__":
    tests = [t for name, t in sorted(globals().items()) if name.startswith("test_") and callable(t)]
    failed = 0
    for test_fn in tests:
        try:
            test_fn()
            print(f"  PASS: {test_fn.__doc__}")
        except Exception as exc:
            failed += 1
            print(f"  FAIL: {test_fn.__doc__} — {exc}")
    raise SystemExit(failed)
