#!/bin/bash
set -e
cd /home/suzume/workspace/BEC-simulation
export LD_LIBRARY_PATH=/usr/lib/wsl/lib
exec /home/suzume/.juliaup/bin/julia --project=. runs/auto/turn_74_edh-matsui-execute-baseline-case-A/step_a_precondition.jl
