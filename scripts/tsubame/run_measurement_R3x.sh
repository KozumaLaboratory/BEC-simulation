#!/bin/sh
# TSUBAME 4.0 job script template — Phase 2 measurement campaign.
#
# Each round (R32-R39) is launched as an array index. Edit the
# directives at top to match the target queue and the array map below
# to add/remove rounds.

#$ -cwd
#$ -l f_node=1
#$ -l h_rt=24:00:00
#$ -N measurement_R3x
#$ -t 1-7
#$ -j y
#$ -o logs/measurement_R3x_$TASK_ID.log

# Project root (this script lives in scripts/tsubame/, so pop two levels).
cd "$(dirname "$0")/../.." || exit 1

# WSL2 / TSUBAME both need the LD_LIBRARY_PATH for CUDA — pick up the
# environment module before launching julia.
module load cuda/12.4
export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:$LD_LIBRARY_PATH"

# Heavy-gate: opt in for the R34/R38 YAML wrappers that gate themselves
# behind this env var.
export SPINORBEC_RUN_HEAVY_YAML=true

# Local-scratch JLD2 .tmp redirect (TSUBAME-friendly, see CLAUDE.md
# "SPINORBEC_SCRATCH_DIR env var redirects").
export SPINORBEC_SCRATCH_DIR="$T3TMPDIR"

# Round selector — array task ID maps to round + run command.
case "$SGE_TASK_ID" in
    1)
        # R33 — MFBO Eu phase scan
        julia --project=. scripts/tsubame/measurement_R33.jl ;;
    2)
        # R35 — B-1 boundary trace
        julia --project=. scripts/tsubame/measurement_R35.jl ;;
    3)
        # R36 — 4D AL Eu (slow — split into job array if needed)
        julia --project=. scripts/tsubame/measurement_R36.jl ;;
    4)
        # R37 — Triple-point hunt (depends on R36 output)
        julia --project=. scripts/tsubame/measurement_R37.jl ;;
    5)
        # R39 — BdG along R35 boundary (depends on R35 output)
        julia --project=. scripts/tsubame/measurement_R39.jl ;;
    6)
        # R32 — Sobolev sweep (low priority, F=6 + DDI)
        julia --project=. scripts/tsubame/measurement_R32.jl ;;
    7)
        # Slack — re-run a failed earlier task or post-process
        echo "slack — manual"
        ;;
    *)
        echo "unknown task id $SGE_TASK_ID"
        exit 1 ;;
esac

echo "task $SGE_TASK_ID complete"
