# Canonical 1/N TWA-validity test runner (Round-3 follow-up).
#
# Mirror of `examples/twa_N_scan.jl` but with c_total / c_dd PINNED at
# the Eu-151 N=10⁴ baseline values. Only the Wigner noise scale differs
# across the three runs, so the result probes the truncated-Wigner
# expansion's leading-order 1/N validity directly.
#
# Expected scalings (Findings B-prime, to be confirmed by the analyzer):
#   * (TWA mean − GP) / GP   ∝ 1/N
#   * σ/μ at peak            ∝ 1/√N
#   * FWHM_z = 6 cells       N-independent (genuine dipolar instability)
#
# Wall-clock budget on RTX 5070 Ti: 30 min × 3 ≈ 95 min total. The runner
# skips configs whose result.jld2 already exists. This script is staged
# but should NOT auto-fire — the user wants Sinatra-criterion results
# first to confirm the 32³ baseline grid is in the controlled regime.

using SpinorBEC, CUDA

const ROOT = dirname(@__DIR__)
const RUN_DIR = joinpath(ROOT, "runs", "twa_N_scan_pinned")
const N_VALUES = (1000, 10000, 100000)

function _resolve_result(N::Integer)
    runs_root = joinpath(ROOT, "runs")
    isdir(runs_root) || return nothing
    hits = String[]
    for d in readdir(runs_root; join=true)
        isdir(d) || continue
        startswith(basename(d), "N$(N)_pinned_") || continue
        rj = joinpath(d, "result.jld2")
        isfile(rj) && push!(hits, rj)
    end
    isempty(hits) ? nothing : (sort!(hits; by=mtime, rev=true); first(hits))
end

function run_one(N::Integer)
    cfg = joinpath(RUN_DIR, "N$(N)_pinned.yaml")
    isfile(cfg) || error("missing config: $cfg")
    out = _resolve_result(N)
    if out !== nothing
        @info "N=$N (pinned): result.jld2 present, skipping" path = out
        return nothing
    end
    @info "N=$N (pinned): running ensemble" config = cfg
    t0 = time()
    run_yaml(cfg)
    @info "N=$N (pinned): done" elapsed_min = (time() - t0) / 60
end

function main()
    @info "TWA 1/N pinned-coupling scan starting" N_values = N_VALUES run_dir = RUN_DIR
    for N in N_VALUES
        run_one(N)
    end
    analyze = joinpath(@__DIR__, "twa_N_scan_pinned_analyze.jl")
    isfile(analyze) && (@info "Running analyzer" script = analyze; include(analyze))
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
