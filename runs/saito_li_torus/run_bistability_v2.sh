#!/usr/bin/env bash
# Second attempt at the bistability arm, after the first one's cigar branch
# failed its own box gate (edge fraction 4.2e-1 / 8.3e-3 / 1.5e-2 against
# 1.2e-6 for every torus cell).
#
# The z-polarized branch is prolate and needs a long box: box_z = 16 a_ho
# (half-box 8.0) against the sigma_z = 2.19 a_ho it showed at 30 uG, i.e. 3.7
# sigma instead of the 1.8 sigma it had. Both seeds are run in that ONE box so
# the energies are comparable, and the torus is re-run there too rather than
# compared across boxes.
#
# Also brackets the torus branch's upper critical field: at 30 uG the torus is
# intact (edge 1.6e-6, circulation +0.9997) and at 100 uG the torus SEED comes
# out prolate and unbound. 50 and 70 uG run in the torus's own (adequate,
# cheap) box.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

LONG='"n=64","nz=192","box_xy=6.5","box_z=16.0","iters=4000"'
SHORT='"n=64","nz=64","box_xy=6.5","box_z=3.5","iters=4000"'

for mG in 0.030 0.010; do
  echo "=== both branches, long box: Bz = ${mG} mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/b_cells.jl\"); main(String[\"C@${mG}\",\"T@${mG}\",${LONG}])"
  echo "--- rc=$? ---"
done

for mG in 0.050 0.070; do
  echo "=== torus upper critical: Bz = ${mG} mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/b_cells.jl\"); main(String[\"T@${mG}\",${SHORT}])"
  echo "--- rc=$? ---"
done
echo ALL_DONE
