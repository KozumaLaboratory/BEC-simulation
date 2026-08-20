#!/usr/bin/env bash
# The three items still open.
#
# 1. Fig. 4 at the paper's OWN cell, with the orientation fixed by EXACT
#    rotation of the converged z-axis state rather than by seeding along y and
#    hoping the zero mode holds. Gate passes at box = 8.0, n = 80:
#    edge 9.3e-5 (< 1e-4), axis exactly y_hat, J_z(0) = 1.6e-8,
#    corr(f_z, L_z) = -0.999999, and E(rotated) = E(z-axis) to 2.5e-7.
#
# 2. Fig. 5: extend the n_drop scan. 3, 5 and the single-vortex control all
#    land on one state; 4 and 6 land lower. The period is therefore NOT
#    determined by what a generic seed reaches, so keep scanning.
#
# 3. The EdH J_z residual. dt and grid are excluded outright; the box moved it
#    -6 % for a 1.31x enlargement. Double the box instead of nudging it.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out
step () { echo; echo "=== $1 ==="; shift; "$@"; echo "--- rc=$? ---"; }
jl () { LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' -e "$1"; }

for mG in 0.050 0.100; do
  step "F=1 EdH (rotated) Bz=${mG}" jl "include(\"runs/saito_li_torus/h6_edh.jl\"); main(String[\"cell=E1\",\"orient=rotate\",\"Bz=${mG}\",\"n=80\",\"box=8.0\",\"t_end=10.0\",\"dt=2.0e-4\",\"save_every=250\"])"
done

for nd in 7 8 9 10; do
  step "Fig.5 chain n_drop=${nd}" jl "include(\"runs/saito_li_torus/h9_supersolid.jl\"); main(String[\"seed=chain\",\"n_drop=${nd}\"])"
done

step "EdH J_z, box 13 (2x)" jl "include(\"runs/saito_li_torus/h6_edh.jl\"); main(String[\"Bz=0.030\",\"n=128\",\"box=13.0\",\"t_end=4.0\",\"dt=5.0e-4\",\"save_every=40\"])"

echo ALL_DONE
