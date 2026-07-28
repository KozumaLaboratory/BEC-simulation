#!/bin/bash
# Klaus magnetostirring, as a movie. Three Omega bracketing the quadrupole
# surface-mode threshold Omega_c ~ 0.7-0.75, chosen from the surviving-vortex
# count in the existing scan (traj_p1_O*.csv): 0.40 -> 0, 0.74 -> 11, 0.85 -> 63.
#
# SMOKE=1 gives a ~2 min single-Omega sanity pass.
#
# Storage, all three limits learned the hard way on the m6 job:
#   * group /gs/fs quota is 1 TB and has been AT it -> run dirs go to the
#     personal work area via SPINORBEC_STORE.
#   * per-job /tmp on gpu_1 is small; psi snapshots stream there. 250 frames at
#     48x48x24 f32 is ~1.4 GB/Omega, well under what SIGBUSed the m6 run
#     (~6.6 GB at 80x80x40). Raise P1_SAVE_EVERY if the grid grows.
#   * JLD2 mmap on Lustre SIGBUSes -> archives build on /tmp and are copied.
#
#$ -cwd
#$ -N eu_p1_movie
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -j y
#$ -o logs/tsubame/p1_movie.log
set -euo pipefail

# PRIVATE repo copy, not the shared one. /gs/fs/.../BEC-simulation is written
# by every session at once: this job first died because another branch's src had
# replaced ours (no `from_jld2`), and on the retry died again because src had
# been fixed but `ext/` was still the other branch's and referenced a function
# ours does not define. Patching one directory at a time loses that race
# forever; a private tree ends the class. Override with REPO= if needed.
REPO="${REPO:-/gs/bs/work/7/uk07267/bec-repo-barnett}"
cd "$REPO"
mkdir -p logs/tsubame
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup

export P1_N="${P1_N:-48,48,24}"
export P1_BOX="${P1_BOX:-12.0,12.0,6.0}"
export P1_OMEGAS="${P1_OMEGAS:-0.40,0.74,0.85}"
# The CAS run key is the config spec alone and does NOT include the source
# version, so a byte-identical config reuses a pre-bugfix result. BUMP THIS on
# any physics change.
export P1_TAG="${P1_TAG:-movie1}"
export SPINORBEC_STORE="${SPINORBEC_STORE:-/gs/bs/work/7/uk07267/bec-runs}"
mkdir -p "$SPINORBEC_STORE"

# The TSUBAME repo is SHARED and other sessions rsync their own branch's src
# over it. That happened between this job's sync and its start: the remote src
# had no `from_jld2` support at all, so `initial_state: from_jld2` fell through
# to the numeric-parameter loop and died on Float64("<path>"). Loud is the point
# — the same overwrite could equally well produce a quietly wrong answer.
need_src() {
  local pat="$1" file="$2" min="$3"
  local n; n=$(grep -c "$pat" "$file" 2>/dev/null || echo 0)
  if [ "$n" -lt "$min" ]; then
    echo "FATAL: remote src is not this branch — '$pat' appears $n times in $file (need >= $min)."
    echo "       Another session has rsynced over \$REPO/src. Re-sync and resubmit."
    exit 1
  fi
}
need_src from_jld2 src/workflow/experiments/pipeline/run_step_ground_state.jl 3
need_src _mass_current_vortices src/workflow/experiments/analyzers/analyzers_large/vortex_density_movie.jl 2
# src and ext must come from the SAME tree — a mixed pair precompiles into an
# UndefVarError, which is how the second attempt died.
if [ "$(grep -r _spin_chain_available src/ 2>/dev/null | wc -l)" != "$(grep -r _spin_chain_available ext/ 2>/dev/null | wc -l)" ]; then
  echo "FATAL: src/ and ext/ disagree — mixed trees. Re-sync BOTH and resubmit."; exit 1
fi
echo "[guard] remote src carries this branch's from_jld2 + mass-current vortex code"

source scripts/tsubame_setup.sh
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== P1-MOVIE node $(hostname) $(date) n=$P1_N box=$P1_BOX omegas=$P1_OMEGAS tag=$P1_TAG SMOKE=${SMOKE:-0} ==="
df -h /gs/fs | tail -1
echo "store=$SPINORBEC_STORE"; df -h "$SPINORBEC_STORE" 2>/dev/null | tail -1
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_p1_klaus_movie.jl
echo "=== done $(date) ==="
ls -la runs/eu_barnett_rotfield_clean/rebuild_movie/
