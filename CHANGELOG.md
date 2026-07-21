# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/) and
this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/leekwangseon/gpu-sentry/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/leekwangseon/gpu-sentry/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/leekwangseon/gpu-sentry/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/leekwangseon/gpu-sentry/releases/tag/v0.1.0
