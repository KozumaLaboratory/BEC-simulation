#!/usr/bin/env bash
# TSUBAME pre-flight check — verify CUDA / Julia / project install before
# committing GPU-hours to a scan submission.
#
# Run on a TSUBAME compute node (e.g. `qrsh -l gpu_h=1,h_rt=00:30:00`):
#   bash scripts/tsubame/preflight.sh

set -e

echo "=== TSUBAME preflight ==="
echo "host: $(hostname)"
echo "date: $(date)"
echo

# 1. Module system + CUDA toolkit
. /etc/profile.d/modules.sh 2>/dev/null || echo "WARNING: no module system found"
module list 2>&1 | head -10 || true
echo
echo "--- CUDA driver / toolkit ---"
which nvcc && nvcc --version | head -3
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv | head -5
echo

# 2. Julia
echo "--- Julia ---"
which julia
julia --version
echo

# 3. Project install + Manifest compatibility
PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$PROJECT_ROOT"
echo "--- Project: $PROJECT_ROOT ---"
ls -la Project.toml Manifest.toml 2>/dev/null

# 4. Try precompiling the package
echo "--- Precompile check ---"
LD_LIBRARY_PATH=${CUDA_HOME:-/usr/local/cuda}/lib64:${LD_LIBRARY_PATH:-} \
    julia --project=. -e '
using Pkg
println("Active project: ", Pkg.project().path)
@time Pkg.precompile()
println("Loading SpinorBEC + CUDA…")
@time using CUDA
@time using SpinorBEC
println()
println("CUDA functional: ", CUDA.functional())
println("CUDA device:     ", CUDA.functional() ? CUDA.name(CUDA.device()) : "none")
println("CUDA capability: ", CUDA.functional() ? CUDA.capability(CUDA.device()) : "none")
println("CUDA mem free:   ",
    CUDA.functional() ? "$(round(CUDA.available_memory()/1e9; digits=1)) GB" : "none")
'

# 5. Tiny end-to-end smoke test
echo
echo "--- Smoke test (option_gamma_micro) ---"
LD_LIBRARY_PATH=${CUDA_HOME:-/usr/local/cuda}/lib64:${LD_LIBRARY_PATH:-} \
    julia --project=. -e '
using CUDA, SpinorBEC
config = SpinorBEC.load_config("runs/option_gamma_micro/config.yaml")
@time SpinorBEC.run_config(config; verbose=false)
println("✅ smoke test passed")
'

# 6. Scratch dir check
echo
echo "--- Scratch dir ---"
echo "T3TMPDIR=${T3TMPDIR:-(not set)}"
echo "TMPDIR=${TMPDIR:-(not set)}"
df -h ${T3TMPDIR:-/tmp} 2>/dev/null | head -2

echo
echo "✅ preflight passed — ready to submit scan_array"
