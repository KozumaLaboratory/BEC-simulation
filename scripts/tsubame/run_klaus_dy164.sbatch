#!/bin/bash
#$ -cwd
#$ -l h_rt=06:00:00
#$ -l f_node=1
#$ -N klaus_dy164_main
#$ -o logs/tsubame/$JOB_NAME_$JOB_ID.log
#$ -j y

# TSUBAME 4.0 (or 3.0) job script for klaus_option_gamma_full reproduction.
#
# Resource request:
#   - 1 full node (f_node=1) → 1× H100 (or V100/A100 depending on era)
#   - 6h wall time (Klaus 1s stir at ε=1e-6 estimated 4-5h on H100)
#
# Submit:  qsub scripts/tsubame/run_klaus_dy164.sbatch
# Status:  qstat -j $JOB_ID
# Cancel:  qdel $JOB_ID

# --- Module setup ---
# Replace these with whatever your TSUBAME profile needs
. /etc/profile.d/modules.sh
module load cuda/12.6.0
module load julia/1.12.6 || true   # if not available, install via juliaup

# --- Project setup ---
PROJECT_ROOT=/gs/bs/${USER}/SpinorBEC.jl   # adjust to your install path
RUN_NAME=klaus_option_gamma_full           # canonical Dy164 Klaus reproduction
EPSILON_STR=eps1e6                         # tag for the ε=1e-6 variant

cd "$PROJECT_ROOT" || exit 1
mkdir -p logs/tsubame

# --- Node-local scratch for JLD2 .tmp atomic writes ---
# Avoids hammering the shared FS during multi-GB snapshot writes.
export SPINORBEC_SCRATCH_DIR=$T3TMPDIR    # or /tmp/$JOB_ID on older systems
mkdir -p "$SPINORBEC_SCRATCH_DIR"

# --- CUDA library path (TSUBAME-specific paths may differ) ---
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# --- Run ---
# This assumes runs/${RUN_NAME}/config.yaml has been prepared with ε=1e-6
# (REPL audit: tabulate(Batch("runs/thesis_batch"), [:norm_drift, :Fz, :per_m_t])).
# For the original ε=1e-3 config, expect false convergence in the
# Klaus p·F·dt > 300 regime.
julia --project=. -e "
using CUDA, SpinorBEC, JLD2
config = SpinorBEC.load_config(\"runs/${RUN_NAME}/config.yaml\")
@time result = SpinorBEC.run_config(config; verbose=true)
dyn = result[:rotating_basis_dynamics]
println(\"Larmor phase per step: \", get(dyn, :larmor_phase_per_step, NaN))
println(\"dt_used: \", get(dyn, :dt_used, NaN))
println(\"epsilon_target: \", get(dyn, :epsilon_target, NaN))
"

# --- Dashboard format is auto-saved by run_pipeline (since 2026-04-29); no
# --- separate repack step required. The result.jld2 + point_001.jld2 symlink
# --- lands on disk automatically when checkpoint_dir is set.
