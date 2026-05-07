# TWA Sinatra criterion validation runner (Round-3 Task 2).
#
# Three TWA ensembles probing whether the σ/μ ≈ 0.42 measured at peak
# in the Eu EdH 50-trajectory ensemble is a real quantum effect or a
# spurious classical-thermalisation artifact arising from the marginal
# Sinatra ratio (32³ × 13 modes vs N=10⁴ atoms, ratio ≈ 43).
#
#   baseline_32g  — 32³ grid, cutoff 6.0   (the reference ensemble)
#   coarse_16g    — 16³ grid, cutoff 6.0   (8× fewer modes, Sinatra ratio ↓)
#   cutoff_16g    — 16³ grid, cutoff 1.0   (drops upper BZ on top of coarsening)
#
# Acceptance test (per parallel-session prediction):
#   * σ/μ at peak roughly N-independent across the three configs
#       → the 0.42 result is genuine quantum noise, publishable.
#   * σ/μ shrinks substantially from baseline → coarse → cutoff
#       → spurious classical thermalisation; needs full BdG / TDHFB
#         to capture the EdH dynamics correctly.
#
# Wall-clock estimate on RTX 5070 Ti:
#   baseline_32g  ~ 31 min   (the 32³ N=10000 reference timing)
#   coarse_16g    ~  5 min   (8× fewer voxels, Wigner sampling matches)
#   cutoff_16g    ~  5 min
# Total ~40 min sequential.

using SpinorBEC, CUDA

const ROOT = dirname(@__DIR__)
const RUN_DIR = joinpath(ROOT, "runs", "twa_sinatra_validation")
const POINTS = ("baseline_32g", "coarse_16g", "cutoff_16g")

_runs_root() = joinpath(ROOT, "runs")

# `run_yaml` writes outputs to `runs/<basename>_<hash>/result.jld2`. The
# Sinatra configs land in `runs/<label>_<hash>/`. Reuse the same
# pattern-resolver as the N-scan analyzer so analysis can find them.
function _resolve_result(label::AbstractString)
    rdir = _runs_root()
    isdir(rdir) || return nothing
    hits = String[]
    for d in readdir(rdir; join=true)
        isdir(d) || continue
        startswith(basename(d), label * "_") || continue
        rj = joinpath(d, "result.jld2")
        isfile(rj) && push!(hits, rj)
    end
    isempty(hits) ? nothing : (sort!(hits; by=mtime, rev=true); first(hits))
end

function run_one(label::AbstractString)
    cfg = joinpath(RUN_DIR, "$(label).yaml")
    isfile(cfg) || error("missing config: $cfg")
    out = _resolve_result(label)
    if out !== nothing
        @info "$label: result.jld2 present, skipping" path = out
        return nothing
    end
    @info "$label: running ensemble" config = cfg
    t0 = time()
    run_yaml(cfg)
    @info "$label: done" elapsed_min = (time() - t0) / 60
end

function main()
    @info "TWA Sinatra validation starting" labels = POINTS run_dir = RUN_DIR
    for label in POINTS
        run_one(label)
    end

    analyze = joinpath(@__DIR__, "twa_sinatra_validation_analyze.jl")
    isfile(analyze) && (@info "Running analyzer" script = analyze; include(analyze))
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
