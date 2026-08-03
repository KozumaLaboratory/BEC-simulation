#!/bin/bash
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=1:00:00
#$ -N openinf
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# The unified design (#300) says an influence left OUTSIDE the name must carry a
# MEASURED cost against a budget, and `isnan(cost)` is red at build. Three rows
# are currently carried as `:dropped` because nobody has measured them on psi:
#
#   * FFTW planner effort   — MEASURE vs ESTIMATE picks a different codelet tree
#   * OpenBLAS thread count — level-1 reductions are reassociated per team size
#   * BLAS/thread interaction with the ITP loop
#
# They are declared open influences, so the question is not "do they change the
# answer" — of course a different summation order can — but HOW MUCH, on the
# state, in this regime. A number turns a dropped row into a caveat with a
# budget; the absence of one is what the design refuses to tolerate.
#
# CPU only and single node: the point is arithmetic, not throughput.
set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-ddi-conv}"
echo "host=$(hostname) commit=$(git rev-parse --short HEAD) date=$(date)"
export SPINORBEC_NO_AUTO_BACKEND=1

$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -2

# One process per condition: FFTW's plan cache and BLAS's team are process-global,
# so comparing them inside one session measures whichever was set first.
probe () {   # $1 = label, $2 = extra julia -e prologue
    echo "### $1"
    OPENBLAS_NUM_THREADS=${OMP:-1} $JULIA --project=. -e "
    import CUDA
    using SpinorBEC, LinearAlgebra, FFTW, SHA, Printf
    $2
    # Measured (job 8338648): the returned NamedTuple is
    # (:workspace,:converged,:energy,:dE,:dpsi,:interrupted,:last_step) and
    # hasproperty(r.workspace, :psi) is FALSE. So locate psi rather than guess.
    function _probe_psi(gs)
        for f in propertynames(gs.workspace)
            v = getproperty(gs.workspace, f)
            if v isa AbstractArray{<:Complex} && ndims(v) == 4
                return Array(v)
            end
        end
        error(\"no 4-D complex array on the workspace; fields = \\$(propertynames(gs.workspace))\")
    end
    function main(label)
        grid = make_grid(GridConfig{3}((24,24,24), (8.0,8.0,8.0)))
        atom = resolve_atom(:Eu151)
        ip   = InteractionParams(Dict(0 => 10.0, 1 => 0.1))
        gs = find_ground_state(; grid, atom, interactions=ip,
                 potential=HarmonicTrap((1.0,1.0,1.2)),
                 dt=1.0e-3, n_steps=400, tol=1.0e-12,
                 initial_state=:polar, verbose=false)
        psi = ComplexF64.(_probe_psi(gs))
        h = bytes2hex(sha256(reinterpret(UInt8, vec(psi))))[1:16]
        @printf(\"COST %-22s E=%.15g norm=%.15g psi=%s blas=%d fftw=%s\n\",
                label, Float64(gs.energy), sum(abs2, psi), h,
                BLAS.get_num_threads(), get(ENV, \"FFTWPLAN\", \"default\"))
    end
    main(\"$1\")" 2>&1 | grep -E '^COST|ERROR|Exception'
}

# Baseline, then one knob moved at a time so a difference names its own cause.
OMP=1 probe "blas1_planEST"  'FFTW.set_provider!' 2>/dev/null || true
OMP=1  probe "blas1"   ''
OMP=4  probe "blas4"   ''
OMP=16 probe "blas16"  ''
OMP=1  probe "blas1_measure" 'ENV["FFTWPLAN"]="MEASURE"; FFTW.set_num_threads(1)'

echo "ALL DONE $(date)"
