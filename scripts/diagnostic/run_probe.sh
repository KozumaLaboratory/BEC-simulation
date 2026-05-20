#!/bin/bash
set -e
cd /home/suzume/workspace/BEC-simulation
exec /home/suzume/.juliaup/bin/julia --project=. scripts/diagnostic/probe_jld2_structure.jl
