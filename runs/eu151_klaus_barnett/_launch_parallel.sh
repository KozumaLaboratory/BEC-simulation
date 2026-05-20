#!/usr/bin/env bash
# Parallel launcher: ±φ pair, 2 GPU workers (each ~7h based on klaus_phi
# batch-2 timing). Loss block makes per-step cost slightly higher than
# klaus_phi (one extra apply_loss_step! per Y4 macro step).
#
# Generates sub-configs first via _gen_subconfigs.py, then xargs -P 2
# fans out. Each worker streams its own log to logs/.
#
# Usage:
#   bash runs/eu151_klaus_barnett/_launch_parallel.sh

set -euo pipefail
cd "$(dirname "$0")/../.."

mkdir -p logs

python3 runs/eu151_klaus_barnett/_gen_subconfigs.py

PHI_LIST="+4.524 -4.524"

echo "[$(date +%H:%M:%S)] launching Barnett ±φ pair (2 parallel workers)..."
echo "$PHI_LIST" | tr ' ' '\n' | xargs -n 1 -P 2 -I {} bash -c '
  PHI={}
  echo "[$(date +%H:%M:%S)] starting phi=$PHI" >> logs/eu151_klaus_barnett_par.log
  LD_LIBRARY_PATH=/usr/lib/wsl/lib /home/suzume/.juliaup/bin/julia --project=. -e "
    import CUDA
    using SpinorBEC
    using Dates
    @async while true; flush(stdout); flush(stderr); sleep(15); end
    println(\"[\$(now())] phi=$PHI start\")
    flush(stdout)
    t0 = time()
    run_yaml(\"runs/eu151_klaus_barnett/phi_$PHI/config.yaml\"; base_dir=\"runs\", verbose=true)
    println(\"[\$(now())] phi=$PHI done in \$(round((time()-t0)/60; digits=2)) min\")
  " > logs/eu151_klaus_barnett_phi_$PHI.log 2>&1
  echo "[$(date +%H:%M:%S)] finished phi=$PHI" >> logs/eu151_klaus_barnett_par.log
'
echo "[$(date +%H:%M:%S)] all workers finished."
