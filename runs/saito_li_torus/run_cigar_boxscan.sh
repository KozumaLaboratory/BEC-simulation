#!/usr/bin/env bash
# Decide the polarized (cigar) branch by a BOX SCAN, which is the measurement
# that separates "long filament whose tail the box is clipping" from "unbound".
#
# So far, at Bz = 30 uG:
#   box_z =  8 a_ho (half 4.0):  sigma_z = 2.19, edge 8.3e-3, E/N = -1.9726
#   box_z = 16 a_ho (half 8.0):  sigma_z = 3.43, edge 1.3e-3, E/N = -2.7745
# sigma_z grew 1.57x for a 2x box --- SUB-linear, so it is not free expansion,
# but the half-box is only 2.3 sigma_z and the Gaussian tail there is ~5e-3 of
# peak, which is exactly the edge fraction seen. A self-bound filament needs
# half-box >~ 4 sigma_z, i.e. box_z ~ 28-32.
#
# If sigma_z and E/N stop moving at box_z = 32, the branch is real and its
# energy can be compared with the torus. If they keep growing, it is unbound
# and there is no cigar at these parameters.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

echo "=== cigar branch, box_z = 32 a_ho, Bz = 30 uG ==="
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' \
  -e 'include("runs/saito_li_torus/h3_cells.jl"); main(String["C@0.030","n=64","nz=384","box_xy=6.5","box_z=32.0","iters=4000"])'
echo "--- rc=$? ---"
echo ALL_DONE
