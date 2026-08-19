#!/usr/bin/env bash
# (a) COARSE arms as a positive control on the convergence scan itself.
#
# n=64 -> n=96 moved E/N by nothing at all (8 identical digits). That is either
# "converged" or "the scan is blind", and the two look the same. Coarse arms
# decide it: if E moves at n=40/48 and stops moving by n=64, the scan can
# resolve a difference and the null at 64->96 is a real convergence statement.
# A convergence scan that cannot fail certifies whatever it is handed --- the
# exact trap that made the sibling campaign's ITP answer look converged while
# being 44 % wrong.
#
# (b) BISTABILITY: torus and cigar converged independently at the same
# (F, N, eps_dd), compared by energy. One common box, sized for the cigar:
# it is prolate along z and the torus box (box_z = 3.5) put 5.7e-2 of the norm
# on the boundary in the smoke run.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

run () {
  echo "=== $1 ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
    -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/b_cells.jl\"); main(String[$2])"
  echo "--- $1 rc=$? ---"
}

run coarse '"T","n=40","nz=40","box_xy=6.5","box_z=3.5","iters=4000"'
run coarse '"T","n=48","nz=48","box_xy=6.5","box_z=3.5","iters=4000"'
run bistab '"T","C","n=64","nz=128","box_xy=6.5","box_z=8.0","iters=4000"'

echo ALL_DONE
