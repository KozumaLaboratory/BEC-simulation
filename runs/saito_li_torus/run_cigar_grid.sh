#!/usr/bin/env bash
# Is the F=1 crossing really 23 % below the paper's 0.14 mG, or is the cigar
# branch under-resolved transversely?
#
# In the wide box (box_xy = 10 a_ho, n = 112) dx = 0.0893 a_ho against the
# cigar's sigma_x = 0.337 — only 3.8 points across its transverse width. The
# torus is comfortable (sigma_x = 0.475, 5.3 points, and its energy is
# unchanged to 6 digits between box_xy = 5 and 10), but the crossing is a
# DIFFERENCE of the two and the cigar is the poorly resolved one.
#
# The paper's own numerics run dx ~ 0.01 um = 0.013 a_ho, seven times finer.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

for n in 160 224; do
  echo "=== cigar transverse grid n=${n} (dx = $(python3 -c "print(f'{10.0/$n:.4f}')") a_ho), Bz = 0.120 mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/h3_cells.jl\"); main(String[\"C1@0.120\",\"n=${n}\",\"nz=224\",\"box_xy=10.0\",\"box_z=20.0\",\"iters=4000\"])"
  echo "--- rc=$? ---"
done
echo "=== torus at the finest, same box, for the difference ==="
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
  -e 'include("runs/saito_li_torus/h3_cells.jl"); main(String["T1@0.120","n=224","nz=224","box_xy=10.0","box_z=20.0","iters=4000"])'
echo "--- rc=$? ---"
echo ALL_DONE
