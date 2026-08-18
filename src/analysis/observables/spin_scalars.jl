# Density-weighted magnetisation scalars — the weak-field Eu ramp order
# parameter. A PHYSICS statement, not boilerplate: this is the single
# definition every ramp driver and the GS library campaign share, so ramp
# endpoints and library states are directly comparable. Duplicating it across
# drivers is how one copy drifts while the others stay right and every plot
# still looks plausible.

export spin_scalars

"""
    spin_scalars(psi, grid) -> (; fz, fperp)

Density-weighted magnetisation per atom: `∫ f_α dV / ∫ n dV` for the axial
component and `∫ |f_⊥| dV / ∫ n dV` for the transverse one.

⟨F⊥⟩ (not ⟨F_z⟩) is the order parameter at weak field: the state lives on a
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
