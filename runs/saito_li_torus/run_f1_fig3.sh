#!/usr/bin/env bash
# Fig. 3 at the paper's OWN parameters: F = 1, N = 50000, eps_dd = 1.2.
#
# This is the cell the paper actually publishes a field axis for, so unlike the
# F=6 ladder in this directory it is a REPRODUCTION, with numbers to hit:
#
#     Fig. 3(b)  bistable region                B_z ~ 0.03 ... 0.17 mG
#     Fig. 3(c)  energies of the two branches cross at  B_z ~ 0.14 mG
#
# Sizing from h8_f1_sizing.jl: sigma_r = 0.500 a_ho, box_xy >= 3.57 a_ho.
# One COMMON box for both branches, long in z because the polarized branch is
# prolate and the F=6 work needed three box doublings before its energy stopped
# moving. box_z = 20 a_ho at nz = 224 gives dz = 0.089 a_ho against the torus's
# sigma_z = 0.409.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

BOX='"n=56","nz=224","box_xy=5.0","box_z=20.0","iters=4000"'

for mG in 0.020 0.050 0.100 0.140 0.170 0.200; do
  echo "=== F=1 Fig.3  Bz = ${mG} mG ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/h3_cells.jl\"); main(String[\"T1@${mG}\",\"C1@${mG}\",${BOX}])"
  echo "--- Bz=${mG} rc=$? ---"
done
echo ALL_DONE
