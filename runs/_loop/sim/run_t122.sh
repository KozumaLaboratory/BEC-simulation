#!/bin/sh
# T122 implementer runner — F=11 T:E_1 non-trivial-irrep verification
set -e
cd /home/suzume/workspace/BEC-simulation
/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia \
  --project=/home/suzume/workspace/BEC-simulation \
  /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl
