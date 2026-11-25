# Linux Installation Setup — Ubuntu GNOME package installer

Linux Installation Setup is an Ubuntu GNOME package installer for workstation users who want
selectable base utilities, desktop apps, and hardware support.

[![Last commit](https://img.shields.io/github/last-commit/mikaeltorni/linux_installations_setup)](https://github.com/mikaeltorni/linux_installations_setup/commits/master)
[![Commit activity](https://img.shields.io/github/commit-activity/m/mikaeltorni/linux_installations_setup)](https://github.com/mikaeltorni/linux_installations_setup/graphs/commit-activity)
[![Issues](https://img.shields.io/github/issues/mikaeltorni/linux_installations_setup)](https://github.com/mikaeltorni/linux_installations_setup/issues)

[Packages](#what-it-installs) · [Requirements](#requirements) · [Configuration](#configuration) · [Tests](#tests) · [Installer commands](#installer-lifecycle) · [MIT license](LICENSE.md)

## Quick start

Run from the checkout in the target user's Ubuntu desktop terminal. System packages require sudo.

```bash
bash install.sh --list-components
sudo INSTALLER_NO_REBOOT=1 bash install.sh --select git
git --version
```

The Ubuntu 24.04.5 GNOME 46 X11 workstation VM installed and detected the profile's package prerequisites on two runs.

## Repository dependencies

This repository installs and runs **standalone** — it has no hard dependency on
any sibling setup repository.

- **Installer support:** the maintained MIT library is included in
  `.installer-support/`, with its license and verifiable source manifest.
  Framework discovery works offline without a private checkout or credentials.

[Linux Configuration Setup](https://github.com/mikaeltorni/linux_configuration_setup) applies desktop settings after the base packages are in place.

## What It Installs

- Base development, desktop, multimedia, remote desktop, and terminal packages,
  including Pillow for cursor asset conversion
- Baobab (GNOME Disk Usage Analyzer), enabled in the default installation menu
- GParted partition editor, enabled as a default-on selectable component
- Google Chrome
- Balena Etcher
- SmartGit, available as an opt-in component, from the pinned official Linux archive
- GitKraken, Spotify, and Discord through Snap
- GitHub CLI, with optional interactive authentication
- Albert launcher
- Optional essential hardware support: Ubuntu firmware and the BlueZ Bluetooth
  userspace stack. The kernel-side Bluetooth drivers are supplied by Ubuntu's
  running kernel.
- Optional author-system Bluetooth workaround: backs up GRUB defaults and
  selects the installed 6.17.0-40-generic kernel for the next boot. It is off
  by default and never reboots the machine itself.
- NVIDIA drivers and CUDA packages when NVIDIA hardware is detected, with
  protection against unattended driver replacement during a desktop session

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
| `BLUETOOTH_KERNEL_VERSION` | Kernel selected by the opt-in Bluetooth fix | `6.17.0-40-generic` (author system) |
| `NVIDIA_DRIVER_PACKAGE` | Override automatic NVIDIA driver selection | Auto-detected |
| `LIS_NVIDIA_APT_CONFIG_DIR` | Override NVIDIA update-policy destination for isolated testing | `/etc/apt/apt.conf.d` |
| `ALBERT_OBS_SERIES` | Override the Albert OBS Ubuntu series | Auto-detected |
| `INSTALLER_REQUIRE_GITHUB_LOGIN` | Force GitHub login even without a TTY | `0` |
| `INSTALLER_NO_REBOOT` | Skip the final reboot when set to `1` | `0` |
| `SMARTGIT_VERSION` | SmartGit release directory name | `26.1.052` |
| `SMARTGIT_ARCHIVE_URL` | SmartGit Linux archive URL | Official pinned archive |
| `SMARTGIT_ARCHIVE_SHA256` | Expected SHA-256 for the archive | Official pinned checksum |
| `SMARTGIT_INSTALL_ROOT` | Root directory for the versioned archive and stable symlink | `/opt` |
| `INSTALLER_LOG_LEVEL` | Minimum log level: `debug`, `info`, `warn`, or `error` | `info` |
| `INSTALLER_PRODUCTION` | Emit JSON log records when set to `1` | `0` |

## Tests

The tests simulate helper behavior and do not install packages:

```bash
python3 tests/test_apt_helpers.py
python3 tests/test_nvidia_updates.py
for test_file in tests/*.sh; do
  bash "$test_file"
done
```

For syntax checks:

```bash
bash -n install.sh lib/*.sh tests/*.sh
python3 -m py_compile tests/*.py
```

## Module Layout

- `lib/apt_packages.sh`: APT cache management and selectable package groups,
  including GParted and the opt-in essential hardware support group
- `lib/app_installer.sh`: Chrome, Etcher, SmartGit, and GitHub CLI installation
- `lib/albert_installer.sh`: Albert OBS series detection, installation, and autostart
- `lib/snap_installer.sh`: Snap application installation
- `lib/hardware.sh`: NVIDIA detection, driver selection, update policy, NVML
  health reporting, and service setup
- `assets/apt/52nvidia-session-safety`: additive unattended-upgrade exclusions
  for NVIDIA drivers, libraries, and versioned kernel-module packages
- `lib/bluetooth.sh`: GRUB backup and one-time kernel selection for Bluetooth
- `lib/inotify_limits.sh`: sysctl drop-in raising inotify instances/watches
- `lib/apt_helpers.sh`: Compatibility entry that sources package and app installers
- `lib/lifecycle.sh`: Detect/uninstall helpers for selectable applications
- `lib/nodejs_installer.sh`: Node.js 22 runtime installation
- `lib/system_services.sh`: GitHub CLI authentication
- `lib/logging.sh`: Centralized Bash installer logging

## Notes

- Package and application installs are designed to be rerunnable.
- APT update failures are logged and installation continues where possible.
- GitHub authentication is skipped in non-interactive runs unless
  `INSTALLER_REQUIRE_GITHUB_LOGIN=1`.
- NVIDIA service enablement is best-effort because service names vary by
  driver package and Ubuntu release.
- `bluetooth_kernel_fix` is an opt-in workaround for the author's MediaTek
  MT7922 system. It depends on `essential_drivers`, backs up
  `/etc/default/grub` as `/etc/default/grub.backup.<timestamp>`, resolves the
  exact kernel menu ID from `/boot/grub/grub.cfg`, and writes a one-time
  `next_entry` with `grub-reboot`. It does not reboot; use
  `BLUETOOTH_KERNEL_VERSION` to target a different installed kernel.
- Extension `metadata.json` pinning lives in `linux_configuration_setup`
  (`lcs-tools patch-metadata`), not in this repository.

## NVIDIA driver updates and GPU readings

The `nvidia` component installs
`/etc/apt/apt.conf.d/52nvidia-session-safety` before installing drivers.
It excludes NVIDIA driver packages, `libnvidia-*`, the NVIDIA Xorg driver,
and NVIDIA kernel-module/object/signature packages from unattended upgrades.
Other automatic security updates and existing package exclusions remain enabled.
This uses the upstream
[`Unattended-Upgrade::Package-Blacklist`](https://github.com/mvo5/unattended-upgrades#supported-options)
setting; it does not hold packages or prevent manual APT updates.

NVIDIA updates, including driver security fixes, must now be applied manually
when you can save your work and restart afterward. A manual driver update can
still produce a temporary mismatch until reboot. A full system upgrade or the
graphical updater can update these packages too, so schedule those accordingly.

Install or reconfigure just this component without an automatic reboot:

```bash
sudo INSTALLER_NO_REBOOT=1 bash install.sh --select nvidia
sudo INSTALLER_NO_REBOOT=1 bash install.sh --reconfigure nvidia
```

For an existing installation that only needs the prevention policy, run from
this repository's root:

```bash
sudo install -D -m 0644 assets/apt/52nvidia-session-safety /etc/apt/apt.conf.d/52nvidia-session-safety
apt-config dump | grep 'Unattended-Upgrade::Package-Blacklist'
```

The policy takes effect for the next unattended-upgrade run without a service
restart. Policy deployment failures stop NVIDIA package installation. The
policy helper records an exact sudo command when called without privileges;
the full base-system installer still requires root.

If `nvidia-smi` reports `Driver/library version mismatch`, compare the running
module with the installed one:

```bash
cat /proc/driver/nvidia/version
modinfo -F version nvidia
dkms status
```

When the updated module is installed for the kernel you will boot, save your
work and restart through the desktop. Do not unload the driver used by the
running graphical session. After login, verify `nvidia-smi -L` and taskbar GPU
readings. If they still fail, inspect kernel/DKMS logs; do not repeatedly
reinstall drivers or clear taskbar device settings. The installer reports
NVML failures and gives reboot guidance specifically for a version mismatch.

To restore automatic NVIDIA updates later, remove only
`/etc/apt/apt.conf.d/52nvidia-session-safety`; existing APT configuration is
retained.

## Component selection

This repository's `install.sh` participates in the shared installer
component menu (see the `installation_scripts`
master installer). Run standalone, it offers an interactive submenu on a
terminal; the master installer drives it non-interactively.

```bash
bash install.sh                 # interactive component selection (TTY), else defaults
bash install.sh --config NAME   # load installation_configs/NAME
bash install.sh --default       # install all default-on components, no prompts
bash install.sh --all           # install every component, no prompts
bash install.sh --select a,b    # install exactly these component ids
bash install.sh --auth          # allow authenticated Git clone/pull in components
bash install.sh --list-components  # print component ids, labels, defaults, and sections
bash install.sh --list-configurable-components
                                # list components with nested detail screens
bash install.sh --list-select-configure-components
                                # list components that configure on selection
bash install.sh --list-component-config-values
                                # list editable component values
bash install.sh --configure-component ID
                                # open one component's nested detail screen
bash install.sh --export-selection  # export resolved selection as JSON
bash install.sh --help          # show all installer options
bash install.sh --list-favorite-components
                                # print app components that can be dock favourites
bash install.sh --list-startup-components
                                # print app startup metadata and defaults
```

SmartGit is off for `--default` installs and remains available through
`--select smartgit`. Changing this default does not uninstall an existing copy.

In the interactive menu, **space** toggles a component, `a`/`n` select all
or none, and **Enter** installs the selection. GParted is enabled by default.
To select only it in a future installer run, use
`sudo bash install.sh --select gparted`. Components:

When run through the master installer, app components that can become GNOME dock
favourites expose their `.desktop` ids through `--list-favorite-components`. The
master menu lets you toggle those with **f** and forwards the selected list to
`linux_configuration_setup`.
Baobab is selected as a dock favorite by default.
Spotify and Discord remain installed and startup-enabled by default, but are
not selected as dock favorites; choose **f** in the master menu to pin either.

VLC, OBS, and EasyEffects now have separate components and expose individual
startup launcher candidates through
`--list-startup-components`. In the master menu, **s** toggles launch at desktop
login; rows selected for favourite and startup display `FS`. Existing default
startup behavior is preserved for Spotify, GitKraken, SmartGit, EasyEffects, and Albert.

The same listing's fourth column carries each application's default display
monitor for the master menu's **m** action (0 = unpinned). Spotify and Discord
default to monitor 1; the master installer forwards the chosen numbers to
`linux_workspaces_setup`, which writes the per-application placement rules.

The core command-line tools are also independent components (`git`, `curl`,
`gpg`, `jq`, and `p7zip`). Compatibility union arrays remain available to the
legacy aggregate installation helper, but the menu no longer couples their
selection.

Every feature is its own independently selectable component. Most components
are default-on so a clean install reproduces the full setup; essential hardware
support and the author-system Bluetooth kernel fix are intentionally opt-in.
Ubuntu Desktop commonly already ships the firmware and Bluetooth stack.
The submenu groups rows into **Core CLI utilities**, **System dependencies**,
**Desktop applications**, and **Drivers & hardware**. Every row in Desktop
applications supports the master menu's `[S]` startup action.

| Component id | Description | Default |
|---|---|---|
| `git` | Git version-control CLI | on |
| `curl` | curl data-transfer CLI | on |
| `gpg` | GnuPG encryption/signing CLI | on |
| `jq` | jq JSON-processing CLI | on |
| `p7zip` | 7-Zip archive CLI | on |
| `gnome_tooling` | GNOME Shell extension & tweak tooling | on |
| `build_tools` | Build toolchain & development headers | on |
| `nodejs` | Node.js 22 runtime with npm (NodeSource) | on |
| `terminal` | Kitty terminal emulator | on |
| `python_runtime` | Python runtime & configuration libraries (includes Secret Service support) | on |
| `desktop_utils` | X11 & desktop utilities (xdotool, screenshot) | on |
| `inotify_limits` | Raise inotify instances/watches (desktop agents/tmux) | on |
| `audio_speech` | Audio stack & speech synthesis | on |
| `vlc` | VLC media player | on |
| `obs` | OBS Studio | on |
| `easyeffects` | EasyEffects audio effects | on |
| `remote_desktop` | Remmina remote desktop client | on |
| `baobab` | Baobab disk usage analyzer | on |
| `gparted` | GParted partition editor | on |
| `tmux` | tmux terminal multiplexer | on |
| `virtualization` | KVM/libvirt virtualization stack | on |
| `chrome` | Google Chrome | on |
| `etcher` | balenaEtcher | on |
| `smartgit` | SmartGit (official Linux archive) | off (opt-in) |
| `snap_gitkraken` | GitKraken (snap) | on |
| `snap_spotify` | Spotify (snap) | on |
| `snap_discord` | Discord (snap) | on |
| `gh_cli` | GitHub CLI | on |
| `github_login` | GitHub login (gh auth) | on |
| `albert` | Albert launcher | on |
| `essential_drivers` | Essential hardware drivers (Linux firmware + Bluetooth) | off |
| `bluetooth_kernel_fix` | Bluetooth MT7922 kernel fix (author's system; selects 6.17.0-40) | off |
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

## Ubuntu GNOME package installer FAQ

### How do I list the available Ubuntu packages and tools?

Run `bash install.sh --list-components` first. The output includes each component ID, its label, and whether it is enabled by default.

### Can I install only the Git tooling?

Run `sudo INSTALLER_NO_REBOOT=1 bash install.sh --select git` from the target desktop user's terminal. Check the result with `git --version`.

### Why does package installation need sudo?

APT-managed components modify the system package database. Run the package installer in the target user's graphical session so any user-level configuration uses that session.

### How can I confirm what the installer selected?

Run `bash install.sh --export-selection` to get JSON for the resolved selection. To query current install state instead, run `bash install.sh --detect`.

### Where are package installer logs saved?

The installer writes timestamped output under `.log/` in the checkout. Check the latest log and the selected component’s section if APT reports a failure.

## Installer lifecycle

Run these commands from this checkout. The component IDs printed by discovery
are the same IDs used by the terminal menu and programmatic actions.

| Command | Behavior |
| --- | --- |
| `bash install.sh` | Open component selection on a terminal; use the default/config selection otherwise. |
| `bash install.sh --help` | Show accepted options (`-h` is equivalent). |
| `bash install.sh --list-components` | Print component IDs, labels and defaults. |
| `bash install.sh --default` | Apply default-on components. |
| `bash install.sh --all` | Apply every component. |
| `bash install.sh --select ID,...` | Apply exactly the named components. |
| `bash install.sh --reconfigure ID,...` | Reapply those components through the same install operations. |
| `bash install.sh --uninstall ID,...` | Run the selected removal operations. |
| `bash install.sh --detect` | Print `ID<TAB>installed` or `ID<TAB>absent`. |
| `bash install.sh --export-selection` | Print selection JSON without applying it. |

The shared interface also accepts `--config NAME` (an installation JSON name
or path) and `--auth` (explicit permission for authenticated component actions).
`--config=NAME`, `--select=ID,...`, `--reconfigure=ID,...`,
`--uninstall=ID,...` and `--configure-component=ID` are equivalent forms.
Advanced discovery is available through `--list-configurable-components`,
`--list-select-configure-components` and `--list-component-config-values`;
`--configure-component ID` opens an available nested screen. Atomic owners
return empty advanced listings and reject unavailable nested configuration.

Explicit `--select ""` selects no optional components; a defined mandatory core
or installation preflight still runs. `--uninstall ""` is a no-op. Unknown or
duplicate IDs, missing operands and conflicting modes reject before component
installation/removal. Help, discovery, detection and export perform no installation.
Cancelling the component menu performs no install/removal. Configuration screens
may save their own settings when explicitly accepted.

The shared terminal screen uses arrows to move, Space to toggle, Enter to
apply and `q`/Escape to cancel; installed components support `u` for removal.
A right-arrow detail action appears where the owner provides configuration.
Removal-only selections skip core installation.

The licensed `.installer-support/` package is generated by
`linux_installation_scripts_functions`; `manifest.json` records provenance and
SHA-256 hashes, and `LICENSE.md` retains the MIT grant. It is a shared library
subset, not an application checkout. The default bootstrap requires no private
download or sibling repository. Explicit `ISC_COMPONENT_LIB_DIR` /
`ISC_FUNCTIONS_DIR` overrides remain available for development and the old setup
chain. Regenerate support from its owner rather than editing copies. Bash and
Python 3 are needed for this library; project build/runtime requirements above
still apply.

Components without a reversible uninstall callback clear their installation
receipt only; they do not undo installed packages, downloaded models or settings.
Live detection can therefore continue to report an installed resource afterward.
This applies to: `git`, `curl`, `gpg`, `jq`, `p7zip`, `nodejs`, `tmux`, `github_login`, `gnome_tooling`, `build_tools`, `python_runtime`, `desktop_utils`, `audio_speech`, `terminal`, `remote_desktop`, `baobab`, `gparted`, `virtualization`, `essential_drivers`, `bluetooth_kernel_fix`, `nvidia`, `terminal`, `vlc`, `obs`, `easyeffects`, `remote_desktop`, `baobab`, `gparted`, `chrome`, `etcher`, `smartgit`, `snap_gitkraken`, `snap_spotify`, `snap_discord`, `albert`, `nvidia`, `virtualization`.

Base-system installation requires root (`sudo bash install.sh`); discovery
and help do not. Successful installation retains the guarded reboot request;
`INSTALLER_NO_REBOOT=1` suppresses it. Menu cancellation and removal-only plans
do not request reboot. Selection takes place before output is piped to the log.

For example, inspect IDs first, then use the same ID with either interface:

```bash
bash install.sh --list-components
sudo bash install.sh --select git
bash install.sh --detect
sudo bash install.sh --uninstall git
```
