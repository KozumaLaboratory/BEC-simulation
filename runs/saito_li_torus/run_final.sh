#!/usr/bin/env bash
# Last queue.
#
#  1. Pin Fig. 3's two published numbers (crossing, torus upper critical) and
#     find the LOWER edge of the bistable window with a box long enough for the
#     low-field polarized branch.
#  2. Re-run the two F=1 EdH cells: they were measured with a `moment_axis`
#     that did not subtract the centre of mass, which corrupts the symmetry
#     axis and therefore the rotation angle. f_z, L_z and J_z are unaffected
#     (they are not computed from that tensor), but phi is.
#  3. Re-measure one F=6 EdH cell with the fixed instrument. Its eigenvalues
#     already matched the COM-subtracted ones from `h4_shape.jl` exactly, which
#     says the droplet was centred and phi was fine — but "already agreed with
#     a correct instrument" is an argument, and a rerun is a measurement.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

step () { echo; echo "=== $1 ==="; shift; "$@"; echo "--- rc=$? ---"; }
jl () { LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' -e "$1"; }

BOX='"n=56","nz=224","box_xy=5.0","box_z=20.0","iters=4000"'
LONG='"n=56","nz=448","box_xy=5.0","box_z=40.0","iters=4000"'

for mG in 0.110 0.120 0.130; do
  step "F=1 crossing Bz=${mG}" jl "include(\"runs/saito_li_torus/h3_cells.jl\"); main(String[\"T1@${mG}\",\"C1@${mG}\",${BOX}])"
done
for mG in 0.180 0.190; do
  step "F=1 torus upper Bz=${mG}" jl "include(\"runs/saito_li_torus/h3_cells.jl\"); main(String[\"T1@${mG}\",${BOX}])"
done
for mG in 0.020 0.030 0.050; do
  step "F=1 cigar lower edge, long box Bz=${mG}" jl "include(\"runs/saito_li_torus/h3_cells.jl\"); main(String[\"C1@${mG}\",${LONG}])"
done

for mG in 0.050 0.100; do
  step "F=1 EdH rerun Bz=${mG}" jl "include(\"runs/saito_li_torus/h6_edh.jl\"); main(String[\"cell=E1\",\"Bz=${mG}\",\"n=64\",\"box=4.0\",\"t_end=10.0\",\"dt=2.0e-4\",\"save_every=250\"])"
done

# 4. The J_z residual's last untested axis: the GRID.
#    dt is excluded (3.074e-3 -> 3.076e-3 on halving) and the box is largely
#    excluded (3.076e-3 -> 2.890e-3 for a 1.3x box, only -6 %, while `edge`
#    itself fell just 25 %). A cubic lattice breaks continuous rotational
#    symmetry, so the DDI's internal torque need not cancel exactly and J_z
#    need not be conserved to machine precision. Same box, finer grid.
step "EdH 30uG n=84 (grid test)" jl "include(\"runs/saito_li_torus/h6_edh.jl\"); main(String[\"Bz=0.030\",\"n=84\",\"box=6.5\",\"t_end=4.0\",\"dt=5.0e-4\",\"save_every=40\"])"

echo ALL_DONE
