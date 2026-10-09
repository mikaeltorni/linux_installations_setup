# GParted feature coverage inventory

## Capability queue

| # | Complete capability sentence (verbatim) | Commands | Checkpoint |
| --- | --- | --- | --- |
| 1 | `add gparted to the installation however we dont need to install it now` | Add GParted as a default-on selectable package component; do not run real APT or the installer. | 3.2 implementation and cumulative verification complete; no real install run. |

## Operation checks

| Operation | Rejection class | Rejected public input | Validation owner | Expected rejection | Test and immediate observations |
| --- | --- | --- | --- | --- | --- |
| GParted installation component | Package-manager failure | Mock `apt install` exits 23 after the component calls the shared installer | `lib/apt_packages.sh` (`apt_install` and `install_pkg_group`) | `lis_install_gparted` returns 23; the trace contains `apt install -y gparted` | `tests/test_gparted.sh`: mocked installer failure case checks the returned status and exact package request. |
| GParted detection | Package absent | Mock `dpkg -s gparted` reports absent | `lib/lifecycle.sh` (`lis_pkgs_installed`) | `detect_gparted` returns nonzero | `tests/test_gparted.sh`: absent-package check follows the present-package case with the same isolated mock. |

| Operation success | Independent expected result | Test location |
| --- | --- | --- |
| Public component registration | `--list-components` includes `gparted`, label `GParted partition editor`, default `on`, section `Desktop applications`. | `tests/test_gparted.sh`, public listing assertion. |
| Package installation wiring | Mock APT records `apt update -y` then `apt install -y gparted`; no real package manager is called. | `tests/test_gparted.sh`, mocked install success case. |
| Package detection | Mock `dpkg -s gparted` reports installed and `detect_gparted` succeeds. | `tests/test_gparted.sh`, installed-package case. |
| Base package compatibility union | `APT_GPARTED` contains `gparted`, and `APT_BASE_PACKAGES` contains it exactly as the aggregate package set. | `tests/test_gparted.sh`, array assertions; retained `tests/test_components.sh::groups_cover_base_packages`. |

## Applicable retained checks and limits

- `tests/test_components.sh::groups_cover_base_packages` compares every explicitly listed package group with `APT_BASE_PACKAGES`; its union now includes `APT_GPARTED` and passed after implementation. This is a retained success assertion, not an expected-exception block.
- No existing rejection block needs a new read: this Feature adds package installation and detection metadata, not a public read API or mutable application state.
- No new command parser or operand shape is added. Empty/unknown commands, missing/extra operands, numeric conversion, domain ranges and resource lookup are therefore inapplicable. Package-manager failure and absent-package detection are covered above.
- The public installer is never run with an installation selection. The only installer invocation in checks is read-only `--list-components`; all package calls are captured by the mock `apt` executable.

## Baseline observed before installer changes

- `bash tests/test_gparted.sh` exited 1 with seven intended missing-feature failures: public default-on listing; `APT_GPARTED`; aggregate package membership; component installer/detector mapping; desktop action metadata; installer function; detector function. The shared component listing command itself completed; this was not a setup or dependency failure.
- `bash tests/test_components.sh` exited 0 with 18 passed and 0 failed, preserving the existing component behavior.
- The APT and dpkg executables used by `test_gparted.sh` are temporary mocks. No package install was attempted.

## Verification after implementation

- `bash tests/test_gparted.sh`: exit 0; all nine checks passed, including default-on public listing, package aggregation, mocked APT success and failure, and mocked installed/absent detection.
- `bash tests/test_components.sh`: exit 0; 18 passed, 0 failed.
- `python3 tests/test_apt_helpers.py`: exit 0; 7 passed, 0 failed.
- All `tests/*.sh` checks passed. `test_hardware.sh` (8 passed) and `test_system_services.sh` (1 passed) were run through a temporary task-local sibling layout because their scripts resolve the shared helper using `../linux_installation_scripts_functions`; the temporary layout was removed.
- `bash -n install.sh installer/components.sh lib/*.sh tests/*.sh`: exit 0.
- `git diff --check`: exit 0.
- No real `apt`, installer selection, package deployment or reboot was run.
