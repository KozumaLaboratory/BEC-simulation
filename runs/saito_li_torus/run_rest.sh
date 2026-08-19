#!/usr/bin/env bash
# Everything still open, in one sequential queue (the GPU is shared).
#
#  1. Fig. 4 at the paper's OWN cell: F=1, N=15000, eps_dd=1.2, B_z = 0.05 and
#     0.1 mG — the two fields Fig. 4(b) plots. The F=6 EdH already in this
#     directory is an extrapolation; this one is a reproduction.
#  2. Fig. 5, the 1D supersolid. `n_drop` is SCANNED and the single-vortex
#     control is run, because "the ground state is periodic" is a statement
#     about which state is lower, not about what a seed relaxes to.
#  3. The EdH J_z residual: dt-independent, so the boundary is the suspect.
#     Enlarge the box until `edge` falls to the static cells' 1e-6 and see
#     whether max|J_z| follows.
#  4. main's 128^3 static cell, which was launched and killed.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

step () { echo; echo "=== $1 ==="; shift; "$@"; echo "--- rc=$? ---"; }
jl () { LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA' -e "$1"; }

# --- 1. Fig. 4 at F=1 -------------------------------------------------------
for mG in 0.050 0.100; do
  step "F=1 EdH Bz=${mG} mG" jl "include(\"runs/saito_li_torus/h6_edh.jl\"); main(String[\"cell=E1\",\"Bz=${mG}\",\"n=64\",\"box=4.0\",\"t_end=10.0\",\"dt=2.0e-4\",\"save_every=250\"])"
done

# --- 2. Fig. 5 supersolid ---------------------------------------------------
for nd in 3 4 5 6; do
  step "Fig.5 chain n_drop=${nd}" jl "include(\"runs/saito_li_torus/h9_supersolid.jl\"); main(String[\"seed=chain\",\"n_drop=${nd}\"])"
done
step "Fig.5 single-vortex control" jl "include(\"runs/saito_li_torus/h9_supersolid.jl\"); main(String[\"seed=single\"])"

# --- 3. J_z residual: is it the boundary? -----------------------------------
step "EdH 30uG box 8.5 (edge test)" jl "include(\"runs/saito_li_torus/h6_edh.jl\"); main(String[\"Bz=0.030\",\"n=84\",\"box=8.5\",\"t_end=4.0\",\"dt=5.0e-4\",\"save_every=40\"])"

# --- 4. main's missing 128^3 static cell ------------------------------------
step "128^3 static cell" jl "using SpinorBEC; run_yaml(\"runs/saito_li_torus/config.yaml\")"

echo ALL_DONE
