#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=1:00:00
#$ -N pardiag
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# Diagnostic, not a comparison. Job 8324826's eight GPU runs produced no PHYS
# line, no WALL line and no error, even under `tail -40` — so the julia process
# is dying before it prints anything, or it is writing somewhere the reader does
# not look. Two attempts have now been burned on my setup rather than on the
# question, so this run only establishes HOW to run the thing, with no
# comparison logic to go wrong.
#
# Everything is unbuffered and nothing is filtered.
set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
ROOT=/gs/fs/tga-kozuma-kouhi/uk07267
D=$ROOT/parity_after
STORE=$ROOT/pardiag_store

echo "host=$(hostname) date=$(date)"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>&1 | head -1
cd "$D"
echo "checkout $(git rev-parse --short HEAD)"

rm -rf "$STORE"; mkdir -p "$STORE"

echo "### A. does the package load and see the GPU?"
$JULIA --project=. -e '
using SpinorBEC
println("loaded")
try
    @eval import CUDA
    println("cuda_functional = ", SpinorBEC.cuda_functional())
catch e
    println("CUDA import failed: ", e)
end' 2>&1 | tail -20

echo
echo "### B. run the config, everything on stdout, nothing filtered"
SPINORBEC_STORE=$STORE $JULIA --project=. -e '
using SpinorBEC
cfg = ARGS[1]
println("running ", cfg, "  store=", get(ENV,"SPINORBEC_STORE","runs"))
flush(stdout)
try
    run_yaml(cfg; verbose=true)
    println("RUN_OK")
catch e
    println("RUN_THREW: ", sprint(showerror, e, catch_backtrace()))
end
flush(stdout)' runs/eu_gs_phase_c1_B_kappa/config_smoke.yaml 2>&1 | tail -60

echo
echo "### C. what actually landed on disk"
find "$STORE" -type f 2>/dev/null | head -30
echo "jld2 count: $(find "$STORE" -name '*.jld2' 2>/dev/null | wc -l)"

echo
echo "### D. and what does find_ground_state really return"
$JULIA --project=. -e '
using SpinorBEC
r = find_ground_state(; grid=make_grid(GridConfig{3}((8,8,8),(4.0,4.0,4.0))),
        atom=resolve_atom(:Rb87),
        interactions=InteractionParams(Dict(0=>1.0,1=>0.01)),
        potential=HarmonicTrap((1.0,1.0,1.0)),
        dt=0.01, n_steps=20, tol=1e-6, initial_state=:polar, verbose=false)
println("keys = ", propertynames(r))
println("psi is at r.workspace.psi ? ", hasproperty(r.workspace, :psi))' 2>&1 | tail -5

echo "ALL DONE $(date)"
