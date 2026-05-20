#!/bin/bash
export LD_LIBRARY_PATH=/usr/lib/wsl/lib
/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia \
    --project=/home/suzume/workspace/BEC-simulation \
    /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/run_t33.jl \
    > /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/run_t33.log 2>&1
echo "Exit code: $?" >> /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/run_t33.log
