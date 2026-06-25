# Linux Installation Setup

> Part of [installation_scripts](https://github.com/mikaeltorni/installation_scripts) — the master installer that orchestrates a productivity-focused Ubuntu 24.04 desktop setup (workspaces, hotkeys, window tiling, programming tools, and more). Tested on Ubuntu 24.04.4 LTS.

Installs the base desktop packages and applications used on an Ubuntu GNOME
workstation. This repository is phase 1 of the larger installation workflow;
repository cloning and later configuration phases belong in the master
installer.

## Repository dependencies

This repository installs and runs **standalone** — it has no hard dependency on
any sibling setup repository.

- **Build-time (soft):** the shared installer component framework
  [`linux_installation_scripts_functions`](https://github.com/mikaeltorni/linux_installation_scripts_functions) —
  loaded from a sibling checkout when present, otherwise downloaded on demand,
  so a missing checkout never blocks installation.

See the full cross-repository map in
[installation_scripts/DEPENDENCIES.md](https://github.com/mikaeltorni/installation_scripts/blob/master/DEPENDENCIES.md).

## What It Installs

- Base development, desktop, multimedia, remote desktop, and terminal packages,
  including Pillow for cursor asset conversion
- Google Chrome
- Balena Etcher
- GitKraken, Spotify, and Discord through Snap
- GitHub CLI, with optional interactive authentication
- Albert launcher
- NVIDIA drivers and CUDA packages when NVIDIA hardware is detected

## Requirements

- Ubuntu 20.04, 22.04, or 24.04 with GNOME
- An active internet connection
- A logged-in graphical desktop session
- `sudo` access

Run the script from a terminal opened inside the target user's graphical
session. The installer needs that session's D-Bus socket to configure
user-level applications.

## Usage

```bash
sudo bash install.sh
```

The installer writes a timestamped log to `.log/` and reboots after a
10-second delay when installation succeeds.

To run without rebooting:

```bash
sudo INSTALLER_NO_REBOOT=1 bash install.sh
```

## Configuration

The following environment variables are supported:

| Variable | Purpose | Default |
| --- | --- | --- |
| `ETCHER_VERSION` | Balena Etcher release to install, or `latest` | `latest` |
| `NVIDIA_DRIVER_PACKAGE` | Override automatic NVIDIA driver selection | Auto-detected |
| `ALBERT_OBS_SERIES` | Override the Albert OBS Ubuntu series | Auto-detected |
| `INSTALLER_REQUIRE_GITHUB_LOGIN` | Force GitHub login even without a TTY | `0` |
| `INSTALLER_NO_REBOOT` | Skip the final reboot when set to `1` | `0` |
| `INSTALLER_LOG_LEVEL` | Minimum log level: `debug`, `info`, `warn`, or `error` | `info` |
| `INSTALLER_PRODUCTION` | Emit JSON log records when set to `1` | `0` |

## Tests

The tests simulate helper behavior and do not install packages:

```bash
python3 tests/test_apt_helpers.py
python3 tests/test_logging_utils.py
python3 tests/test_patch_extension_metadata.py
for test_file in tests/*.sh; do
  bash "$test_file"
done
```

For syntax checks:

```bash
bash -n install.sh lib/*.sh tests/*.sh
python3 -m py_compile scripts/*.py tests/*.py
```

## Module Layout

- `lib/apt_packages.sh`: APT cache and base package installation
- `lib/app_installer.sh`: Chrome, Etcher, and GitHub CLI installation
- `lib/albert_installer.sh`: Albert OBS series detection, installation, and autostart
- `lib/snap_installer.sh`: Snap application installation
- `lib/hardware.sh`: NVIDIA detection, driver selection, and service setup
- `lib/system_services.sh`: GitHub CLI authentication
- `lib/logging.sh`: Centralized Bash installer logging
- `scripts/logging_utils.py`: Centralized Python file logging and call tracing

`lib/apt_helpers.sh` remains the compatibility entry point for package and
application installer functions.

## Notes

- Package and application installs are designed to be rerunnable.
- APT update failures are logged and installation continues where possible.
- GitHub authentication is skipped in non-interactive runs unless
  `INSTALLER_REQUIRE_GITHUB_LOGIN=1`.
- NVIDIA service enablement is best-effort because service names vary by
  driver package and Ubuntu release.
- `scripts/patch_extension_metadata.py` is a standalone helper that adds a
  GNOME `shell-version` entry to an extension's `metadata.json`. It is invoked
  by the wider installation workflow:
  `python3 scripts/patch_extension_metadata.py <metadata.json> <shell-version>`.

## Component selection

This repository's `install.sh` participates in the shared installer
component menu (see the [`installation_scripts`](https://github.com/mikaeltorni/installation_scripts)
master installer). Run standalone, it offers an interactive submenu on a
terminal; the master installer drives it non-interactively.

```bash
bash install.sh                 # interactive component selection (TTY), else defaults
bash install.sh --default       # install all default-on components, no prompts
bash install.sh --all           # install every component, no prompts
bash install.sh --select a,b    # install exactly these component ids
bash install.sh --list-components  # print: id<TAB>label<TAB>default
```

In the interactive menu, **space** toggles a component, `a`/`n` select all
or none, and **Enter** installs the selection. Components:

Every feature is its own independently selectable component, all default-on,
so a clean install reproduces the full setup while you can deselect anything.

| Component id | Description | Default |
|---|---|---|
| `core_utils` | Core CLI utilities (git, curl, gpg, jq, 7zip) | on |
| `gnome_tooling` | GNOME Shell extension & tweak tooling | on |
| `build_tools` | Build toolchain & development headers | on |
| `terminal` | Kitty terminal emulator | on |
| `python_runtime` | Python runtime & libraries | on |
| `desktop_utils` | X11 & desktop utilities (xdotool, screenshot) | on |
| `audio_speech` | Audio stack & speech synthesis | on |
| `multimedia` | Multimedia apps (VLC, OBS, EasyEffects) | on |
| `keyring` | GNOME Keyring & Secret Service libraries | on |
| `remote_desktop` | Remmina remote desktop client | on |
| `tmux` | tmux terminal multiplexer | on |
| `virtualization` | KVM/libvirt virtualization stack | on |
| `chrome` | Google Chrome | on |
| `etcher` | balenaEtcher | on |
| `snap_gitkraken` | GitKraken (snap) | on |
| `snap_spotify` | Spotify (snap) | on |
| `snap_discord` | Discord (snap) | on |
| `gh_cli` | GitHub CLI | on |
| `github_login` | GitHub login (gh auth) | on |
| `albert` | Albert launcher | on |
| `nvidia` | NVIDIA drivers (if a GPU is detected) | on |

## Detect, reconfigure, and uninstall

This installer tracks what it has installed and can re-apply or remove it, so you
can refresh configuration after a repo update or cleanly back a feature out.

```bash
bash install.sh --detect            # show each component as installed|absent
bash install.sh --reconfigure a,b   # re-apply (idempotent) these component ids
bash install.sh --uninstall a,b     # uninstall these component ids
```

In the interactive menu (run `bash install.sh` on a terminal, or via the master
installer), already-installed components show a green `✓`. Select one with
**space** to **reconfigure** it (`~`), press **`u`** to mark it for **uninstall**
(`✗`), or press **`r`** to reconfigure every installed component at once. Detection
uses a live check where deterministic and otherwise an install receipt under
`${XDG_STATE_HOME:-~/.local/state}/isc/receipts/`; a component without a reversal
step simply clears that receipt on uninstall.

## Disclaimer

This software is provided under the MIT License on an **“as is”** basis, without warranties of any kind. To the maximum extent permitted by applicable law, the authors and copyright holders shall not be liable for any claims, damages, losses, or other liability arising from the use of this software.

You are solely responsible for determining whether this software is suitable, safe, lawful, and appropriate for your intended use. Unless explicitly stated otherwise, this project is general-purpose software and is not designed, tested, certified, or approved for safety-critical, medical, automotive, aviation, industrial-control, life-support, cybersecurity-critical, financial-critical, or other high-risk use cases.

The authors and copyright holders make no guarantees regarding security, reliability, availability, correctness, compliance, non-infringement, or fitness for any particular purpose.

This notice is intended to clarify the nature of the project and does not impose additional restrictions beyond the MIT License.
