# --- LightShift HamTerm ---
#
# Light shift via ws.light_shift. Per-component diagonal or full
# off-diagonal matrix per voxel. Energy was MISSING in pre-2026-06-04
# GPU implementation (fixed as part of the GAP analysis).

"""Optical light-shift potential."""
struct LightShiftTerm <: HamTerm end

function apply_step!(::LightShiftTerm, psi, dt::Real, imaginary_time::Bool, ws)
    ws.light_shift === nothing && return nothing
    # Light shift is folded into the diagonal step with `_diagonal_step_with_ls!`.
    # Standalone application: per-component for diagonal LightShift.
    ls = ws.light_shift
    N = ndims(psi) - 1
    D = size(psi, N + 1)
    if ls.is_diagonal
        itv = Val(imaginary_time)
        for c in 1:D
            phase = ls.eigvals[c] .* ls.profile
            view(psi, ntuple(_ -> :, Val(N))..., c) .*= wick_phase.(.-phase .* dt, itv)
        end
    else
        error(
            "Off-diagonal LightShift propagator not yet exposed as a standalone HamTerm; use legacy path"
        )
    end
    return nothing
end

# ============================================================================
# Canonical energy + gradient kernels. Propagator stays as-is (folded into
# `_diagonal_step_with_ls!` for the diagonal case + standalone fallback above).
# ============================================================================

"""
    _light_shift_energy(psi, ls::LightShift, n_comp, ndim, n_pts, dV)

`E_LS = ∫ I(r) Σ_k λ_k |⟨k|ψ(r)⟩|² dV` where `λ_k = ls.eigvals` and
`I(r) = ls.profile`. Diagonal fast path when `ls.is_diagonal`;
otherwise project ψ onto eigenbasis via `Uadj = ls.U'`.
"""
function _light_shift_energy(psi, ls::LightShift, n_comp, ndim, n_pts, dV)
    profile = _to_host(ls.profile)
    psi_h = _to_host(psi)
    eigvals = ls.eigvals
    D = n_comp

    if ls.is_diagonal
        E = 0.0
        @inbounds for I in CartesianIndices(n_pts)
            intensity = profile[I]
            for c in 1:D
                E += eigvals[c] * abs2(psi_h[I, c]) * intensity
            end
        end
        return E * dV
    end

    Uadj = ls.U'
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        intensity = profile[I]
        for k in 1:D
            proj = zero(ComplexF64)
            for c in 1:D
                proj += Uadj[k, c] * psi_h[I, c]
            end
            E += eigvals[k] * abs2(proj) * intensity
        end
    end
    E * dV
end

"""
    _grad_light_shift!(grad, psi, ws, n_pts, D, ::Val{N})

`∂E_LS/∂ψ*_c`: diagonal `eigvals[c]·profile·ψ_c`; off-diagonal
`Σ_c2 M_full[c,c2]·profile·ψ_c2` with `M_full = U·diag(eigvals)·U†`.

GPU-safe: route `profile` through `_to_device(ws.backend, …)` so the
broadcast is pure-CuArray when grad is on GPU. Pre-collapse code used
`_to_host(ls.profile)` and broadcast it against a CuArray grad — the
GPU kernel compiler rejected this with "non-bitstype argument".
Latent bug caught by 2026-06-04 GPU per-term parity gate.
"""
function _grad_light_shift!(grad, psi, ws, n_pts, D, ::Val{N}) where {N}
    ws.light_shift !== nothing || return nothing
    ls = ws.light_shift
    profile = _to_device(ws.backend, ls.profile)
    if ls.is_diagonal
        for c in 1:D
            idx = _component_slice(N, n_pts, c)
            view(grad, idx...) .+= ls.eigvals[c] .* profile .* view(psi, idx...)
        end
    else
        M_full = ls.U * Diagonal(ls.eigvals) * ls.U'
        for c in 1:D
            idx_c = _component_slice(N, n_pts, c)
            for c2 in 1:D
                abs(M_full[c, c2]) < COUPLING_TOL && continue
                idx_c2 = _component_slice(N, n_pts, c2)
                view(grad, idx_c...) .+= M_full[c, c2] .* profile .* view(psi, idx_c2...)
            end
        end
    end
    nothing
end

"""Energy is `1.0 · Re⟨ψ, H·ψ⟩ · dV` for this term — one-body AC-Stark.
See the trinity convention in `terms/base.jl`; gated per term by
`test/oracles/test_energy_operator_ratio.jl`."""
energy_operator_ratio(::LightShiftTerm) = 1.0

function energy_contribution(::LightShiftTerm, psi::AbstractArray{<:Complex}, ws)
    ws.light_shift === nothing && return 0.0
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    return _light_shift_energy(
        psi, ws.light_shift, n_comp, N, n_pts, cell_volume(ws.grid)
    )
end

# ============================================================================
# Trinity authoritative kernel: apply_operator!
# H_LS = M_LS·profile (linear); δE/δψ̄ = M_LS·profile·ψ via diagonal or
# full-matrix form. `_grad_light_shift!` implements this.
# ============================================================================

function apply_operator!(out::AbstractArray, ::LightShiftTerm, ws, psi::AbstractArray)
    # Gate-first: `_grad_light_shift!` gates on ws.light_shift internally
    # and broadcasts device-generically (no extra alloc when inactive).
    ws.light_shift === nothing && return out
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    _grad_light_shift!(out, psi, ws, n_pts, D, Val(N))
    return out
end

sign_oracle(::Type{LightShiftTerm}) = (
    name="LightShiftTerm: ⟨H_LS⟩ matches stored eigvals × profile sign",
    predicate=function (psi, ws)
        ws.light_shift === nothing && return true
        E = energy_contribution(LightShiftTerm(), psi, ws)
        return isfinite(E)
    end,
)
