#!/bin/bash
# The euv3 evaporation with mu determined by the total, on the cluster.
#
#   qsub -g <group> -o <dir>/uge.log -v SBEC_MODE=full submit_eu_nc.sh
#
# SBEC_MODE: smoke (5% of the ramp), dtbox (the dt and box sweep), full.
#$ -cwd
#$ -N eunc
#$ -l cpu_16=1
#$ -l h_rt=6:00:00
#$ -j y
set -eu
PROOT=/gs/fs/tga-kozuma-kouhi/uk07267/spgpe_evap
OUT=/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu_number_conserving
mkdir -p "$OUT"
cd "$PROOT"
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export SPINORBEC_FIGS_ROOT="$OUT"
export JULIA_NUM_THREADS=4
MODE="${SBEC_MODE:-smoke}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "[eunc] host=$(hostname) mode=$MODE"
echo "[eunc] HEAD=$(git rev-parse --short HEAD) dirty=$(git status --porcelain | wc -l)"
[ "$(git status --porcelain | wc -l)" -eq 0 ] || {
    echo "[eunc] FAIL: dirty tree — sync with scripts/kz/sync_tsubame.sh"; exit 1; }
# Prove the dispatch runs before spending the reservation: same script, same mode
# machinery, 5% of the ramp. Three earlier KZ launches died on their first line
# because nothing executed the invocation before qsub took the node.
if [ "$MODE" != "smoke" ]; then
    echo "[eunc] smoking at 5% first"
    # Job id in the name. A shared _smoke.log is whichever run touched it last, so a
    # dead job's log reads as the live one's — which happened: a 17:33 failure was read
    # as the 18:19 run's output and reported as that run having died, while it was still
    # going and the failure had already been fixed. Same class as the provenance work in
    # this branch: an output that does not record what produced it cannot refuse to be
    # misread.
    SMOKE="$OUT/_smoke_${JOB_ID:-nojob}.log"
    timeout 3600 "$JULIA" --project=. scripts/kz/eu_number_conserving.jl smoke \
        > "$SMOKE" 2>&1 || {
        echo "[eunc] FAIL: the smoke could not run"; tail -25 "$SMOKE"; exit 1; }
    echo "[eunc] smoke OK"
fi
"$JULIA" --project=. scripts/kz/eu_number_conserving.jl "$MODE"
echo "[eunc] PASS"
