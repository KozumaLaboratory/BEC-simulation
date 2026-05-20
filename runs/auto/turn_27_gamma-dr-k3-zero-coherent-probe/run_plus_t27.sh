#!/bin/sh
# T27 GPU run for stir_+0.5 noloss coherent probe
set -e
export LD_LIBRARY_PATH=/usr/lib/wsl/lib
cd /home/suzume/workspace/BEC-simulation
/home/suzume/.juliaup/bin/julia \
  --project=/home/suzume/workspace/BEC-simulation \
  /home/suzume/workspace/BEC-simulation/runs/eu151_barnett_spin_cdd0_noloss/run_plus.jl
