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
# Validate the mode string BEFORE reserving the node's time. 48 shards once died
# on the first line because c1 was passed as -6.4e-5 and the parser accepted only
# [0-9.], and the 20-hour reservations were already made.
MODE_PROBE="spin11of::::"
if ! "" --project=. docs/guides/figures/kz_toroidal_winding.jl --check-mode ""; then
    echo "[kzspin1] FAIL: mode string rejected: "
    exit 1
fi

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
