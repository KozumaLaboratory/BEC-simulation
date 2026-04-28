#!/bin/bash
#$ -cwd
#$ -l h_rt=12:00:00
#$ -l f_node=1
#$ -t 1-11        # array of 11 = 3 Dy + 8 Eu configs (adjust if scan changes)
#$ -tc 4          # max 4 concurrent (TSUBAME node has limited GPU sharing)
#$ -N spinor_scan
#$ -o logs/tsubame/$JOB_NAME_$JOB_ID_$TASK_ID.log
#$ -j y

# TSUBAME job array driver for the high-resolution Dy + Eu scan.
#
# Submit:
#   julia --project=. scripts/tsubame/generate_hires_scan.jl   # one-shot, populates runs/tsubame_scan/
#   qsub scripts/tsubame/run_scan_array.sbatch
#
# Each task picks one config from runs/tsubame_scan/ (sorted alphabetically)
# and runs it. Job status:
#   qstat -j $JOB_ID
#   qstat -u $USER -t

. /etc/profile.d/modules.sh
module load cuda/12.6.0
module load julia/1.12.6 || true

PROJECT_ROOT=/gs/bs/${USER}/SpinorBEC.jl
cd "$PROJECT_ROOT" || exit 1
mkdir -p logs/tsubame

# --- Pick this task's config by index (1-based, sorted) ---
mapfile -t CONFIGS < <(ls -d runs/tsubame_scan/*/ | sort | awk -F/ '{print $(NF-1)}')
RUN_NAME="${CONFIGS[$((SGE_TASK_ID - 1))]}"

if [ -z "$RUN_NAME" ]; then
    echo "Task $SGE_TASK_ID: no config found"
    exit 1
fi

echo "[$(date)] Task $SGE_TASK_ID/$SGE_TASK_LAST starting $RUN_NAME"

# --- Node-local scratch ---
export SPINORBEC_SCRATCH_DIR=$T3TMPDIR/${JOB_ID}_${SGE_TASK_ID}
mkdir -p "$SPINORBEC_SCRATCH_DIR"

# --- CUDA paths (verify on TSUBAME — may need adjustment) ---
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# --- Run via the same launcher we use locally ---
# Note: scripts/launch_thesis_run.jl hardcodes runs/thesis_batch/<name>/.
# For tsubame_scan we use a similar wrapper:
julia --project=. -e "
using CUDA, SpinorBEC, JLD2
config = SpinorBEC.load_config(\"runs/tsubame_scan/${RUN_NAME}/config.yaml\")
@time result = SpinorBEC.run_config(config; verbose=true)

dyn = result[:rotating_basis_dynamics]
println(\"Larmor phase: \", get(dyn, :larmor_phase_per_step, NaN))
println(\"dt_used: \", get(dyn, :dt_used, NaN))
pm_init = dyn[:per_m_history][1] / sum(dyn[:per_m_history][1])
pm_final = dyn[:per_m_history][end] / sum(dyn[:per_m_history][end])
println(\"=== ${RUN_NAME} COMPLETED ===\")
println(\"  m=+F: \$(round(pm_init[1]; digits=6)) -> \$(round(pm_final[1]; digits=6))\")

JLD2.jldsave(\"runs/tsubame_scan/${RUN_NAME}/result_legacy.jld2\";
    times=dyn[:times], norms=dyn[:norms], Lz=dyn[:Lz], Fz=dyn[:Fz],
    per_m_history=hcat(dyn[:per_m_history]...),
    psi_snapshots=Vector{Array{ComplexF64,4}}([Array(s) for s in get(dyn, :psi_snapshots, [])]),
    dt_used=get(dyn, :dt_used, NaN),
    larmor_phase=get(dyn, :larmor_phase_per_step, NaN),
)
"

echo "[$(date)] Task $SGE_TASK_ID done"
