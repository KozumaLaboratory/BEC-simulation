# Extract BOTH seeds' energies (not just min-E) per (c1,κ) cell, so the phase
# boundary can be located the thermodynamically-correct way — by the energy
# crossing E_FM = E_polar — and the transition ORDER diagnosed from the seed
# near-degeneracy (bistable/coexistence ⇒ first-order) instead of smoothing over
# it. Also carries grad_norm per seed so under-converged cells are visible, not
# hidden. Output is one row PER SEED; the analysis pivots to per-cell downstream.
#
#   julia --project=. scripts/eu_phase_seed_energies.jl <run_dir> [out.csv]
# env SPINORBEC_PHASE_B_UG   B (µG) fallback when B is a base value, not scanned.

using JLD2

const RUN = length(ARGS) >= 1 ? ARGS[1] : error("usage: eu_phase_seed_energies.jl <run_dir> [out.csv]")
const OUT = length(ARGS) >= 2 ? ARGS[2] : joinpath(RUN, "seed_energies.csv")
const BDEF = parse(Float64, get(ENV, "SPINORBEC_PHASE_B_UG", "NaN"))
_ug(s) = 1e6 * parse(Float64, split(String(s))[1])

open(OUT, "w") do io
    println(io, "c1_ratio,B_uG,kappa,seed,E,grad_norm")
    for f in sort(readdir(RUN))
        m = match(r"^point_\d+_(.+)\.jld2$", f)
        m === nothing && continue
        seed = m.captures[1]
        path = joinpath(RUN, f)
        E = try
            JLD2.load(path, "energy")
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
        println(io, join((c1, B, k, seed, E, g), ","))
    end
end
println("wrote ", OUT)
