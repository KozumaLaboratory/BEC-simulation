# --- Trap HamTerm ---
#
# H_trap = +V_trap(r).  Universal positive potential, no sign
# question. Delegates to the existing diagonal step.

"""External trap potential `H = +V_trap(r)`."""
struct Trap <: HamTerm end

function apply_step!(::Trap, psi, dt::Real, imaginary_time::Bool, ws)
    # V_trap is applied as part of the diagonal step. As a standalone
    # term application: psi *= exp(-V_trap·dt) per voxel (IT) or
    # cis(-V_trap·dt) (RT).
    V = ws.potential_values
    D = size(psi, ndims(psi))
    if imaginary_time
        for c in 1:D
            view(psi, ntuple(_ -> :, Val(ndims(psi) - 1))..., c) .*= exp.(.-V .* dt)
        end
    else
        for c in 1:D
            view(psi, ntuple(_ -> :, Val(ndims(psi) - 1))..., c) .*= cis.(.-V .* dt)
        end
    end
    return nothing
end

function energy_contribution(::Trap, psi::AbstractArray{<:Complex}, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    V = _to_host(ws.potential_values)
    return _trap_energy(psi, V, n_comp, N, n_pts, cell_volume(ws.grid))
end

function add_gradient!(grad, ::Trap, psi, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    _grad_trap!(grad, psi, ws, n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{Trap}) = (name="Trap: positive coupling", predicate=(_, _) -> true)
