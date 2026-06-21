#!/bin/bash
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=0:30:00
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
# Usage: qsub -g tga-kozuma-kouhi -N <name> bench/tsubame_run.sh <julia_script> [args...]
set -e
GRP=tga-kozuma-kouhi
export JULIA_DEPOT_PATH=/gs/fs/$GRP/shared/.julia
cd /gs/fs/$GRP/uk07267/BEC-opt
SCRIPT="$1"; shift
echo "host=$(hostname) script=$SCRIPT args=$* date=$(date)"
nvidia-smi --query-gpu=name --format=csv,noheader || true
/gs/fs/$GRP/shared/.juliaup/bin/julia --project=. "$SCRIPT" "$@"
echo "EXIT=$?"
