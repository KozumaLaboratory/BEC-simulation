#!/usr/bin/env bash
# Re-run the EdH arms with dt and t_end in the output filename. The first pass
# tagged only (field, n), so the dt/2 convergence arm overwrote the dt arm's
# time series — the same collision class already fixed for the eGPE cells.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

run () {
  echo "=== $1 ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/h6_edh.jl\"); main(String[$2])"
  echo "--- $1 rc=$? ---"
}

run edh_30uG    '"n=64","Bz=0.030","t_end=20.0","dt=5.0e-4","save_every=200"'
run edh_15uG    '"n=64","Bz=0.015","t_end=20.0","dt=5.0e-4","save_every=200"'
run edh_30uG_dt '"n=64","Bz=0.030","t_end=4.0","dt=2.5e-4","save_every=40"'
echo ALL_DONE
