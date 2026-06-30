#!/bin/bash
#$ -cwd
#$ -N edh_v5
#$ -l gpu_h=1
#$ -l h_rt=4:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/edh_v5.log
set -euo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
export FPE_RUNS_ROOT="$DATA"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
echo "=== EdH v5 dynamics + diagnostic (c1=1/36, K3=2.1e-41 realistic loss) ==="
"$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl runs/eu151_edh_vs_flower/edh_quench_v5.yaml
RDIR=$(ls -d "$DATA"/edh_quench_v5_*/ 2>/dev/null | head -1)
echo "=== extract from $RDIR ==="
"$JULIA" --project=. scripts/edh_vs_flower/extract_slices.jl "$RDIR/point_001.jld2" "$RDIR/slices.jld2" --tstride 1
"$JULIA" --project=. scripts/edh_vs_flower/extract_3d.jl "$RDIR/point_001.jld2" "$RDIR/spin3d.jld2" --stride 2 --tstride 1 --box 18 --F 6
"$JULIA" --project=. scripts/edh_vs_flower/extract_psi13.jl "$RDIR/point_001.jld2" "$DATA/edh_v5_psi13.jld2" --stride 2 --tstride 1 --box 18 --F 6
echo "=== done RDIR=$RDIR ==="
