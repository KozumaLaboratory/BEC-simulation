#!/usr/bin/env bash
# The energy crossing, predicted from the two box-converged branches and then
# checked directly.
#
# Both branches are nearly fully polarised or nearly unmagnetised, so their
# field dependence is simple and was fitted to the measured, box-converged
# points:
#   E_torus(B) = -1.575563 - 3.16e-5 B^2   (B in uG; reproduces 10/30/50 uG
#                                           to 4 digits)
#   E_cigar(B) = -0.12790  - 0.0881  B     (Zeeman of a fully polarised state,
#                                           <f_z> = -5.955 essentially constant)
# => crossing at B = 16.5 uG.
#
# Run both seeds at 16 uG to check it. The cigar needs box_z = 32 (half-box
# 8.0 = 2.3 sigma_z was not enough; 16.0 = 4.6 sigma_z passes the gate at
# 3.9e-5). The torus is box-converged already: its energy is identical to 6
# digits in box_z = 8 and 16, so it runs in the cheap box.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

echo "=== cigar branch at 16 uG, box_z = 32 ==="
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
  -e 'include("runs/saito_li_torus/b_cells.jl"); main(String["C@0.016","n=64","nz=384","box_xy=6.5","box_z=32.0","iters=4000"])'
echo "--- rc=$? ---"

echo "=== torus branch at 16 uG, box_z = 8 ==="
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
  -e 'include("runs/saito_li_torus/b_cells.jl"); main(String["T@0.016","n=64","nz=128","box_xy=6.5","box_z=8.0","iters=4000"])'
echo "--- rc=$? ---"
echo ALL_DONE
