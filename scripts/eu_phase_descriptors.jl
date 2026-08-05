# Full rotation-invariant descriptor vector per (min-E) cell, for UNSUPERVISED
# phase discovery — no candidate templates. Captures what the scalar classifier
# missed: the σ_S spectrum, orbital L_z (vortex!), structure factors, flux-closure.
#
#   julia --project=. scripts/eu_phase_descriptors.jl <run_dir> [out.csv]

using JLD2, Printf, SpinorBEC

const RUN = ARGS[1]
const OUT = length(ARGS) >= 2 ? ARGS[2] : joinpath(RUN, "descriptors.csv")
const C1DEF = parse(Float64, get(ENV, "SPINORBEC_PHASE_C1", "NaN"))
_ug(s) = 1e6 * parse(Float64, split(String(s))[1])

function _cellkey(ov)
    c1 = get(ov, "pipeline.0.interactions.c1_ratio", missing)
    (c1 === missing ? C1DEF : Float64(c1),
        _ug(get(ov, "pipeline.0.B.Bz", "0.0 Gauss")),
        Float64(get(ov, "pipeline.0.potential.omega.2", NaN)))
end

pts = sort(unique(parse.(Int, [m.captures[1] for f in readdir(RUN)
    for m in (match(r"point_(\d+)_", f),) if m !== nothing])))

Svals = 0:2:12
open(OUT, "w") do io
    hdr = ["c1_ratio", "B_uG", "kappa", "gs_seed", "E_gs",
        ["sigma$S" for S in Svals]...,
        "mF", "coh", "fluxclosure", "abschir", "absLz", "absFz", "Jz",
        "spin_mod", "kspin", "dens_mod", "kdens"]
    println(io, join(hdr, ","))
    for i in pts
        best = nothing
        for s in ("stretched", "polar")
            f = joinpath(RUN, @sprintf("point_%03d_%s.jld2", i, s))
            isfile(f) || continue
            E = JLD2.load(f, "energy")
            (best === nothing || E < best.E) && (best = (; E, f, s))
        end
        best === nothing && continue
        psi = SpinorBEC.load_point_psi(best.f)   # light-point aware (gs_ref → stage)
        n = Int.(JLD2.load(best.f, "grid_n_points"))
        box = Float64.(JLD2.load(best.f, "grid_box_size"))
        ov = JLD2.load(best.f, "override")
        grid = make_grid(GridConfig(Tuple(n), Tuple(box)))
        fp = spinor_fingerprint(psi, grid, 6)
        c1, B, k = _cellkey(ov)
        fcl = isnan(fp.fluxclosure) ? -1.0 : fp.fluxclosure   # NaN (|F|≈0) → sentinel
        row = Any[c1, B, k, best.s, best.E,
            [fp.sigma[S] for S in Svals]...,
            fp.mF, fp.coh, fcl, abs(fp.chirality), abs(fp.Lz), abs(fp.Fz), fp.Jz,
            fp.spin_mod, fp.kspin, fp.dens_mod, fp.kdens]
        println(io, join(row, ","))
    end
end
println("wrote ", OUT)
