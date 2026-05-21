#!/bin/sh
set -e
cd /home/suzume/workspace/BEC-simulation
LOG=runs/eu151_matsui_edh/logs/t82_analyze.log
mkdir -p runs/eu151_matsui_edh/logs
echo "=== T82 analyze start: $(date -Iseconds) ===" | tee "$LOG"
LD_LIBRARY_PATH=/usr/lib/wsl/lib   /home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia   --project=/home/suzume/workspace/BEC-simulation   scripts/diagnostic/matsui_edh_t82_analyze.jl   2>&1 | tee -a "$LOG"
echo "=== T82 analyze end: $(date -Iseconds) ===" | tee -a "$LOG"
