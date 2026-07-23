# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/) and
this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.6.0] - 2026-07-23

### Added

- Guided interactive configuration when `gpu-sentry` runs without arguments.
- Full-screen `dialog` and `whiptail` backends with a dependency-free Bash menu fallback.
- Interactive selection for targets, profiles, stress controls, safety limits,
  paths, failure policy, and final confirmation.
- D-Aquila branding in the terminal banner, HTML report, and JSON metadata.

## [0.5.0] - 2026-07-23

### Added

- Inventory, quick, standard, burn-in, and RMA diagnostic profiles.
- Safety preflight checks for active GPU processes, temperature, MIG, power
  limits, Slurm allocations, and local report storage.
- Optional NVIDIA DCGM diagnostics with consumer-GPU level capping.
- Versioned `report.json`, preflight evidence, DCGM evidence, and stable outcome
  exit codes.

### Changed

- Unsafe stress runs now stop with exit code 7 unless `--force` is explicit.
- Diagnostic failures now return exit code 5 while still generating reports.

## [0.4.1] - 2026-07-22

### Fixed

- Prevented unsupported optional `nvidia-smi` query fields such as `compute_cap`
  from aborting inventory collection on older NVIDIA drivers.
- Optional PCIe and compute-capability fields now degrade individually to
  `unknown` while required GPU inventory remains available.

## [0.4.0] - 2026-07-22

### Added

- Multi-strategy CUDA Toolkit discovery for environment variables, PATH, standard
  locations, NVIDIA HPC SDK, environment modules, and bounded filesystem scans.
- `--cuda-home` for explicit target-side CUDA selection.
- CUDA root path and discovery source in diagnostic reports.

### Changed

- Reused the validated CUDA root for gpu-burn builds instead of rediscovering it.

## [0.3.0] - 2026-07-21

### Changed

- Renamed RackProbe to GPU Sentry (`gpu-sentry`) for a clearer product identity.
- Updated executable, installation paths, report branding, documentation, and release assets.

## [0.2.0] - 2026-07-21

### Changed

- Renamed the project and command from gpu-doctor to RackProbe (`rackprobe`).
- Updated report branding, installation paths, documentation, and release artifacts.

## [0.1.0] - 2026-07-21

### Added

- Local and SSH diagnostics with automatic hardware, CUDA, PCIe, and NUMA discovery.
- Topology-aware single, pair, half, and all-GPU stress plans.
- Online and offline gpu-burn installation paths.
- NVIDIA telemetry, kernel log capture, Xid/AER/MCE/NMI analysis, and HTML/PDF reports.
- Extensible Dell, Lenovo, and IPMI vendor collectors.
- ShellCheck and release automation.

[Unreleased]: https://github.com/leekwangseon/gpu-sentry/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/leekwangseon/gpu-sentry/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/leekwangseon/gpu-sentry/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/leekwangseon/gpu-sentry/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/leekwangseon/gpu-sentry/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/leekwangseon/gpu-sentry/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/leekwangseon/gpu-sentry/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/leekwangseon/gpu-sentry/releases/tag/v0.1.0
