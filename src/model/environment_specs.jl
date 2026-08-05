# --- The setting: moving frame, reduced dimension, open-system baths ---
#
# None of these is a coupling to a field; each changes what the equation of
# motion is. Shared rules and the `_pad3` helper are in `specs.jl`.

export FrameSpec, GeometrySpec, ReservoirSpec

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------

"""
    FrameSpec(; rotating_omega=0.0, spin_rotating_omega=0.0)

The two frame transformations, both of which change `H`.

**Inactive value: `FrameSpec()`** — the lab frame.

**Values here are LAB-frame parameters, not pre-folded effective fields.**
`rotating_omega ≠ 0` costs the potential a centrifugal `−½Ω²r⊥²` and the Zeeman
a Barnett shift `p → p + Ω`; a builder that folded either into `potential` or
`zeeman` would double-count against the same folding inside the workspace
builder. The frame-transform half-term class has already produced a silent
cancellation once and a reverted Coriolis sign once, so the rule is stated here
and not left to be inferred: `potential` and `zeeman` hold what a lab observer
would set, `frame` holds how the frame moves, and the folding happens exactly
once, downstream.

`spin_rotating_omega ≠ 0` requires `ddi.secular` when DDI is active — full DDI's
off-diagonal components Larmor-average to zero only in the secular limit.
`Model`'s constructor enforces the pair, since neither spec alone can see it.

Activity uses `ROTATION_TOL` (1e-15), not the coupling tolerance. That is the
threshold `make_workspace` uses for the centrifugal and Barnett shifts while
using a bare `!= 0.0` for the Coriolis cache in the same function — so a
`Ω = 1e-16` currently gets two of the three. One predicate, one threshold.
"""
struct FrameSpec <: ModelValue
    rotating_omega::Float64
    spin_rotating_omega::Float64

    function FrameSpec(rotating_omega::Float64, spin_rotating_omega::Float64)
        isfinite(rotating_omega) && isfinite(spin_rotating_omega) ||
            throw(ArgumentError("frame rates must be finite"))
        new(is_active(rotating_omega, ROTATION_TOL) ? rotating_omega : 0.0,
            is_active(spin_rotating_omega, ROTATION_TOL) ? spin_rotating_omega : 0.0)
    end
end

FrameSpec(; rotating_omega::Real=0.0, spin_rotating_omega::Real=0.0) =
    FrameSpec(Float64(rotating_omega), Float64(spin_rotating_omega))

# ---------------------------------------------------------------------------
# geometry
# ---------------------------------------------------------------------------

"""
    GeometrySpec(; quasi_2d=false, l_z=0.0, absorbing=AbsorbingBoundary(0.0,0.0,2))

Reduced-dimension confinement and the absorbing edge — the two things that act
on the field without being Hamiltonian terms of their own.

**Inactive value: `GeometrySpec()`** — no quasi-2-D reduction, no absorber.

`quasi_2d` is genuinely physics: it rescales every contact coupling by
`1/(√(2π) l_z)`. Whether a model's `interactions.c*` are pre- or post-rescale is
invisible in the type, so the rule is fixed here: **they are the 3-D values, and
the rescale is applied once, downstream, exactly as `make_workspace` does it.**
The DDI half of the same physical confinement lives in `DDISpec` next to the
kernel it parameterises.

`AbsorbingBoundary` (`sim_fft.jl:118`) is reused verbatim — it is already
concrete, non-parametric and immutable. `strength = 0` is its inactive value,
matching what `make_workspace` tests, so no `Union{Nothing,…}` is needed.

A leak worth naming: the absorbing *mask* is built from this spec **and the
timestep** (`compute_absorbing_mask(grid, ab, sim_params.dt)`). It is therefore
the one physics object a `Model` cannot resolve on its own — `dt` is a method
parameter. The spec is complete; the materialised mask is not derivable from it
alone.
"""
struct GeometrySpec <: ModelValue
    quasi_2d::Bool
    l_z::Float64
    absorbing::AbsorbingBoundary

    function GeometrySpec(quasi_2d::Bool, l_z::Float64, absorbing::AbsorbingBoundary)
        _finite_or_throw(absorbing.strength, "geometry.absorbing.strength")
        _finite_or_throw(absorbing.width, "geometry.absorbing.width")
        quasi_2d && !(l_z > 0) &&
            throw(ArgumentError("quasi_2d needs l_z > 0 (transverse oscillator length); got $l_z"))
        quasi_2d || (l_z = 0.0)
        ab = if is_active(absorbing.strength)
            absorbing.width > 0 ||
                throw(ArgumentError("absorbing boundary needs width > 0; got $(absorbing.width)"))
            absorbing.power >= 1 ||
                throw(ArgumentError("absorbing boundary needs power >= 1; got $(absorbing.power)"))
            absorbing
        else
            AbsorbingBoundary(0.0, 0.0, 2)
        end
        new(quasi_2d, l_z, ab)
    end
end

GeometrySpec(; quasi_2d::Bool=false, l_z::Real=0.0,
    absorbing::AbsorbingBoundary=AbsorbingBoundary(0.0, 0.0, 2)) = GeometrySpec(
    quasi_2d, Float64(l_z), absorbing)

# ---------------------------------------------------------------------------
# reservoir
# ---------------------------------------------------------------------------

"""
    ReservoirSpec(; sgpe_gamma=0.0, sgpe_temperature=0.0, sgpe_mu=0.0, sgpe_k_cut=0.0,
                    projection_k_cut=0.0, projection_smooth=0.0, photon_rate=0.0)

Open-system couplings: the SGPE/SPGPE growth reservoir, the projected-GP energy
cutoff, and photon-scattering heating.

**Inactive value: `ReservoirSpec()`** — a closed system.

**This is a 15th slot the doc's sketch does not have, and it is physics.** The
three YAML blocks it replaces (`sgpe:`, `projected_gp:`, `photon_scattering:`)
add terms to the equation of motion — they change the answer, not the schedule —
and they fit none of the fourteen. A model that omits them is silently
incomplete for every SPGPE run, and two runs differing only in `sgpe.gamma`
would take the same content id.

**Seeds are deliberately absent.** A stochastic seed selects a *realisation*, not
a physics; it belongs with the initial state, alongside `noise_seed`. So does
the callback stride (`every:`): applying a continuous damping in discrete kicks
is a discretisation of the same physics, exactly as `dt` is, and belongs to the
method.
"""
struct ReservoirSpec <: ModelValue
    sgpe_gamma::Float64
    sgpe_temperature::Float64
    sgpe_mu::Float64
    sgpe_k_cut::Float64
    projection_k_cut::Float64
    projection_smooth::Float64
    photon_rate::Float64

    function ReservoirSpec(sgpe_gamma::Float64, sgpe_temperature::Float64, sgpe_mu::Float64,
        sgpe_k_cut::Float64, projection_k_cut::Float64, projection_smooth::Float64,
        photon_rate::Float64)
        all(
            isfinite,
            (sgpe_gamma, sgpe_temperature, sgpe_mu, sgpe_k_cut,
                projection_k_cut, projection_smooth, photon_rate),
        ) ||
            throw(ArgumentError("reservoir parameters must be finite"))
        sgpe_gamma >= 0 || throw(ArgumentError("sgpe_gamma must be >= 0; got $sgpe_gamma"))
        photon_rate >= 0 || throw(ArgumentError("photon_rate must be >= 0; got $photon_rate"))
        g, T, mu, kc = if is_active(sgpe_gamma)
            (sgpe_gamma, sgpe_temperature, sgpe_mu, sgpe_k_cut)
        else
            (0.0, 0.0, 0.0, 0.0)
        end
        pk, ps = is_active(projection_k_cut) ? (projection_k_cut, projection_smooth) : (0.0, 0.0)
        new(g, T, mu, kc, pk, ps, photon_rate)
    end
end

ReservoirSpec(; sgpe_gamma::Real=0.0, sgpe_temperature::Real=0.0, sgpe_mu::Real=0.0,
    sgpe_k_cut::Real=0.0, projection_k_cut::Real=0.0, projection_smooth::Real=0.0,
    photon_rate::Real=0.0) = ReservoirSpec(Float64(sgpe_gamma), Float64(sgpe_temperature),
    Float64(sgpe_mu), Float64(sgpe_k_cut), Float64(projection_k_cut),
    Float64(projection_smooth), Float64(photon_rate))
