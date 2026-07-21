# Troubleshooting

- `nvidia-smi failed`: verify the NVIDIA driver is loaded and the user can access
  `/dev/nvidia*`.
- `nvcc not found`: load a CUDA module or add the CUDA `bin` directory to PATH.
- install permission denied: configure passwordless sudo for the narrow install
  commands, preinstall gpu-burn, or pass `--gpu-burn /writable/path/gpu_burn`.
- kernel logs denied: run with appropriate privileges or grant journal access.
- SSH failure: verify key-based login; gpu-doctor deliberately uses BatchMode and
  never prompts for a password.

