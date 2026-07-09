#!/bin/bash
#$ -cwd
#$ -N smoke_v6
#$ -l gpu_h=1
#$ -l h_rt=1:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/smoke_v6.log
# End-to-end validation of the v6 code path at 16^3 (cheap): GS(--n 16) ->
# f64 dynamics -> stride=1 f64 extraction. Run this BEFORE the real 96^3 jobs.
set -euo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
mkdir -p "$DATA"; cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
export FPE_RUNS_ROOT="$DATA"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
echo "=== smoke GS 16^3 c1=1/36 ==="
"$JULIA" --project=. scripts/edh_vs_flower/gs_trajectory.jl \
  "$DATA/_smoke_v6_gs_traj.jld2" \
  "$PROJECT_ROOT/runs/eu151_edh_vs_flower/cache/_smoke_v6_gs.jld2" \
  --backend gpu --n 16 --record_every 200 --itp_steps 1500 --lbfgs_steps 100 --c1_ratio 1/36
echo "=== smoke RTP (f64 save) ==="
"$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl runs/eu151_edh_vs_flower/_smoke_v6.yaml
RDIR=$(ls -dt "$DATA"/_smoke_v6_*/ 2>/dev/null | head -1)
echo "=== smoke extraction stride=1 f64 from $RDIR ==="
"$JULIA" --project=. scripts/edh_vs_flower/extract_3d.jl   "$RDIR/point_001.jld2" "$RDIR/spin3d.jld2"        --stride 1 --tstride 1 --box 18 --F 6
"$JULIA" --project=. scripts/edh_vs_flower/extract_psi13.jl "$RDIR/point_001.jld2" "$DATA/_smoke_v6_psi13.jld2" --stride 1 --tstride 1 --box 18 --F 6 --dtype f64
echo "=== SMOKE OK: check 16^3 grid + f64 dtype below ==="
"$VIZPY_OR_PY" -c "import h5py,numpy as np; f=h5py.File('$DATA/_smoke_v6_psi13.jld2','r'); a=np.asarray(f['psi_re_c13']); print('psi13 shape',a.shape,'dtype',a.dtype)" 2>/dev/null || \
 python3 -c "import h5py,numpy as np; f=h5py.File('$DATA/_smoke_v6_psi13.jld2','r'); a=np.asarray(f['psi_re_c13']); print('psi13 shape',a.shape,'dtype',a.dtype)" 2>/dev/null || echo "(h5 check skipped)"
echo "=== smoke done ==="
