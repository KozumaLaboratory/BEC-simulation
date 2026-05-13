# TWA ε_dd scan: reproducible runner (Round-2 Task 2).
#
# Runs four 50-trajectory TWA ensembles at fixed N_atoms=10⁴ and varying
# c_dd to sweep the scalar dipolar parameter ε_dd = a_dd/a_s. The four
# species labels are mnemonic only — physics is set by c_dd, not the atom.
#
#   Cr-like  (ε_dd = 0.15) c_dd = 11.5
#   Eu       (ε_dd = 0.55) c_dd = natural (no override)
#   Er-like  (ε_dd = 0.88) c_dd = 67.5
#   Dy-like  (ε_dd = 1.39) c_dd = 106.6
#
# Wall-clock on RTX 5070 Ti (32^3 grid, 50 trajectories): ~31 min per point.
# Total ~125 min. Run after `scripts/twa/twa_N_scan.jl` (single GPU; the
# runners do not parallelise).

using SpinorBEC, CUDA

const ROOT = @__DIR__ |> dirname
const RUN_DIR = joinpath(ROOT, "runs", "twa_eps_dd_scan")
const POINTS = (
    (label="Cr_eps0.15", eps_dd=0.15),
    (label="Eu_eps0.55", eps_dd=0.55),
    (label="Er_eps0.88", eps_dd=0.88),
    (label="Dy_eps1.39", eps_dd=1.39),
)

_result_path(label::AbstractString) = joinpath(RUN_DIR, label, "result.jld2")

function run_one(label::AbstractString)
    cfg = joinpath(RUN_DIR, "$(label).yaml")
    isfile(cfg) || error("missing config: $cfg")

    out = _result_path(label)
    if isfile(out)
        @info "$label: result.jld2 present, skipping" path=out
        return
    end

    @info "$label: running ensemble" config=cfg
    t0 = time()
    run_yaml(cfg)
    @info "$label: done" elapsed_min=(time() - t0) / 60
end

function main()
    @info "TWA ε_dd scan starting" n_points=length(POINTS) run_dir=RUN_DIR
    for p in POINTS
        run_one(p.label)
    end

    analyze = joinpath(@__DIR__, "twa_eps_dd_scan_analyze.jl")
    if isfile(analyze)
        @info "All ensembles complete; running analyzer" script=analyze
        include(analyze)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
