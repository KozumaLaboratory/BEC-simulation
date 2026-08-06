#!/bin/bash
# Run one mode of kz_toroidal_winding.jl on the cluster, single process.
#
# Every measurement belongs here rather than on the workstation, and the two this
# was written for are real measurements and not smokes: how large dt can be before
# sigma(W) moves (cost is linear in 1/dt, and the convergence sweep only ever tried
# SMALLER), and whether common random numbers across tau_Q shrink the error on beta
# (beta is a slope, so the correlation between points matters more than the error on
# each).
#
#   qsub -g <group> -o <dir>/uge.log -v SBEC_MODE=dtpush submit_kz_mode.sh
#$ -cwd
#$ -N kzmode
#$ -l cpu_16=1
#$ -l h_rt=20:00:00
#$ -j y
set -eu
PROOT=/gs/fs/tga-kozuma-kouhi/uk07267/spgpe_evap
OUT=/gs/fs/tga-kozuma-kouhi/uk07267/runs/kz_toroidal
cd "$PROOT"
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export SPINORBEC_FIGS_ROOT="$OUT"
export JULIA_NUM_THREADS=4
MODE="${SBEC_MODE:?set SBEC_MODE}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "[kzmode] host=$(hostname) mode=$MODE"
echo "[kzmode] HEAD=$(git rev-parse --short HEAD) dirty=$(git status --porcelain | wc -l)"
[ "$(git status --porcelain | wc -l)" -eq 0 ] || {
    echo "[kzmode] FAIL: dirty tree — sync with scripts/kz/sync_tsubame.sh"; exit 1; }
# One rate first, to prove the branch runs before spending the reservation. Same
# branch, same parsing; only the rate list is shorter, and that is declared.
echo "[kzmode] smoking $MODE at one rate"
SBEC_MAX_RATES=1 SPINORBEC_FIGS_ROOT="$OUT/_smoke" timeout 2400 "$JULIA" --project=. \
    docs/guides/figures/kz_toroidal_winding.jl "$MODE" > "$OUT/_smoke_$MODE.log" 2>&1 || {
    echo "[kzmode] FAIL: the dispatch could not run $MODE"
    tail -25 "$OUT/_smoke_$MODE.log"; exit 1; }
echo "[kzmode] dispatch OK"
"$JULIA" --project=. docs/guides/figures/kz_toroidal_winding.jl "$MODE"
echo "[kzmode] PASS"
