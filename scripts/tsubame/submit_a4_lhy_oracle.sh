#!/bin/bash
#$ -cwd
#$ -l cpu_4=1
#$ -l h_rt=0:30:00
#$ -N a4_lhy
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# Lane A item A4 — the F=6 LHY oracle. CPU only (BdG diagonalisation, no time
# evolution). Gate G1 does not open until this is green, and every later GPU
# hour is wasted if it is red, so it is the first job of the campaign.
#
# Smoke runs inside the same job before production: a bench that dies after the
# queue wait has cost the wait for nothing, and filtering a log by form has
# eaten the explaining line before.
set -u
export JULIA_DEPOT_PATH="$HOME/.julia"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-ddi-conv}"
echo "host=$(hostname) commit=$(git rev-parse --short HEAD) date=$(date)"
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -3

echo "### SMOKE"
$JULIA --project=. bench/a4_lhy_closed_form_residual.jl smoke 2>&1
smoke_rc=${PIPESTATUS[0]}
echo "### smoke rc=$smoke_rc"
if [ "$smoke_rc" -ne 0 ]; then
    echo "SMOKE FAILED — not spending the production pass"
    echo "ALL DONE $(date)"
    exit 1
fi

echo
echo "### PRODUCTION"
$JULIA --project=. bench/a4_lhy_closed_form_residual.jl full 2>&1
echo "### production rc=${PIPESTATUS[0]}"
echo "ALL DONE $(date)"
