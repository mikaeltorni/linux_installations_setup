#!/usr/bin/env python3
"""Tests for the centralized Python logging utility."""

import logging
import sys
import uuid
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR / "scripts"))

from logging_utils import get_logger, log_call  # noqa: E402


def test_get_logger_creates_repo_log_file_and_reuses_handlers():
    """get_logger should create a repo .log file and avoid duplicate handlers."""
    log_name = f"test-{uuid.uuid4().hex}.log"
    logger_name = f"test_logger_{uuid.uuid4().hex}"

    logger = get_logger(logger_name, log_name)
    first_handlers = list(logger.handlers)
    logger.info("centralized python logger test")
    again = get_logger(logger_name, log_name)

    assert again is logger
    assert logger.handlers == first_handlers
    assert len(logger.handlers) == 1
    assert (ROOT_DIR / ".log" / log_name).is_file()
    assert "centralized python logger test" in (ROOT_DIR / ".log" / log_name).read_text()


def test_log_call_records_arguments_and_return_value():
    """log_call should record bound arguments on entry and the return on exit."""
    log_name = f"trace-{uuid.uuid4().hex}.log"
    logger_name = f"trace_logger_{uuid.uuid4().hex}"
    logger = get_logger(logger_name, log_name)

    @log_call(logger, logging.INFO)
    def sample(alpha: str, count: int = 2) -> str:
        return alpha * count

    assert sample("x", count=3) == "xxx"
    log_text = (ROOT_DIR / ".log" / log_name).read_text()
    assert (
        "ENTER test_logging_utils.py:"
        "test_log_call_records_arguments_and_return_value.<locals>.sample"
        "(alpha='x', count=3)"
    ) in log_text
    assert (
        "EXIT test_logging_utils.py:"
        "test_log_call_records_arguments_and_return_value.<locals>.sample -> 'xxx'"
    ) in log_text


if __name__ == "__main__":
    tests = [
        test_fn
        for name, test_fn in sorted(globals().items())
        if name.startswith("test_") and callable(test_fn)
    ]
    passed = failed = 0
    for test_fn in tests:
        try:
            test_fn()
            print(f"  PASS: {test_fn.__doc__}")
            passed += 1
        except Exception as exc:  # noqa: BLE001
            print(f"  FAIL: {test_fn.__doc__} - {exc}")
            failed += 1
    print(f"\nResults: {passed} passed, {failed} failed")
    sys.exit(failed)
