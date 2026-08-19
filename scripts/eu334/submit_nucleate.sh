#!/bin/bash
# TSUBAME (UGE) submit: one (T, rate) CELL of the #334 ensemble — every seed in
# the cell, then the classification of each endpoint.
#
#   qsub -g tga-kozuma-kouhi -N nu_T5_t200 -l h_rt=24:00:00 \
#     -v NU_T=5.0,NU_TAU_MS=200,NU_SEEDS_N=20,NU_SEED_FILE=... \
#     scripts/eu334/submit_nucleate.sh
#
# One job per cell rather than one per trajectory: the seeds inside a cell share
# the JIT cascade, which is minutes and would otherwise be paid 20 times. A cell
# is also the unit the binomial error is quoted over, so a killed job costs one
# error bar rather than a hole in the middle of one.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=24:00:00
#$ -j y
#$ -o logs/tsubame/
source "${EU334_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu334}/scripts/eu334/_preamble.sh"

export NU_KAPPA="${NU_KAPPA:-1.8}"
export NU_B="${NU_B:-20.0}"
export NU_GRID="${NU_GRID:-64}"
export NU_BOX="${NU_BOX:-24.0}"
export NU_PIN="${NU_PIN:-0.002}"
export NU_T="${NU_T:-5.0}"
export NU_NT="${NU_NT:-1.0}"
export NU_DT="${NU_DT:-0.002}"
export NU_EVERY="${NU_EVERY:-5}"
export NU_TAU_MS="${NU_TAU_MS:-200.0}"
export NU_HOLD_MS="${NU_HOLD_MS:-0.0}"
export NU_FRAMES="${NU_FRAMES:-200}"
export NU_OUT="${NU_OUT:-$EU334_OUT/nucleate_k${NU_KAPPA}_T${NU_T}_tau${NU_TAU_MS}}"
SEEDS_N="${NU_SEEDS_N:-20}"
SEED0="${NU_SEED0:-1}"
: "${NU_SEED_FILE:?NU_SEED_FILE is required — the bifurcation cell to grow from}"
export NU_SEED_FILE
[ -n "${NU_MU0:-}" ] && export NU_MU0
[ -n "${NU_MU1:-}" ] && export NU_MU1
[ -n "${NU_NOISE:-}" ] && export NU_NOISE

echo "=== nucleate κ=$NU_KAPPA T=$NU_T τ=$NU_TAU_MS ms, seeds $SEED0..$((SEED0+SEEDS_N-1)) ==="
mkdir -p "$NU_OUT"

fails=0
for i in $(seq 0 $((SEEDS_N-1))); do
    s=$((SEED0+i))
    tag=$(printf "k%.1f_T%.1f_tau%.0f_seed%03d" "$NU_KAPPA" "$NU_T" "$NU_TAU_MS" "$s")
    if [ -f "$NU_OUT/psi_$tag.jld2" ]; then
        echo "--- seed $s: already present, skipping"
        continue
    fi
    echo "--- seed $s"
    if NU_SEED=$s "$JULIA" --project=. scripts/eu334/nucleate.jl; then
        :
    else
        echo "SEED $s FAILED (rc=$?)"; fails=$((fails+1))
    fi
done

# Classification is a separate driver so it can be re-run when the branch table
# is refined without repeating the trajectories.
echo "=== classifying $NU_OUT ==="
for p in "$NU_OUT"/psi_*.jld2; do
    [ -e "$p" ] || continue
    CL_PSI="$p" CL_GRID="$NU_GRID" CL_KAPPA="$NU_KAPPA" CL_B="$NU_B" CL_PIN="$NU_PIN" \
        CL_BIF="${CL_BIF:-$EU334_OUT/bifurcation_k${NU_KAPPA}_g${NU_GRID}}" \
        CL_OUT="${CL_OUT:-$NU_OUT/class}" \
        "$JULIA" --project=. scripts/eu334/classify.jl || {
            echo "CLASSIFY FAILED for $p"; fails=$((fails+1)); }
done

echo "=== cell summary: $fails failure(s) $(date) ==="
[ "$fails" -eq 0 ] || exit 1
