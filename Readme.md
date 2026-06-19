# Linux Installation Setup

> Part of [installation_scripts](https://github.com/mikaeltorni/installation_scripts) — the master installer that orchestrates a productivity-focused Ubuntu 24.04 desktop setup (workspaces, hotkeys, window tiling, programming tools, and more). Tested on Ubuntu 24.04.4 LTS.

Installs the base desktop packages and applications used on an Ubuntu GNOME
workstation. This repository is phase 1 of the larger installation workflow;
repository cloning and later configuration phases belong in the master
installer.

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
python3 tests/test_patch_extension_metadata.py
for test_file in tests/*.sh; do
  bash "$test_file"
done
```

For syntax checks:

```bash
bash -n install.sh lib/*.sh tests/*.sh
python3 -m py_compile scripts/patch_extension_metadata.py tests/*.py
```

## Module Layout

- `lib/apt_packages.sh`: APT cache and base package installation
- `lib/app_installer.sh`: Chrome, Etcher, and GitHub CLI installation
- `lib/albert_installer.sh`: Albert OBS series detection, installation, and autostart
- `lib/snap_installer.sh`: Snap application installation
- `lib/hardware.sh`: NVIDIA detection, driver selection, and service setup
- `lib/system_services.sh`: GitHub CLI authentication

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

| Component id | Description | Default |
|---|---|---|
| `base_packages` | Base APT packages and utilities | on |
| `chrome` | Google Chrome | on |
| `etcher` | balenaEtcher | on |
| `snaps` | Snap apps (GitKraken, Spotify, Discord) | on |
| `gh_cli` | GitHub CLI | on |
| `github_login` | GitHub login (gh auth) | on |
| `albert` | Albert launcher | on |
| `nvidia` | NVIDIA drivers (if a GPU is detected) | on |

