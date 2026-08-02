#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:30:00
#$ -N ratchet_n32
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# 32^3 is the one grid the GPU ratchet has never measured, and D1a's whole cost
# estimate rests on it: observability/best.json holds only N128 keys, and
# history.jsonl has 64/96/128 but no 32. Extrapolating by cells is not safe
# here — 64^3 already runs at only 83-85% device-busy, so a smaller grid is
# occupancy-limited and will NOT scale down linearly.
#
# 64^3 is re-run FIRST as a positive control. If this node does not reproduce
# the recorded 2.57-2.67 ms / 83-85% busy, then the 32^3 number cannot be
# compared against the existing table and the run is void. Same instrument,
# same workload, same session — that is what makes the two numbers comparable.
#
# gpu_1 is a MIG slice: it silently rejects h_rt=12h, so keep h_rt short.
set -u
export JULIA_DEPOT_PATH="$HOME/.julia"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-ddi-conv}"
COMMIT=$(git rev-parse --short HEAD)
echo "host=$(hostname) commit=$COMMIT date=$(date)"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>&1 | head -2
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -3

echo
echo "### ANCHOR — 64^3, must reproduce history.jsonl (2.57-2.67 ms, 83-85% busy)"
$JULIA --project=. observability/collect_gpu.jl 64 f64 "$COMMIT" 2>&1
anchor_rc=${PIPESTATUS[0]}
echo "### anchor rc=$anchor_rc"
if [ "$anchor_rc" -ne 0 ]; then
    echo "ANCHOR FAILED — a 32^3 number taken here would not be comparable"
    echo "ALL DONE $(date)"
    exit 1
fi

echo
echo "### TARGET — 32^3, never measured before"
$JULIA --project=. observability/collect_gpu.jl 32 f64 "$COMMIT" 2>&1
echo "### target rc=${PIPESTATUS[0]}"
echo "ALL DONE $(date)"
