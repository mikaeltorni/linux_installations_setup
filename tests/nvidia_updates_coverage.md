# NVIDIA update safety coverage

Public entrypoint: `install.sh`'s `main_inner` → unchanged framework `component_main`.
All installations run in temporary state with simulated hardware, privilege and package/service operations.

| Operation | Success/boundary assertions | Missing operand | Extra operand | Conversion/domain/resource cases | Actual shared owner or inapplicable reason |
| --- | --- | --- | --- | --- | --- |
| --select nvidia | test_install_and_reconfigure: policy parsed by apt-config; exact package exclusion, preserved unrelated policy, installation ordering, mode 0644 | test_invalid_cli_has_no_side_effects: --select | same test: --select nvidia extra | test_policy_write_failure_stops_driver_changes: invalid destination; test_unprivileged_policy_is_deferred; test_mismatch_reports_activation: original NVML error | shared component_main parser; configure_nvidia_update_policy operation; no numeric arguments |
| --reconfigure nvidia | test_install_and_reconfigure: second invocation with receipt and same policy | test_invalid_cli_has_no_side_effects: --reconfigure | same test: --reconfigure nvidia extra | same installed-policy owner as --select | Same shared parser and install operation |
| unknown flag | test_invalid_cli_has_no_side_effects: --unknown | not applicable | not applicable | rejection has no files or package calls | shared component_main |

Gate B: no expected-exception bodies load hardware.sh in existing tests/test_hardware.sh or tests/test_components.sh; the new tests use return status assertions. Each malformed CLI case uses fresh state and immediately reads its package-call and config-file observations. No public read query exposes this APT drop-in; installed files and apt-config are the direct consumer observation. Command is stateless apart from filesystem receipts/installations. Blank CLI means documented default install and is not rejected; no invented blank rejection.

Existing operations retained: ubuntu-drivers recommendation/override/fallback and hardware detection in tests/test_hardware.sh, all component routing in tests/test_components.sh. No new command grammar, numeric/domain checks, GPU-setting change or destructive activation.

Extra-operand cells use test_extra_operands_preserve_shared_cli_contract: --select nvidia extra and --reconfigure nvidia extra. Direct source evidence: shared component_runtime.sh:857 warns and ignores positional arguments; preserving that existing contract takes precedence over introducing unrelated rejection behavior. Missing operands and unknown flags still reject.

Checkpoint: pre-code baseline `python3 tests/test_nvidia_updates.py` ran 6 tests: 4 intended failures and 2 retained CLI cases passed; exit 1. Initial draft assumed extra rejection, corrected before code using the actual shared contract and reran baseline. All checks were saved before application edits.
