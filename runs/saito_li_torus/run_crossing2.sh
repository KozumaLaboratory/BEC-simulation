#!/usr/bin/env bash
# Demonstrate the crossing by the SIGN FLIP rather than by interpolation.
# Measured, both branches box-converged:
#   16 uG : torus -1.583638  cigar -1.539958   -> torus lower by 0.0437
#   30 uG : torus -1.604089  cigar -2.772653   -> cigar lower by 1.1686
# The two fits put the crossing at 16.50 uG, so 18 uG must already favour the
# cigar. If it does not, the fit is wrong and the interpolation was not a
# measurement.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

echo "=== cigar at 18 uG, box_z = 32 ==="
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
  -e 'include("runs/saito_li_torus/b_cells.jl"); main(String["C@0.018","n=64","nz=384","box_xy=6.5","box_z=32.0","iters=4000"])'
echo "--- rc=$? ---"

echo "=== torus at 18 uG, box_z = 8 ==="
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
  -e 'include("runs/saito_li_torus/b_cells.jl"); main(String["T@0.018","n=64","nz=128","box_xy=6.5","box_z=8.0","iters=4000"])'
echo "--- rc=$? ---"
echo ALL_DONE
