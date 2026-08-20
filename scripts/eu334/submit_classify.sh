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
CL_B="${CL_B:-20.0}"
CL_PIN="${CL_PIN:-0.002}"

# kappa is derived PER FILE from the psi's own name, not taken as one value for
# the whole sweep.
#
# It used to be `CL_KAPPA=${CL_KAPPA:-1.8}` applied to every directory under
# CL_ROOT. The kappa = 0.9 control therefore got classified against the kappa =
# 1.8 branch table AND relaxed in a kappa = 1.8 trap: its `fperp_relaxed` = 4.59
# was computed in the wrong Hamiltonian. The rows came back `above_table` (f =
# 0.575 against that table's 0.521 ceiling) so the wrong number was never read as
# a verdict — the refusal masked the defect rather than catching it, and a control
# that runs to a slightly lower f would have published it.
#
# Every psi in this campaign carries kappa in its filename (126/126 checked), so
# this is total rather than a heuristic with a fallback. Refusing on a name that
# does not match is the point: a default here is how the wrong trap got used.

n=0; skipped=0; failed=0
for p in "$CL_ROOT"/*/psi_*.jld2; do
    [ -e "$p" ] || continue
    d=$(dirname "$p")
    tag=$(basename "$p" .jld2); tag=${tag#psi_}
    out="$d/class"
    if [ -f "$out/class_$tag.csv" ]; then skipped=$((skipped+1)); continue; fi
    k=$(basename "$p" | sed -n 's/^psi_k\([0-9][0-9.]*\)_.*/\1/p')
    if [ -z "$k" ]; then
        echo "NO KAPPA IN NAME, refusing to guess: $p" >&2
        failed=$((failed+1)); continue
    fi
    bif="$EU334_OUT/bifurcation_k${k}_g${CL_GRID}"
    if [ ! -f "$bif/flower_down.csv" ]; then
        echo "NO BRANCH TABLE for kappa=$k at ${CL_GRID}^3 ($bif): $p" >&2
        failed=$((failed+1)); continue
    fi
    CL_PSI="$p" CL_GRID="$CL_GRID" CL_KAPPA="$k" CL_B="$CL_B" \
        CL_PIN="$CL_PIN" CL_BIF="$bif" CL_OUT="$out" \
        "$JULIA" --project=. scripts/eu334/classify.jl
    if [ $? -eq 0 ]; then n=$((n+1)); else echo "CLASSIFY FAILED: $p"; failed=$((failed+1)); fi
    flush=1
done

echo "=== classified $n, skipped $skipped, failed $failed $(date) ==="
[ "$failed" -eq 0 ] || exit 1
