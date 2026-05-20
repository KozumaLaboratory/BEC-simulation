#!/usr/bin/env bash
# Weak-Bz Barnett launcher: ±Ω = ±0.5 pair, 2 GPU workers parallel.
#
# Setup: K3_long-level Bz (2.6 nT, non-secular regime) + Klaus-style
# rotating B + DDI + K3 + γ_dr loss. Spinor path, 32³ grid, 30 ω⁻¹.
# Estimated ~1-2h per worker.
#
# Usage:
#   bash runs/eu151_barnett_spin/_launch_parallel.sh

set -euo pipefail
cd "$(dirname "$0")/../.."

mkdir -p logs

python3 runs/eu151_barnett_spin/_gen_subconfigs.py

TAG_LIST="+0.5 -0.5"

echo "[$(date +%H:%M:%S)] launching weak-Bz Barnett ±Ω pair..."
echo "$TAG_LIST" | tr ' ' '\n' | xargs -n 1 -P 2 -I {} bash -c '
  TAG={}
  echo "[$(date +%H:%M:%S)] starting stir_$TAG" >> logs/eu151_barnett_spin_par.log
  LD_LIBRARY_PATH=/usr/lib/wsl/lib /home/suzume/.juliaup/bin/julia --project=. -e "
    import CUDA
    using SpinorBEC
    using Dates
    @async while true; flush(stdout); flush(stderr); sleep(15); end
    println(\"[\$(now())] stir_$TAG start\")
    flush(stdout)
    t0 = time()
    run_yaml(\"runs/eu151_barnett_spin/stir_$TAG/config.yaml\"; base_dir=\"runs\", verbose=true)
    println(\"[\$(now())] stir_$TAG done in \$(round((time()-t0)/60; digits=2)) min\")
  " > logs/eu151_barnett_spin_stir_$TAG.log 2>&1
  echo "[$(date +%H:%M:%S)] finished stir_$TAG" >> logs/eu151_barnett_spin_par.log
'
echo "[$(date +%H:%M:%S)] all workers finished."
