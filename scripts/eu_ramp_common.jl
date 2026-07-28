# Shared helpers for the Eu weak-field ramp drivers (eu_adiabatic_ramp_protocol.jl,
# eu_kappa_ramp_protocol.jl, eu_adiabatic_window.jl).
#
# These two are here because they are PHYSICS statements, not boilerplate: the
# definition of the order parameter ⟨F⊥⟩ and the seed/preset consistency check.
# Duplicating either across drivers is how one copy drifts while the others stay
# right and every plot still looks plausible.

using SpinorBEC: Units, _spin_expectation_fields, cell_volume
using JLD2: jldopen
using Printf

"""
    spin_scalars(psi, grid) -> (; fz, fperp)

Density-weighted magnetisation per atom: `∫ f_α dV / ∫ n dV` for the axial
component and `∫ |f_⊥| dV / ∫ n dV` for the transverse one. This is the SAME
definition the GS library campaign wrote into its manifests, so ramp endpoints
and library states are directly comparable.

⟨F⊥⟩ (not ⟨F_z⟩) is the order parameter here: at weak field the state lives on a
soft manifold where the axial component is not rotation-invariant.
"""
function spin_scalars(psi::AbstractArray{<:Complex}, grid)
    dV = cell_volume(grid)
    dens = dropdims(sum(abs2, psi; dims=ndims(psi)); dims=ndims(psi))
    fx, fy, fz = _spin_expectation_fields(psi, grid)
    ntot = sum(dens) * dV
    (; fz=sum(fz) * dV / ntot,
        fperp=sum(sqrt.(fx .^ 2 .+ fy .^ 2)) * dV / ntot)
end

"""
    assert_seed_epoch(path, meta; c0, c1, c_dd, p, n_points, box)

Abort unless a library seed's stored parameters match the preset the caller
rebuilt. A silent mismatch puts one parameter epoch's state into another epoch's
Hamiltonian: the seed is then not stationary, and everything measured afterwards
is that transient rather than the ramp.
"""
function assert_seed_epoch(
    path::AbstractString, m::NamedTuple;
    c0::Real, c1::Real, c_dd::Real, p::Real,
    n_points::Tuple, box::Real,
)
    for (name, got, want, tol) in (
        ("c0", m.c0, c0, 1e-8),
        ("c1", m.c1, c1, 1e-8),
        ("c_dd", m.c_dd, c_dd, 1e-8),
        ("zeeman_p", m.p, p, 1e-6),
    )
        rel = abs(got - want) / max(abs(want), 1e-30)
        rel < tol || error("""
            seed/preset mismatch on $name: stored $got vs preset $want (rel $rel).
            The library state was computed with a different parameter epoch — fix
            the preset (n_atoms / box / ω_ref / trap ratios) before ramping.
            seed = $path""")
    end
    (m.n == n_points && all(≈(box), m.box)) ||
        error("seed grid $(m.n) box $(m.box) ≠ requested $n_points / $box\nseed = $path")
    nothing
end

"""Scalar metadata a library ψ file carries (schema written by the GS campaign)."""
seed_meta(path::AbstractString) = jldopen(path, "r") do f
    (; c0=f["c0"], c1=f["c1"], c_dd=f["c_dd"], p=f["zeeman_p"],
        pin=f["pin_bx"], box=f["grid_box_size"], n=f["grid_n_points"])
end
