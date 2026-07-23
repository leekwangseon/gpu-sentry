# Architecture

`bin/gpu-sentry` owns argument parsing and orchestration. Library modules are
small capability boundaries: transport, inventory, GPU testing, installation,
CUDA discovery, profiles, safety preflight, DCGM, analysis, JSON, and reporting.
All remote commands go through `lib/ssh.sh`, allowing
collectors to work unchanged in local and SSH modes.

Vendor support is capability-based. Dell uses racadm/OMSA, Lenovo uses OneCLI,
and other platforms use IPMI when present. Future vendor collectors should emit
plain logs and must not make configuration changes.

The diagnostic run is append-only under `logs/YYYYMMDD/HOST`. Raw evidence is
kept beside derived findings so an engineer can audit every conclusion.
