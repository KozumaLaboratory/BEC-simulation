#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:15:00
#$ -N vec_measure
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
set -e
GRP=tga-kozuma-kouhi
export JULIA_DEPOT_PATH=/gs/fs/$GRP/shared/.julia
JULIA=/gs/fs/$GRP/shared/.juliaup/bin/julia
cd /gs/fs/$GRP/uk07267/BEC-opt
nvidia-smi --query-gpu=name --format=csv,noheader | head -1
echo "===== gradient profile (broadcast% after vectorization) ====="
$JULIA --project=. observability/e2e/profile_gradient.jl 128
echo "===== end-to-end LBFGS (new, vectorized) ====="
$JULIA --project=. observability/e2e/bench_lbfgs_e2e.jl 128 30
echo ALLDONE
