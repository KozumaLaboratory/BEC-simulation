#!/bin/bash
# Movie version of the m=-6 imprint + quench (fig_m6_spatial, but in time).
# SMOKE=1 shrinks it to a ~2 min sanity pass first.
#
# Only small per-frame arrays reach /gs (~29 MB/arm); psi stays on the per-job
# /tmp. TWO independent limits, both hit for real:
#   * /gs was at 99% (16 GB free) — psi must never be written there.
#   * per-job /tmp on gpu_1 is small — 250 streamed 80x80x40 frames (~6.6 GB)
#     SIGBUSed the snapshot mmap mid-dynamics. Keep RB_SAVE_EVERY >= 1000.
#
#$ -cwd
#$ -N eu_m6_movie
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -j y
#$ -o logs/tsubame/m6_movie.log
set -euo pipefail

REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"
mkdir -p logs/tsubame
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup

export RB_BOX="20.0, 20.0, 10.0"
export RB_N="80, 80, 40"
export RB_DT="0.0004"
export RB_LOSS="${RB_LOSS:-1}"
# The content-addressed run key is the config spec and does NOT include the
# source version, so a byte-identical config reuses a result computed by
# pre-bugfix code. RB_TAG is carried in the spec to break that — BUMP IT
# whenever the physics code changes.
export RB_TAG="${RB_TAG:-movie1}"
if [ "${SMOKE:-0}" = "1" ]; then
  export RB_GS_STEPS="50"; export RB_DUR="2.0"; export RB_SAVE_EVERY="200"
  export RB_TAG="${RB_TAG}smoke"
else
  # save_every=1000 -> 125 frames, which is 4.2 s at 30 fps and is the setting
  # the original m6 job is known to survive. Lower values overflow the per-job
  # /tmp on gpu_1 and the snapshot mmap SIGBUSes mid-dynamics: measured, 250
  # streamed frames at 80x80x40 (~6.6 GB) core-dumped twice.
  export RB_GS_STEPS="2500"; export RB_DUR="50.0"; export RB_SAVE_EVERY="1000"
fi

source scripts/tsubame_setup.sh
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== M6-MOVIE node $(hostname) $(date) box=$RB_BOX n=$RB_N dur=$RB_DUR save=$RB_SAVE_EVERY tag=$RB_TAG SMOKE=${SMOKE:-0} ==="
df -h /gs/fs | tail -1
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_m6_movie.jl
echo "=== done $(date) ==="
ls -la runs/eu_barnett_rotfield_clean/rebuild_movie/
