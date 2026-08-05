#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:25:00
#$ -N lbfgs_e2e
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
set -e
GRP=tga-kozuma-kouhi
export JULIA_DEPOT_PATH=/gs/fs/$GRP/shared/.julia
JULIA=/gs/fs/$GRP/shared/.juliaup/bin/julia
cd /gs/fs/$GRP/uk07267/BEC-opt
E=observability/e2e
nvidia-smi --query-gpu=name --format=csv,noheader | head -1
echo "===== NEW (P2 + gate-first + fusion) ====="
$JULIA --project=. $E/bench_lbfgs_e2e.jl 128 30
echo "===== swap in pre-campaign code, recompile, run OLD ====="
cp ext/SpinorBECCUDAExt/gpu_energy.jl /tmp/ge.keep
cp ext/SpinorBECCUDAExt/gpu_tensor.jl /tmp/gt.keep
cp src/solvers/lbfgs/energy_gradient.jl /tmp/eg.keep
cp $E/gpu_energy.jl.old      ext/SpinorBECCUDAExt/gpu_energy.jl
cp $E/gpu_tensor.jl.old      ext/SpinorBECCUDAExt/gpu_tensor.jl
cp $E/energy_gradient.jl.old src/solvers/lbfgs/energy_gradient.jl
$JULIA --project=. $E/bench_lbfgs_e2e.jl 128 30
echo "===== restore NEW ====="
cp /tmp/ge.keep ext/SpinorBECCUDAExt/gpu_energy.jl
cp /tmp/gt.keep ext/SpinorBECCUDAExt/gpu_tensor.jl
cp /tmp/eg.keep src/solvers/lbfgs/energy_gradient.jl
echo ALLDONE
