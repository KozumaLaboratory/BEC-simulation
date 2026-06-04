# --- Tensor HamTerm ---
#
# Covers c2 singlet-pair and higher-rank tensor channels (c4, c6, ...)
# via the existing tensor_cache + _singlet_pair_energy paths.
# Gradient is NOT implemented in legacy energy_gradient! (LBFGS warns
# and falls back to ITP for these); we mirror that limitation here.

"""Tensor (singlet-pair + higher-rank) spin-spin interaction."""
struct TensorTerm <: HamTerm end

function apply_step!(::TensorTerm, psi, dt::Real, imaginary_time::Bool, ws)
    # Apply singlet-pair (c2) + tensor cache.
    F = ws.spin_matrices.system.F
    N = ndims(psi) - 1
    c2 = get_cn(ws.interactions, 2)
    if is_active(c2)
        apply_singlet_pair_step!(psi, ws.spin_matrices, c2, dt, N; imaginary_time)
    end
    if ws.tensor_cache !== nothing
        apply_tensor_step!(psi, ws.tensor_cache, ws.spin_matrices, dt, N; imaginary_time)
    end
    return nothing
end

function energy_contribution(::TensorTerm, psi::AbstractArray{<:Complex}, ws)
    F = ws.spin_matrices.system.F
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    dV = cell_volume(ws.grid)
    E = 0.0
    c2 = get_cn(ws.interactions, 2)
    if is_active(c2)
        E += _singlet_pair_energy(psi, F, c2, N, n_pts, dV)
    end
    if ws.tensor_cache !== nothing
        E += _tensor_interaction_energy(psi, ws.tensor_cache, N, n_pts, dV)
    end
    return E
end

function add_gradient!(grad, ::TensorTerm, psi, ws)
    # Legacy energy_gradient! does NOT cover tensor terms (LBFGS
    # falls back to ITP). Mirror that limitation; FD-consistency
    # CI test should skip this term explicitly.
    return nothing
end

sign_oracle(::Type{TensorTerm}) = (
    name="TensorTerm: c2 polar singlet ⇒ E_pair ≥ 0; gradient KNOWN-LIMIT",
    predicate=function (psi, ws)
        c2 = get_cn(ws.interactions, 2)
        E = energy_contribution(TensorTerm(), psi, ws)
        is_active(c2) || return isfinite(E)
        return c2 >= 0.0 ? E >= -1e-12 : E <= 1e-12
    end,
)
