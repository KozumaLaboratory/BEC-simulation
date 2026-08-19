#!/usr/bin/env bash
# Field ladder for #336: at each B_z, converge BOTH seeds and name the two
# states by energy — the discipline #335 settled on, not "whichever basin the
# relaxation happened to find".
#
# At B_z = 0 there is no bistability: the cigar seed relaxes into a magnetic
# vortex with the same second-moment eigenvalues and the opposite circulation
# (d_shape.jl), so the paper's Fig. 3(b) statement that the cigar "becomes
# unstable below some critical magnetic field" holds at F = 6 too.
#
# FIELD SCALE, predicted before scanning (CLAUDE.md gate 2). The torus is held
# together against polarization by the azimuthal spin-winding cost
# <S_z^2>/r^2 = (F/2)/(lam sigma_r^2) = 2.44 hbar w_ref per atom. A z-polarized
# state gains |p| F from the Zeeman term, and p = -g_F mu_B B/(hbar w_ref) is
# -0.0148 per uG for Eu F=6 at w_ref = 2 pi 110 Hz. Equality at |p| F = 2.44
# gives B ~ 27 uG. So the ladder brackets that: 3, 10, 30, 100 uG.
#
# This is a PREDICTION for F = 6, not a reproduction: the paper's Fig. 3 is
# F = 1, N = 50000, where it finds bistability over 0.03-0.17 mG.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

# common box, sized for the prolate branch (box_z = 8 a_ho)
BOX='"n=64","nz=128","box_xy=6.5","box_z=8.0","iters=4000"'

for mG in 0.003 0.010 0.030 0.100; do
  echo "=== Bz = ${mG} mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
    -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/b_cells.jl\"); main(String[\"T@${mG}\",\"C@${mG}\",${BOX}])"
  echo "--- Bz=${mG} rc=$? ---"
done
echo ALL_DONE
