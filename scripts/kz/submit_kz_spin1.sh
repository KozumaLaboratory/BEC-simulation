#!/bin/bash
# Step 1 of the spinor ladder: c1 != 0, three components, on the toroidal protocol
# where beta reproduced at 0.6 sigma (number-damping) and 0.05 sigma (full).
#
# WHICH winding is fitted is a parameter, because it is the question. One
# trajectory at tau_Q = 1000 gave per_m = [+1, -1, 0], mass = 0, spin = -1 for the
# SAME field: read the mass winding and there is no defect, read the spin winding
# and there is one. So all three get their own scan and the answer is measured.
#
#   qsub -g <group> -o <dir>/uge.log \
#        -v SBEC_W=mass|spin|m,SBEC_C1=-0.00007,SBEC_MD=nd,SBEC_NTRAJ=320 \
#        submit_kz_spin1.sh
#$ -cwd
#$ -N kzspin1
#$ -l cpu_16=1
#$ -l h_rt=20:00:00
#$ -j y
set -eu
PROOT=/gs/fs/tga-kozuma-kouhi/uk07267/spgpe_evap
OUT=/gs/fs/tga-kozuma-kouhi/uk07267/runs/kz_toroidal
cd "$PROOT"
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export SPINORBEC_FIGS_ROOT="$OUT"
export JULIA_NUM_THREADS=1
W="${SBEC_W:-spin}"; C1="${SBEC_C1:--0.00007}"; MD="${SBEC_MD:-nd}"
NTRAJ="${SBEC_NTRAJ:-320}"; NSHARD=16
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "[kzspin1] host=$(hostname) W=$W c1=$C1 md=$MD ntraj=$NTRAJ"
echo "[kzspin1] HEAD=$(git rev-parse --short HEAD) dirty=$(git status --porcelain | wc -l)"
if [ "$(git status --porcelain | wc -l)" -ne 0 ]; then
    echo "[kzspin1] FAIL: dirty tree — sync with scripts/kz/sync_tsubame.sh"
    git status --porcelain | head -10
    exit 1
fi
# Smoke the REAL dispatch before reserving the node: one trajectory, one rate, the
# same mode string modulo n_traj. If the branch does not exist, or its regex rejects
# the arguments, or a kwarg is missing, this fails here in a minute instead of after
# a 20-hour reservation — which is what happened three times, 144 shards, because
# the spin1 branch had never been added and nothing executed it to find out.
#
# It must be the dispatch itself. The previous guard kept its own table of regexes
# and answered OK for a mode with no implementation behind it: a check written in a
# different vocabulary from the thing it checks cannot see that thing missing.
SMOKE_MODE="spin11of${NSHARD}:${C1}:${MD}:1:${W}"
echo "[kzspin1] smoking the dispatch: $SMOKE_MODE"
if ! SPINORBEC_FIGS_ROOT="$OUT/_smoke" timeout 3600 "$JULIA" --project=. \
        docs/guides/figures/kz_toroidal_winding.jl "$SMOKE_MODE" > "$OUT/_smoke.log" 2>&1; then
    echo "[kzspin1] FAIL: the dispatch could not run $SMOKE_MODE"
    tail -25 "$OUT/_smoke.log"
    exit 1
fi
echo "[kzspin1] dispatch OK"

pids=""
for i in $(seq 1 $NSHARD); do
    "$JULIA" --project=. docs/guides/figures/kz_toroidal_winding.jl \
        "spin1${i}of${NSHARD}:${C1}:${MD}:${NTRAJ}:${W}" \
        > "$OUT/spin1_${W}_${MD}_${i}.log" 2>&1 &
    pids="$pids $!"
done
fail=0
for p in $pids; do wait "$p" || fail=$((fail+1)); done
echo "[kzspin1] shards done, failures=$fail"
[ "$fail" -eq 0 ] || { echo "[kzspin1] FAIL"; exit 1; }
echo "[kzspin1] PASS"
