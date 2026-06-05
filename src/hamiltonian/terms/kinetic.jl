# --- KineticTerm HamTerm + canonical kinetic kernels ---
#
# H_kinetic = (1/2) p² = -(1/2) ∇²  (universal, no sign question).
#
# This file owns the THREE canonical kinetic kernels:
#
#   `_apply_kinetic_step_core!` — RT/IT propagator (batched FFT pair).
#   `_kinetic_energy_core`      — ⟨ψ|H_kin|ψ⟩ for `energy_decomposition`.
#   `_grad_kinetic_core!`       — δE_kin/δψ* for LBFGS.
#
# The legacy entry points (`apply_kinetic_step_batched!` in
# `integrator/propagators.jl`, `_kinetic_energy` in `analysis/energy.jl`,
# `_grad_kinetic!` in `solvers/lbfgs/energy_gradient.jl`) are now one-line
# shims forwarding to these `_core` helpers — caller code is unchanged.
#
# Per-term collapse landed 2026-06-04 PM (see plan c-greedy-blum.md,
# Part B). Bit-identity is preserved (gates in
# `test/oracles/test_term_legacy_equivalence.jl` and
# `test/oracles/test_registry_gradient_parity.jl`).

"""
Universal kinetic energy `H = (1/2) k²` in momentum space.
"""
struct KineticTerm <: HamTerm end

@inline _kinetic_sign() = +0.5  # H = +(1/2)·k²; no user-spec sign question

# ============================================================================
# Canonical kernel: RT/IT propagator (batched FFT pair)
# ============================================================================

"""
    _apply_kinetic_step_core!(psi, cache::BatchedKineticCache)

Apply `exp(-i·dt·k²/2)` (RT) or `exp(-dt·k²/2)` (IT) to `psi` via a
batched per-component FFT. `cache.kinetic_phase_bc` carries the
broadcasted phase shape `(n_pts..., 1)`; the trailing singleton
broadcasts across spin components. This is the single-FFT-plan path
that BatchedKineticCache encodes.
"""
function _apply_kinetic_step_core!(psi, cache::BatchedKineticCache)
    cache.forward * psi
    psi .*= cache.kinetic_phase_bc
    cache.inverse * psi
    nothing
end

# ============================================================================
# Canonical kernel: ⟨ψ|H_kin|ψ⟩
# ============================================================================

"""
    _kinetic_energy_core(psi, grid, plans, fft_buf, n_comp, ndim, n_pts, dV)

Compute kinetic energy by per-component FFT-and-reduction:
`E = (1/2) Σ_c ∫ |k|² |ψ̂_c(k)|² dk`. The manual reduction loop avoids
materialising the `n_pts`-shaped `k_squared .* abs2.(fft_buf)`
temporary every component (saves D × n_pts × 8 B per energy call —
~425 KB per call at 16³ × D=13).
"""
function _kinetic_energy_core(psi, grid, plans, fft_buf, n_comp, ndim, n_pts, dV)
    E = 0.0
    inv_npts = 1.0 / prod(n_pts)
    k_sq = grid.k_squared
    @inbounds for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        fft_buf .= view(psi, idx...)
        plans.forward * fft_buf
        Ec = 0.0
        for i in eachindex(k_sq, fft_buf)
            Ec += k_sq[i] * abs2(fft_buf[i])
        end
        E += Ec * dV * inv_npts
    end
    0.5 * E
end

# ============================================================================
# Canonical kernel: δE_kin/δψ*
# ============================================================================

"""
    _grad_kinetic_core!(grad, psi, ws, fft_buf, k_squared_dev, n_pts, D, ::Val{N})

Add the kinetic contribution to `grad` (BEFORE the outer ×2 Wirtinger
scaling that `energy_gradient!` applies). Per-component FFT round-trip
applying `(1/2) k²` in k-space. Shared `fft_buf` lets the integrator
reuse one ComplexF64 array across all components.
"""
function _grad_kinetic_core!(
    grad, psi, ws, fft_buf, k_squared_dev, n_pts, D, ::Val{N}
) where {N}
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        fft_buf .= view(psi, idx...)
        ws.fft_plans.forward * fft_buf
        fft_buf .*= (0.5 .* k_squared_dev)
        ws.fft_plans.inverse * fft_buf
        view(grad, idx...) .+= fft_buf
    end
    nothing
end

# ============================================================================
# HamTerm interface
# ============================================================================

function apply_step!(::KineticTerm, psi, dt::Real, imaginary_time::Bool, ws)
    _apply_kinetic_step_core!(psi, ws.batched_kinetic)
    return nothing
end

# ============================================================================
# Trinity authoritative kernel: apply_operator!
# H_kin = -½∇² (linear). apply_operator! returns (½k²·ψ̂)→ifft per-voxel.
# Energy = Re⟨ψ, H·ψ⟩·dV; gradient = H·ψ.
# ============================================================================

function apply_operator!(out::AbstractArray, ::KineticTerm, ws, psi::AbstractArray)
    fill!(out, zero(eltype(out)))
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    fft_buf = similar(psi, ComplexF64, n_pts...)
    k_squared_dev = _to_device(ws.backend, ws.grid.k_squared)
    _grad_kinetic_core!(out, psi, ws, fft_buf, k_squared_dev, n_pts, D, Val(N))
    return out
end

function energy_contribution(::KineticTerm, psi::AbstractArray{<:Complex}, ws)
    # Linear: E = Re⟨ψ, H·ψ⟩·dV. Retains the manual reduction form
    # (faster than apply_operator + dot at scale; bit-equivalent for H_kin).
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    dV = cell_volume(ws.grid)
    fft_buf = zeros(ComplexF64, ws.grid.config.n_points)
    return _kinetic_energy_core(
        psi, ws.grid, ws.fft_plans, fft_buf, n_comp, N, n_pts, dV
    )
end

function add_gradient!(grad, ::KineticTerm, psi, ws)
    buf = similar(psi)
    apply_operator!(buf, KineticTerm(), ws, psi)
    grad .+= buf
    return nothing
end

# Context-aware specialisation: borrow ctx.fft_buf instead of allocating.
function add_gradient!(grad, ::KineticTerm, psi, ws, ctx::GradientContext)
    N = ndims(psi) - 1
    D = ws.spin_matrices.system.n_components
    k_squared_dev = _to_device(ws.backend, ws.grid.k_squared)
    _grad_kinetic_core!(grad, psi, ws, ctx.fft_buf, k_squared_dev, ctx.n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{KineticTerm}) = (
    name="KineticTerm: ⟨k²/2⟩ ≥ 0 always",
    predicate=function (psi, ws)
        E = energy_contribution(KineticTerm(), psi, ws)
        return E >= -1e-12  # FFT roundoff floor
    end,
)
