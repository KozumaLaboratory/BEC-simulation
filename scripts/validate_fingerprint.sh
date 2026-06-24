#!/usr/bin/env bash
# Thorough validation of phase_fingerprint.jl: run every known-structure state and
# tabulate the discriminating invariants, so we can see which parameters recover
# the known phase (keep those; drop the ones that don't).
set -e
JULIA=/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
cd "$(dirname "$0")/.."
G=${FP_GRID:-40}
STATES="polar cyclic biaxial_nematic m_plus_F spin_helix fl_vortex polar_core_vortex chiral_spin_vortex skyrmion axial_spin_texture"
for s in $STATES; do
  echo "########## $s ##########"
  FP_STATE=$s FP_GRID=$G $JULIA --project=. scripts/phase_fingerprint.jl 2>&1 \
    | grep -vE "Warning|@ |Info:|Precompil|✓|dependencies" || echo "  (FAILED)"
  echo ""
done
