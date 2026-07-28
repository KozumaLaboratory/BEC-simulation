#!/bin/bash
# Deploy helper for the Eu finite-temperature SGPE GPU campaign on TSUBAME 4.
#
# This script DOES NOT auto-run anything by default. It prints the exact
# copy-pasteable command sequence. Pass `--run` to actually execute the
# stages (rsync up, instantiate, submit, poll, rsync back).
#
# All values below are resolved from scripts/spinorbec.env.

set -euo pipefail

HOST=tsubame
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
RUNS_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/runs
GROUP=tga-kozuma-kouhi
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
DEPOT=/gs/fs/tga-kozuma-kouhi/shared/.julia
MODE=${SBEC_FT_MODE:-campaign}
LOCAL_ROOT=$(cd "$(dirname "$0")/../.." && pwd)

cat <<EOF
# ============================================================================
# Eu finite-T SGPE campaign — TSUBAME 4 deploy sequence (mode=${MODE})
# Local repo : ${LOCAL_ROOT}
# Remote     : ${HOST}:${PROJECT_ROOT}
# ============================================================================

# (a) rsync the local tree to project_root (exclude .git, runs, logs)
rsync -avz --delete \\
    --exclude='.git' --exclude='runs' --exclude='logs' \\
    "${LOCAL_ROOT}/" "${HOST}:${PROJECT_ROOT}/"

# (b) instantiate on the login node (only needed after Project/Manifest change)
ssh ${HOST} 'cd ${PROJECT_ROOT} && JULIA_DEPOT_PATH=${DEPOT} \\
    ${JULIA} --project=. -e "using Pkg; Pkg.instantiate()"'

# (c) submit the job (group as CLI flag, mode via -v; NEVER a #\$ -g directive)
ssh ${HOST} 'cd ${PROJECT_ROOT} && \\
    qsub -g ${GROUP} -v SBEC_FT_MODE=${MODE} scripts/eu_shape/submit_finite_t.sh'

# (d) poll the queue
ssh ${HOST} 'qstat -u \$USER'

# (e) rsync results back into the local runs/ tree
rsync -avz "${HOST}:${RUNS_ROOT}/eu_shape_finite_t/" \\
    "${LOCAL_ROOT}/runs/eu_shape_finite_t/"
# ============================================================================
EOF

if [[ "${1:-}" != "--run" ]]; then
    echo
    echo "# (dry-run: printed only. Re-run with --run to execute the stages.)"
    exit 0
fi

echo ">>> (a) rsync up"
rsync -avz --delete --exclude='.git' --exclude='runs' --exclude='logs' \
    "${LOCAL_ROOT}/" "${HOST}:${PROJECT_ROOT}/"

echo ">>> (b) instantiate"
ssh ${HOST} "cd ${PROJECT_ROOT} && JULIA_DEPOT_PATH=${DEPOT} ${JULIA} --project=. -e 'using Pkg; Pkg.instantiate()'"

echo ">>> (c) submit"
ssh ${HOST} "cd ${PROJECT_ROOT} && qsub -g ${GROUP} -v SBEC_FT_MODE=${MODE} scripts/eu_shape/submit_finite_t.sh"

echo ">>> (d) poll"
ssh ${HOST} 'qstat -u $USER'

echo ">>> (e) rsync results back (run after the job completes)"
echo "rsync -avz ${HOST}:${RUNS_ROOT}/eu_shape_finite_t/ ${LOCAL_ROOT}/runs/eu_shape_finite_t/"
