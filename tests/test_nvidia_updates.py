"""Exercise the NVIDIA installer with isolated APT state and mocked hardware."""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
FRAMEWORK = PROJECT / ".installer-support"


def run_installer(directory, arguments, privileged=True, smi_status=0):
    """Run the public installer dispatcher without host changes.

    Parameters: directory - temporary state; arguments - public CLI tokens; privileged - simulated root; smi_status - simulated NVML exit.
    Returns: the completed subprocess.
    """
    print(f"directory={directory}, arguments={arguments}, privileged={privileged}, smi_status={smi_status}")
    script = r'''
set -euo pipefail
source "$PROJECT/install.sh"
ensure_root() {
  # Simulate the root preflight. Parameters: none. Returns: success.
  printf '%s\n' parameters=none 0
}
ensure_session_bus() {
  # Avoid contacting the desktop. Parameters: none. Returns: success.
  printf '%s\n' parameters=none 0
}
is_root() {
  # Simulate privileges. Parameters: none. Returns: mocked root status.
  printf '%s\n' parameters=none "$MOCK_ROOT_STATUS"
  return "$MOCK_ROOT_STATUS"
}
nvidia_gpu_detected() {
  # Simulate an RTX 4090. Parameters: none. Returns: success.
  printf '%s\n' parameters=none 0
}
choose_nvidia_driver_package() {
  # Preserve package-selection output. Parameters: none. Returns: driver package.
  printf '%s\n' parameters=none >&2
  printf '%s\n' nvidia-driver-595-open
}
apt_install() {
  # Capture requests. Parameters: $@ - packages. Returns: success.
  printf 'packages=%s\n' "$*"
  if [ ! -f "$LIS_NVIDIA_APT_CONFIG_DIR/52nvidia-session-safety" ]; then
    printf '%s\n' POLICY_MISSING_AT_INSTALL >> "$MOCK_APT_LOG"
  fi
  printf '%s\n' "$*" >> "$MOCK_APT_LOG"
  printf '%s\n' 0
}
enable_nvidia_services() {
  # Avoid changing services. Parameters: none. Returns: success.
  printf '%s\n' parameters=none 0
}
nvidia-smi() {
  # Simulate NVML. Parameters: $@ - query arguments. Returns: simulated status.
  printf 'arguments=%s\n' "$*" >&2
  if [ "$MOCK_SMI_STATUS" = 0 ]; then
    printf '%s\n' 'GPU 0: NVIDIA GeForce RTX 4090'
  else
    printf '%s\n' 'Failed to initialize NVML: Driver/library version mismatch' >&2
    printf '%s\n' 'NVML library version: 595.99' >&2
  fi
  printf 'status=%s\n' "$MOCK_SMI_STATUS" >&2
  return "$MOCK_SMI_STATUS"
}
main_inner "$@"
printf 'pending=%s\n' "${SUDO_REQUIRED_STEPS[*]}"
'''
    environment = dict(os.environ, PROJECT=str(PROJECT), ISC_FUNCTIONS_DIR=str(FRAMEWORK),
                       XDG_STATE_HOME=str(directory / "state"), INSTALLER_LOG_LEVEL="error",
                       LIS_NVIDIA_APT_CONFIG_DIR=str(directory / "apt.conf.d"),
                       MOCK_ROOT_STATUS="0" if privileged else "1", MOCK_SMI_STATUS=str(smi_status),
                       MOCK_APT_LOG=str(directory / "apt.calls"))
    runner = directory / "run-installer.sh"
    runner.write_text(script)
    result = subprocess.run(["bash", str(runner), *arguments],
                            env=environment, text=True, capture_output=True)
    print(result)
    return result


class NvidiaUpdatesTests(unittest.TestCase):
    """Check policy deployment through existing public CLI commands."""

    def test_install_and_reconfigure(self):
        """Verify an additive, idempotent exclusion before driver installation.

        Parameters: self - test instance.
        Returns: None.
        """
        print(f"self={object.__repr__(self)}")
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            config = directory / "apt.conf.d"
            config.mkdir()
            original = 'Unattended-Upgrade::Package-Blacklist { "custom-package$"; };\n'
            (config / "50existing").write_text(original)
            apt_root = directory / "apt-root.conf"
            apt_root.write_text(f'Dir::Etc::Parts "{config}";\nDir::Etc::main "";\n')
            for arguments in (["--select", "nvidia"], ["--reconfigure", "nvidia"]):
                result = run_installer(directory, arguments)
                self.assertEqual(result.returncode, 0, result.stderr)
                policy = config / "52nvidia-session-safety"
                self.assertTrue(policy.is_file(), result.stdout)
                self.assertEqual((config / "50existing").read_text(), original)
                calls = (directory / "apt.calls").read_text()
                self.assertNotIn("POLICY_MISSING_AT_INSTALL", calls)
                self.assertIn("nvidia-driver-595-open", calls)
                self.assertEqual(policy.stat().st_mode & 0o777, 0o644)
                dump = subprocess.run(["apt-config", "dump"],
                                      env=dict(os.environ, APT_CONFIG=str(apt_root)),
                                      text=True, capture_output=True, check=True).stdout
                patterns = re.findall(r'Unattended-Upgrade::Package-Blacklist:: "([^"]+)";', dump)
                self.assertIn("custom-package$", patterns)
                for package in ("nvidia-driver-595-open", "libnvidia-compute-595", "libnvidia-gl-595:i386",
                                "xserver-xorg-video-nvidia-595", "linux-modules-nvidia-595-open-generic",
                                "linux-objects-nvidia-595-7.0.0-38-generic", "linux-signatures-nvidia-7.0.0-38-generic"):
                    self.assertTrue(any(re.match(pattern, package) for pattern in patterns), package)
                for package in ("openssl", "linux-image-generic-hwe-24.04", "firefox", "libc6"):
                    self.assertFalse(any(re.match(pattern, package) for pattern in patterns), package)
                self.assertNotIn("Automatic-Reboot", policy.read_text())
                self.assertNotIn("APT::Periodic", policy.read_text())
        print(None)

    def test_mismatch_reports_activation(self):
        """Keep the reported mismatch visible and explain safe recovery.

        Parameters: self - test instance.
        Returns: None.
        """
        print(f"self={object.__repr__(self)}")
        with tempfile.TemporaryDirectory() as temporary:
            result = run_installer(Path(temporary), ["--select", "nvidia"], smi_status=18)
            self.assertEqual(result.returncode, 0, result.stderr)
            output = result.stdout + result.stderr
            self.assertIn("Driver/library version mismatch", output)
            self.assertIn("reboot", output.lower())
            self.assertIn("taskbar", output.lower())
        print(None)

    def test_unprivileged_policy_is_deferred(self):
        """Report an exact privileged deployment command without prompting.

        Parameters: self - test instance.
        Returns: None.
        """
        print(f"self={object.__repr__(self)}")
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            result = run_installer(directory, ["--select", "nvidia"], privileged=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((directory / "apt.conf.d/52nvidia-session-safety").exists())
            self.assertIn("pending=sudo install -D -m 0644", result.stdout)
        print(None)

    def test_policy_write_failure_stops_driver_changes(self):
        """Propagate policy deployment failures before touching packages.

        Parameters: self - test instance.
        Returns: None.
        """
        print(f"self={object.__repr__(self)}")
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / "apt.conf.d").write_text("occupied")
            result = run_installer(directory, ["--select", "nvidia"])
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((directory / "apt.calls").exists())
        print(None)

    def test_invalid_cli_has_no_side_effects(self):
        """Retain malformed CLI rejection before any installation effect.

        Parameters: self - test instance.
        Returns: None.
        """
        print(f"self={object.__repr__(self)}")
        for arguments in (["--select"], ["--reconfigure"], ["--unknown"]):
            with tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary)
                result = run_installer(directory, arguments)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertFalse((directory / "apt.calls").exists())
                self.assertFalse((directory / "apt.conf.d").exists())
        print(None)

    def test_extra_operands_are_rejected_before_nvidia_changes(self):
        """Reject extra positional operands without installing or configuring drivers.

        Parameters: self - test instance.
        Returns: None.
        """
        print(f"self={object.__repr__(self)}")
        for operation in ("--select", "--reconfigure"):
            with tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary)
                result = run_installer(directory, [operation, "nvidia", "extra"])
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("unknown option or argument: extra", result.stderr)
                self.assertFalse((directory / "apt.calls").exists())
                self.assertFalse((directory / "apt.conf.d").exists())
        print(None)


if __name__ == "__main__":
    unittest.main()
