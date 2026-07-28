# Per-SEED (not min-E) extractor carrying E, grad_norm AND mF, for the transition-
# ORDER diagnosis: first-order shows two DISTINCT branches (FM mF≈1, polar mF≈0)
# with an energy crossing; continuous shows a single branch carrying mF smoothly
# through. Needs mF PER SEED (spinor_fingerprint), so this loads SpinorBEC (unlike
# the fast E+grad-only eu_phase_seed_energies.jl).
#
#   julia --project=. scripts/eu_phase_seed_full.jl <run_dir> [out.csv]
# env SPINORBEC_PHASE_B_UG  B (µG) fallback when B is a base value, not scanned.

using SpinorBEC
using SpinorBEC: make_grid, GridConfig, spinor_fingerprint
using JLD2

const RUN = length(ARGS) >= 1 ? ARGS[1] : error("usage: eu_phase_seed_full.jl <run_dir> [out.csv]")
const OUT = length(ARGS) >= 2 ? ARGS[2] : joinpath(RUN, "seed_full.csv")
const BDEF = parse(Float64, get(ENV, "SPINORBEC_PHASE_B_UG", "NaN"))
_ug(s) = 1e6 * parse(Float64, split(String(s))[1])

open(OUT, "w") do io
    println(io, "c1_ratio,B_uG,kappa,seed,E,grad_norm,mF")
    for f in sort(readdir(RUN))
        m = match(r"^point_\d+_(.+)\.jld2$", f)
        m === nothing && continue
        seed = m.captures[1]
        path = joinpath(RUN, f)
        local E
        try
            E = JLD2.load(path, "energy")
        catch
            continue
        end
        ov = try
            JLD2.load(path, "override")
        catch
            Dict{String,Any}()
        end
        c1 = get(ov, "pipeline.0.interactions.c1_ratio", NaN)
        b = get(ov, "pipeline.0.B.Bz", missing)
        B = b === missing ? BDEF : _ug(b)
        k = Float64(get(ov, "pipeline.0.potential.omega.2", NaN))
        g = try
            JLD2.load(path, "grad_norm")
        catch
            NaN
        end
        mF = try
            psi = SpinorBEC.load_point_psi(path)   # light-point aware (gs_ref → stage)
            n = Int.(JLD2.load(path, "grid_n_points"))
            box = Float64.(JLD2.load(path, "grid_box_size"))
            grid = make_grid(GridConfig(Tuple(n), Tuple(box)))
            spinor_fingerprint(psi, grid, 6).mF
        catch
            NaN
        end
        println(io, join((c1, B, k, seed, E, g, mF), ","))
    end
end
println("wrote ", OUT)
