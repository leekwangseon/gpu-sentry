# gpu-doctor

`gpu-doctor` is a field-oriented NVIDIA GPU server diagnostic tool for local or
single-hop SSH operation. It discovers hardware, builds a topology-aware stress
plan, captures raw evidence, recognizes common failure signatures, and creates
customer-ready HTML and PDF reports.

The project refactors the behavior of `gpu_remote_test_from_master_v4.sh` into
maintainable modules. It targets RHEL 8, Rocky Linux 8/9, AlmaLinux, and Ubuntu
22.04/24.04 on Dell, ASUS, Lenovo, Supermicro, and standards-based servers.

## Highlights

- Detects GPU count/model, driver and CUDA versions, PCIe link state, topology,
  NUMA context, CPU, memory, BIOS, and platform identity.
- Supports RTX 3090/4090, A100, H100, H200, L40/L40S, RTX PRO Blackwell, and
  future NVIDIA GPUs without model allowlists.
- Generates single and pair tests for every system, half-system tests at eight
  GPUs and above, and an all-GPU test.
- Finds CUDA via PATH or environment modules.
- Installs gpu-burn in `git → curl → wget → bundled archive` order.
- Captures telemetry and kernel logs; analyzes NVIDIA Xid 48/79, AER, MCE, NMI,
  PCIe, and stress failures.
- Uses optional racadm/OMSA, Lenovo OneCLI, or ipmitool collectors without making
  server configuration changes.

## Quick start

```bash
git clone https://github.com/leekwangseon/gpu-doctor.git
cd gpu-doctor
chmod +x bin/gpu-doctor

sudo ./bin/gpu-doctor --local --power 300 --time 600
./bin/gpu-doctor --host gpu01 --power 300 --time 600
```

For a safe inventory pass that does not install or run gpu-burn:

```bash
./bin/gpu-doctor --host gpu01 --inventory-only
```

Logs are created at `logs/YYYYMMDD/HOST/` with `main.log`, `gpu.csv`,
`dmesg.log`, `report.html`, `report.pdf`, the test plan/results, inventories,
vendor evidence, and automated analysis.

## Options

Run `./bin/gpu-doctor --help`. Key controls are `--power`, `--time`,
`--cooldown`, `--interval`, `--continue-on-failure`, and `--gpu-burn`.

When `--power` is nonzero, the limit is applied with `nvidia-smi -pl` before
stress testing and the previously reported limits are restored during cleanup.
This action normally requires elevated privileges.

## Offline use

Place an audited upstream source archive at
`tools/gpu-burn/gpu-burn.tar.gz`. The tool copies it to the target only after
git, curl, and wget acquisition attempts fail. CUDA, a C++ compiler, make, and
tar must already exist on the target.

## Safety

Stress testing can expose marginal hardware and interrupt workloads. Drain the
server, obtain a maintenance window, verify cooling and power capacity, and
review vendor limits first. The tool reads diagnostics and installs gpu-burn;
it does not update firmware or alter BIOS/BMC configuration.

## Development

```bash
make lint
make test
```

See [architecture](docs/architecture.md), [troubleshooting](docs/troubleshooting.md),
and [contributing](CONTRIBUTING.md). Licensed under the [MIT License](LICENSE).
