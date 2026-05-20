#!/bin/sh
# T57 analysis runner — calls julia with full path as in other run scripts
set -e
cd /home/suzume/workspace/BEC-simulation
/home/suzume/.juliaup/bin/julia \
  --project=/home/suzume/workspace/BEC-simulation \
  /home/suzume/workspace/BEC-simulation/scripts/diagnostic/klaus_bch_leak_verification.jl
