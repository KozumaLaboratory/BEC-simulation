# Gauge/frame-invariant phase RE-LABEL for a (c1×Bz×κ) GS scan.
#
#   julia --project=. scripts/eu_phase_fingerprint.jl <run_dir> [out.csv]
#
# The coarse phase_classify_distance label calls the weak-field texture "cyclic",
# but the validated weak-field Eu+DDI GS is the FLOWER (flux-closure, ∇·F≈0)
# phase — locally ferromagnetic (mF≈1) with a divergence-free in-plane texture.
# This re-labels each cell (min-E seed) from spinor_fingerprint:
#   mF ≳ 0.5 & fluxclosure < 0.5  → flower   (flux-closure FM texture; weak field)
#   mF ≳ 0.5 & fluxclosure ≥ 0.5  → ferromagnetic (uniform / polarised)
#   mF ≲ 0.5                      → the nearest polyhedral inert state (polar/…)
# The 0.577 density-gradient baseline (uniform-spin cloud) is the flux reference;
# a true flux-closure reads well below it (validated ≈0.06 for the Eu Flower GS).

using JLD2, Printf, SpinorBEC

include(joinpath(@__DIR__, "eu_phase_classifier.jl"))   # classify_spinor_phase (validated)

const RUN =
    length(ARGS) >= 1 ? ARGS[1] : error("usage: eu_phase_fingerprint.jl <run_dir> [out.csv]")
const OUT = length(ARGS) >= 2 ? ARGS[2] : joinpath(RUN, "fingerprint_table.csv")
const C1DEF = parse(Float64, get(ENV, "SPINORBEC_PHASE_C1", "NaN"))
# B fallback (µG) for slices where B is a base value, not a scan override.
const BDEF = parse(Float64, get(ENV, "SPINORBEC_PHASE_B_UG", "NaN"))

_ug(s) = 1e6 * parse(Float64, split(String(s))[1])

function _cellkey(ov)
    c1 = get(ov, "pipeline.0.interactions.c1_ratio", missing)
    b = get(ov, "pipeline.0.B.Bz", missing)
    (c1 === missing ? C1DEF : Float64(c1),
        b === missing ? BDEF : _ug(b),
        Float64(get(ov, "pipeline.0.potential.omega.2", NaN)))
end

pts = sort(
    unique(
        parse.(
            Int,
            [
                m.captures[1] for f in readdir(RUN)
                for m in (match(r"point_(\d+)[._]", f),) if m !== nothing
            ],
        ),
    ),
)
isempty(pts) && error("no point_*.jld2 in $RUN")

open(OUT, "w") do io
    println(
        io, "c1_ratio,B_uG,kappa,gs_seed,E_gs,grad_norm,mF,coh,fluxclosure,chirality,inert,phase"
    )
    for i in pts
        # min-E over ALL seeds present for this point (seed-set agnostic)
        best = nothing
        for f in readdir(RUN)
            m = match(Regex("^point_0*$(i)(?:_(.+))?\\.jld2\$"), f)
            m === nothing && continue
            seed = m.captures[1] === nothing ? "single" : m.captures[1]
            fp_ = joinpath(RUN, f)
            E = try
                JLD2.load(fp_, "energy")
            catch
                ; continue
            end
            (best === nothing || E < best.E) && (best = (; E, f=fp_, s=seed))
        end
        best === nothing && continue
        psi = ComplexF64.(JLD2.load(best.f, "psi"))
        n = Int.(JLD2.load(best.f, "grid_n_points"))
        box = Float64.(JLD2.load(best.f, "grid_box_size"))
        ov = JLD2.load(best.f, "override")
        gnorm = try
            JLD2.load(best.f, "grad_norm")
        catch
            ; NaN
        end
        grid = make_grid(GridConfig(Tuple(n), Tuple(box)))
        fp = spinor_fingerprint(psi, grid, 6)
        c1, B, k = _cellkey(ov)
        ph = classify_spinor_phase(fp)
        println(
            io,
            join(
                (c1, B, k, best.s, best.E, gnorm, fp.mF, fp.coh,
                    fp.fluxclosure, fp.chirality, String(fp.inert), ph), ","),
        )
    end
end
println("wrote ", OUT)
