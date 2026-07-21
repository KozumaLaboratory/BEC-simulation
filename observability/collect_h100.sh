#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:08:00
#$ -N obs_collect
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
# Observability GPU-ratchet collector job (TSUBAME H100).
#
# COST-HACKED per the official 別表2 formula:
#   points = nodes × typeCoef × prioCoef × (0.7·max(actual_s,300) + 0.1·h_rt_s)/3600
#   - gpu_1 (coef 0.200, ONE full non-MIG H100, 8 cores) beats node_q (0.250) by 20%.
#     MIG is only node_o/gpu_h — gpu_1 profiles fully.
#   - h_rt=0:08:00 (480s): the 0.1·h_rt reserved term is tiny; margin over ~250-350s actual.
#   - actual is floored at 300s (max(actual,300)) → sub-5-min jobs cost the SAME, so we
#     pack 64³+96³+128³ into ONE job for free scaling data. Do NOT add f32 (10-min JIT).
#   => ~0.013 pt/job (half of node_q). At the 30-pt cap that is ~2000 jobs.
# Dispatch (login node, AFTER the 30-pt cap check in tsubame_points.sh):
#   qsub -g tga-kozuma-kouhi observability/collect_h100.sh
set -e
GRP=tga-kozuma-kouhi
export JULIA_DEPOT_PATH=/gs/fs/$GRP/shared/.julia
JULIA=/gs/fs/$GRP/shared/.juliaup/bin/julia
cd /gs/fs/$GRP/uk07267/BEC-opt
mkdir -p logs
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
echo "host=$(hostname) date=$(date) commit=$COMMIT"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader || true
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println(CUDA.name(CUDA.device()))'

# 300s-floor packing: all three sizes + the accuracy gates ride the same
# paid-for 300s window (all on the SAME H100 env as the measurement).
for NG in 64 96 128; do
  echo "=== collect ${NG}^3 f64 ==="
  GIT_COMMIT=$COMMIT $JULIA --project=. observability/collect_gpu.jl $NG f64 "$COMMIT"
done
echo "=== accuracy gates (GPU=CPU parity + norm) ==="
GIT_COMMIT=$COMMIT $JULIA --project=. observability/gates.jl || echo "GATES_RUN_FAILED"
echo "ALLDONE"
