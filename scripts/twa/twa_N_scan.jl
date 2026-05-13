# TWA N scan: reproducible runner (Round-2 Task 1).
#
# Runs the three ensemble configs in `runs/twa_N_scan/N{1000,10000,100000}.yaml`
# sequentially, each producing a 50-trajectory ensemble at end-of-Phase-2.
# Then dispatches `scripts/twa/twa_N_scan_analyze.jl` for the 1/N + 1/√N scaling
# tables.
#
# Wall-clock budget on RTX 5070 Ti (32^3 grid, 50 trajectories):
#   N=1000    -> ~31 min
#   N=10000   -> ~31 min
#   N=100000  -> ~31 min
#   total     -> ~95 min
#
# Skips an N point if its result.jld2 already exists. Delete the file to
# force re-run.

using SpinorBEC, CUDA

const ROOT = @__DIR__ |> dirname
const RUN_DIR = joinpath(ROOT, "runs", "twa_N_scan")
const N_VALUES = (1000, 10000, 100000)

function _result_path(N::Integer)
    joinpath(RUN_DIR, "N$(N)", "result.jld2")
end

function run_one(N::Integer)
    cfg = joinpath(RUN_DIR, "N$(N).yaml")
    isfile(cfg) || error("missing config: $cfg")

    out = _result_path(N)
    if isfile(out)
        @info "N=$N: result.jld2 present, skipping (delete to force re-run)" path=out
        return
    end

    @info "N=$N: running ensemble" config=cfg
    t0 = time()
    run_yaml(cfg)
    @info "N=$N: done" elapsed_min=(time() - t0) / 60
end

function main()
    @info "TWA N scan starting" N_values=N_VALUES run_dir=RUN_DIR
    for N in N_VALUES
        run_one(N)
    end

    analyze = joinpath(@__DIR__, "twa_N_scan_analyze.jl")
    @info "All ensembles complete; running analyzer" script=analyze
    include(analyze)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
