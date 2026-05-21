#!/bin/sh
set -e
cd /home/suzume/workspace/BEC-simulation
LOG=runs/eu151_matsui_edh/logs/t81_run.log
mkdir -p runs/eu151_matsui_edh/logs
echo "=== T81 run start: $(date -Iseconds) ===" | tee "$LOG"
LD_LIBRARY_PATH=/usr/lib/wsl/lib \
  /home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia \
  --project=/home/suzume/workspace/BEC-simulation \
  -e 'using CUDA, SpinorBEC; SpinorBEC.run_yaml("runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml"); println("OK_T81_run_yaml_complete")' \
  2>&1 | tee -a "$LOG"
echo "=== T81 run end: $(date -Iseconds) ===" | tee -a "$LOG"
