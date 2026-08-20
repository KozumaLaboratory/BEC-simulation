#!/usr/bin/env bash
# Pin the two numbers Fig. 3 publishes, now that the coarse ladder brackets both.
#
#   crossing        measured in (0.100, 0.140) mG   paper: 0.14 mG
#   torus dies      measured in (0.170, 0.200) mG   paper: ~0.17 mG
#
# The cigar branch's low-field cells (0.02, 0.05 mG) failed the box gate at
# box_z = 20 a_ho — the polarized branch elongates as the field falls, the same
# pattern that needed three box doublings at F=6. Re-run those two at
# box_z = 40 to find the LOWER edge of the bistable window (paper: 0.03 mG).
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

BOX='"n=56","nz=224","box_xy=5.0","box_z=20.0","iters=4000"'
LONG='"n=56","nz=448","box_xy=5.0","box_z=40.0","iters=4000"'

for mG in 0.110 0.120 0.130; do
  echo "=== crossing: Bz = ${mG} mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/h3_cells.jl\"); main(String[\"T1@${mG}\",\"C1@${mG}\",${BOX}])"
  echo "--- rc=$? ---"
done

for mG in 0.180 0.190; do
  echo "=== torus upper critical: Bz = ${mG} mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/h3_cells.jl\"); main(String[\"T1@${mG}\",${BOX}])"
  echo "--- rc=$? ---"
done

for mG in 0.020 0.030 0.050; do
  echo "=== cigar lower edge, long box: Bz = ${mG} mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/h3_cells.jl\"); main(String[\"C1@${mG}\",${LONG}])"
  echo "--- rc=$? ---"
done
echo ALL_DONE
