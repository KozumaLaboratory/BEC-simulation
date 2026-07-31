#!/bin/bash
#$ -cwd
#$ -l cpu_4=1
#$ -l h_rt=0:30:00
#$ -N lhy_stab
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
set -u
export JULIA_DEPOT_PATH="$HOME/.julia"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-ddi-conv}"
echo "host=$(hostname) commit=$(git rev-parse --short HEAD)"
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -3
echo "### SMOKE"
$JULIA --project=. bench/lhy_stability_scan.jl 3 2>&1
smoke_rc=${PIPESTATUS[0]}
echo "### smoke rc=$smoke_rc"
[ "$smoke_rc" -ne 0 ] && { echo "SMOKE FAILED"; echo "ALL DONE $(date)"; exit 1; }
echo; echo "### PRODUCTION"
$JULIA --project=. bench/lhy_stability_scan.jl 9 2>&1
echo "ALL DONE $(date)"
