# Linux Installation Setup

**Phase 1 of 7** — Base system packages, hardware detection, and application installation.

## Overview

This repository is the master installer that sets up a fresh Ubuntu 24.04 desktop environment. It handles:

- **Base package installation**: GNOME Shell extensions manager, terminals (kitty), development tools, multimedia apps
- **Hardware detection & drivers**: NVIDIA GPU detection and driver/CUDA toolkit installation
- **Application installation**: Google Chrome, Balena Etcher, GitHub CLI, Albert launcher, Snap apps
- **Repository orchestration**: Clones and runs all subsequent setup repositories in order

## Repository Chain (7 repos)

The installer clones and runs these repositories in dependency order:

| # | Repository | Purpose |
|---|-----------|---------|
| 1 | `linux_installations_setup` (this repo) | Base packages, hardware, apps |
| 2 | `linux_configuration_setup` | GNOME desktop, autostart, GSettings |
| 3 | `linux_hotkey_setup` | GNOME hotkeys and workspace bindings |
| 4 | `agent_command_center` | Agent command center components |
| 5 | `linux_programming_setup` | Cursor IDE, VS Code extensions |
| 6 | `ubuntu_2404_taskbar_system_status_monitor` | Taskbar system monitor extension |
| 7 | `phrase_automation` | Phrase automation tmux service |

## Installation

```bash
# Clone this repo (or the main installation_scripts wrapper)
git clone https://github.com/mikaeltorni/linux_installations_setup.git
cd linux_installations_setup

# Run as root — it will handle everything else
sudo bash install.sh
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ETCHER_VERSION` | `2.1.4` | Balena Etcher version to install |
| `NVIDIA_DRIVER_PACKAGE` | (auto-detected) | Override NVIDIA driver package name |
| `INSTALLER_NO_REBOOT` | `0` | Set to `1` to skip automatic reboot |

## Idempotency

All installation steps are idempotent:
- Packages: checked via `need_cmd()` before installing
- Extensions: checked for existing `.git` directory or installed files
- Configs: GSettings operations use `set_if_key_exists` pattern
- Apps: Chrome, Etcher, GH CLI all check if already in PATH

## Structure

```
linux_installations_setup/
├── install.sh              # Master installer entry point
├── lib/
│   ├── helpers.sh          # Core utilities (msg, run_as_target, etc.)
│   ├── logging.sh          # Centralized logging with levels
│   ├── hardware.sh         # NVIDIA GPU detection and driver installation
│   ├── system_services.sh  # Repo cloning logic, GitHub login
│   ├── apt_helpers.sh      # APT package management helpers
│   └── app_installer.sh    # Chrome, Etcher, snaps, GH CLI, Albert installers
├── scripts/
│   └── patch_extension_metadata.py  # Patch GNOME extension metadata.json
└── .gitignore
```

## License

MIT

## Disclaimer

This software is provided under the MIT License on an **“as is”** basis, without warranties of any kind. To the maximum extent permitted by applicable law, the authors and copyright holders shall not be liable for any claims, damages, losses, or other liability arising from the use of this software.

You are solely responsible for determining whether this software is suitable, safe, lawful, and appropriate for your intended use. Unless explicitly stated otherwise, this project is general-purpose software and is not designed, tested, certified, or approved for safety-critical, medical, automotive, aviation, industrial-control, life-support, cybersecurity-critical, financial-critical, or other high-risk use cases.

The authors and copyright holders make no guarantees regarding security, reliability, availability, correctness, compliance, non-infringement, or fitness for any particular purpose.

This notice is intended to clarify the nature of the project and does not impose additional restrictions beyond the MIT License.
