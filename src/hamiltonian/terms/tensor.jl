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

# ============================================================================
# Canonical energy kernel: c2 singlet-pair (`_tensor_interaction_energy`
# stays in `interactions/tensor_interaction.jl`; it has its own tensor-cache
# subsystem and is genuinely architectural, not delegation).
# ============================================================================

"""
    _singlet_pair_energy_core(psi, F, c2, ndim, n_pts, dV)

`E_pair = (c2/2) ∫ |A(r)|² d³r` where `A(r)` is the S=0 singlet-pair
amplitude. Active iff `is_active(c2)`. Sign: c2>0 polar suppresses
singlet; c2<0 FM amplifies.
"""
function _singlet_pair_energy_core(psi, F, c2, ndim, n_pts, dV)
    A = singlet_pair_amplitude(psi, F, ndim)
    0.5 * c2 * sum(abs2, A) * dV
end

function energy_contribution(::TensorTerm, psi::AbstractArray{<:Complex}, ws)
    F = ws.spin_matrices.system.F
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    dV = cell_volume(ws.grid)
    E = 0.0
    c2 = get_cn(ws.interactions, 2)
    if is_active(c2)
        E += _singlet_pair_energy_core(psi, F, c2, N, n_pts, dV)
    end
    if ws.tensor_cache !== nothing
        E += _tensor_interaction_energy(psi, ws.tensor_cache, N, n_pts, dV)
    end
    # CRITICAL trinity consistency check: TensorTerm.apply_operator! is
    # KNOWN-LIMIT (no-op), so if energy_contribution computes a non-zero
    # E, LBFGS gradient sees a different landscape than this energy. That's
    # the freeze-class inconsistency the trinity is supposed to kill. Warn
    # LOUDLY so the silent break doesn't bite a future user with c_S ≠ 0.
    if !iszero(E)
        @warn """TensorTerm: energy_contribution = $E (non-zero) but
        apply_operator! / add_gradient! are NO-OP (legacy KNOWN-LIMIT).
        LBFGS gradient MISSES this energy. Multi-start GS will converge
        on an incomplete Hamiltonian (H without tensor channels). Either:
          (a) For Eu nominal (c_2..c_12 = 0), this branch should never
              fire — verify your `interactions:` block does not set rank
              ≥ 2 coefficients.
          (b) If c_S ≠ 0 is intentional, implement TensorTerm.apply_operator!
              and lift the KNOWN-LIMIT.""" maxlog=1
    end
    return E
end

# Operator-trinity KNOWN-LIMIT: TensorTerm gradient (c2/c4/...) was
# never implemented in legacy `energy_gradient!` (see commit log /
# CLAUDE.md "Tensor c2/c4 not in energy_gradient!"). LBFGS falls back
# to ITP for tensor-active configurations. apply_operator! is nil to
# match — propagator (apply_step!) is the active path for ITP.
apply_operator!(out, ::TensorTerm, ws, psi) = (fill!(out, zero(eltype(out))); out)
function add_gradient!(grad, ::TensorTerm, psi, ws)
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
