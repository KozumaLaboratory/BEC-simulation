#!/bin/bash
export LD_LIBRARY_PATH=/usr/lib/wsl/lib
exec /home/suzume/.juliaup/bin/julia --project=/home/suzume/workspace/BEC-simulation /home/suzume/workspace/BEC-simulation/runs/eu151_barnett_spin_cdd0/extract_trajectory.jl
