#!/usr/bin/env bash
# The cigar branch's box gate failed on the WRONG AXIS, and doubling box_z
# proved it: E_solver was unchanged to 9 significant figures (-2.07667649 at
# both box_z = 20 and 40) while `edge` stayed at exactly 4.864e-4. An energy
# that does not move and an edge that does not move mean the extra length was
# empty and the boundary occupation is somewhere else — the only axis left is
# xy, which was never widened because the object is prolate along z and that
# is what I looked at.
#
# sigma_x = 0.46 a_ho against a 2.5 a_ho half-box is 5.4 sigma, where a
# Gaussian is ~1e-13, so the 4.9e-4 is a broad low-density halo, not the core.
#
# This matters for the crossing: it sits at 0.112 mG against the paper's
# 0.14 mG, and it is the difference of two energies of which the cigar's is
# the one whose box is in question.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out
WIDE='"n=112","nz=224","box_xy=10.0","box_z=20.0","iters=4000"'

for mG in 0.020 0.110 0.120 0.140; do
  echo "=== cigar WIDE box_xy=10, Bz = ${mG} mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/h3_cells.jl\"); main(String[\"C1@${mG}\",${WIDE}])"
  echo "--- rc=$? ---"
done
# and the torus at the same two fields in the same wide box, so the crossing is
# a difference of two energies computed in ONE box
for mG in 0.110 0.120; do
  echo "=== torus WIDE box_xy=10, Bz = ${mG} mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/h3_cells.jl\"); main(String[\"T1@${mG}\",${WIDE}])"
  echo "--- rc=$? ---"
done


# The F=1 EdH cell failed three of its own checks at box = 4.0: edge 4.6e-4
# (above the 1e-4 gate), GS grad_norm 7e-3, and the symmetry axis relaxing to
# z instead of the y the protocol requires — at B=0 every orientation is
# degenerate, so a soft, under-converged GS is free to rotate. Retry in a box
# that passes, with more iterations.
for mG in 0.050 0.100; do
  echo "=== F=1 EdH retry box=6.0, Bz = ${mG} mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/h6_edh.jl\"); main(String[\"cell=E1\",\"Bz=${mG}\",\"n=96\",\"box=6.0\",\"t_end=10.0\",\"dt=2.0e-4\",\"save_every=250\"])"
  echo "--- rc=$? ---"
done
echo ALL_DONE
