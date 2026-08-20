#!/bin/bash
# TSUBAME (UGE) submit: classify every trajectory endpoint under a directory tree.
#
#   qsub -g tga-kozuma-kouhi -N eu334_cls -v CL_ROOT=... scripts/eu334/submit_classify.sh
#
# Separate from `submit_nucleate.sh`, which classifies at the end of its own shard,
# for two reasons. A shard killed at its walltime banks its finished trajectories
# but never reaches its classify loop, so those endpoints would sit unread — which
# is what happened to the first ensemble wave. And the branch table can be refined
# after the fact; re-classifying then must not mean re-running the trajectories.
#
# Idempotent: a psi whose class CSV already exists is skipped, so this can be run
# repeatedly as trajectories land.
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=12:00:00
#$ -j y
#$ -o logs/tsubame/
source "${EU334_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu334}/scripts/eu334/_preamble.sh"
set +e

CL_ROOT="${CL_ROOT:-$EU334_OUT}"
CL_GRID="${CL_GRID:-64}"
CL_KAPPA="${CL_KAPPA:-1.8}"
CL_B="${CL_B:-20.0}"
CL_PIN="${CL_PIN:-0.002}"
CL_BIF="${CL_BIF:-$EU334_OUT/bifurcation_k${CL_KAPPA}_g${CL_GRID}}"

n=0; skipped=0; failed=0
for p in "$CL_ROOT"/*/psi_*.jld2; do
    [ -e "$p" ] || continue
    d=$(dirname "$p")
    tag=$(basename "$p" .jld2); tag=${tag#psi_}
    out="$d/class"
    if [ -f "$out/class_$tag.csv" ]; then skipped=$((skipped+1)); continue; fi
    CL_PSI="$p" CL_GRID="$CL_GRID" CL_KAPPA="$CL_KAPPA" CL_B="$CL_B" \
        CL_PIN="$CL_PIN" CL_BIF="$CL_BIF" CL_OUT="$out" \
        "$JULIA" --project=. scripts/eu334/classify.jl
    if [ $? -eq 0 ]; then n=$((n+1)); else echo "CLASSIFY FAILED: $p"; failed=$((failed+1)); fi
    flush=1
done

echo "=== classified $n, skipped $skipped, failed $failed $(date) ==="
[ "$failed" -eq 0 ] || exit 1
