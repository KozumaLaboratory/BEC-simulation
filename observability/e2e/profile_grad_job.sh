#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:12:00
#$ -N grad_prof
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
set -e
GRP=tga-kozuma-kouhi
export JULIA_DEPOT_PATH=/gs/fs/$GRP/shared/.julia
JULIA=/gs/fs/$GRP/shared/.juliaup/bin/julia
cd /gs/fs/$GRP/uk07267/BEC-opt
nvidia-smi --query-gpu=name --format=csv,noheader | head -1
$JULIA --project=. observability/e2e/profile_gradient.jl 128
echo ALLDONE
