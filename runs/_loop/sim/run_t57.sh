#!/bin/bash
set -e
cd /home/suzume/workspace/BEC-simulation
exec /home/suzume/.juliaup/bin/julia --project=. scripts/diagnostic/klaus_bch_leak_verification.jl
