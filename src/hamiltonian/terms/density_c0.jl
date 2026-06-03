# --- DensityC0 HamTerm ---
#
# H_c0 = (c0/2) ∫ n² d³r. The mean-field self-coupling per spin
# component is `c0·n(r)·ψ(r)` in the GP equation. Universal positive
# c0 = repulsive contact interaction.

"""Density (c0) interaction term `H = (c0/2)·n²`."""
struct DensityC0 <: HamTerm
    c0::Float64
end

@inline _density_sign(term::DensityC0) = +term.c0   # positive c0 = repulsive

function apply_step!(term::DensityC0, psi, dt::Real, imaginary_time::Bool, ws)
    n = total_density(psi, ndims(psi) - 1)
    D = size(psi, ndims(psi))
    if imaginary_time
        for c in 1:D
            view(psi, ntuple(_ -> :, Val(ndims(psi) - 1))..., c) .*= exp.(.-(term.c0 .* n) .* dt)
        end
    else
        for c in 1:D
            view(psi, ntuple(_ -> :, Val(ndims(psi) - 1))..., c) .*= cis.(.-(term.c0 .* n) .* dt)
        end
    end
    return nothing
end

function energy_contribution(term::DensityC0, psi::AbstractArray{<:Complex}, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    return _density_interaction_energy(psi, term.c0, n_comp, N, n_pts, cell_volume(ws.grid))
end

function add_gradient!(grad, term::DensityC0, psi, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    n_density = total_density(psi, N)
    _grad_c0_density!(grad, psi, ws, n_density, n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{DensityC0}) = (name="DensityC0: +c0 repulsive", predicate=(_, _) -> true)
