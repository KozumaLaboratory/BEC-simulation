#!/bin/bash
set -e
cd /home/suzume/workspace/BEC-simulation
LD_LIBRARY_PATH=/usr/lib/wsl/lib /home/suzume/.juliaup/bin/julia --project=. /home/suzume/workspace/BEC-simulation/runs/eu151_barnett_spin_cdd0/extract_trajectory.jl
