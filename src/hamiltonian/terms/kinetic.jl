# --- KineticTerm: H_kin = -½∇² ---
#
# Single source of truth for the three kinetic kernels:
#   apply_kinetic_step_batched! — RT/IT propagator (batched FFT pair)
#   _kinetic_energy             — ⟨ψ|H_kin|ψ⟩
#   _grad_kinetic!              — δE_kin/δψ*
# All three are also reachable via the trinity dispatch
# (apply_step! / energy_contribution / apply_operator! / add_gradient!).

"""
Universal kinetic energy `H = (1/2) k²` in momentum space.
"""
struct KineticTerm <: HamTerm end

@inline _kinetic_sign() = +0.5  # H = +(1/2)·k²; no user-spec sign question

# ============================================================================
# Canonical kernel: RT/IT propagator (batched FFT pair)
# ============================================================================

"""
    apply_kinetic_step_batched!(psi, cache::BatchedKineticCache)

Apply `exp(-i·dt·k²/2)` (RT) or `exp(-dt·k²/2)` (IT) to `psi` via a
batched per-component FFT. `cache.kinetic_phase_bc` carries the
broadcasted phase shape `(n_pts..., 1)`; the trailing singleton
broadcasts across spin components. This is the single-FFT-plan path
that BatchedKineticCache encodes.
"""
function apply_kinetic_step_batched!(psi, cache::BatchedKineticCache)
    cache.forward * psi
    psi .*= cache.kinetic_phase_bc
    cache.inverse * psi
    nothing
end

# ============================================================================
# Canonical kernel: ⟨ψ|H_kin|ψ⟩
# ============================================================================

"""
    _kinetic_energy(psi, grid, plans, fft_buf, n_comp, ndim, n_pts, dV)

Compute kinetic energy by per-component FFT-and-reduction:
`E = (1/2) Σ_c ∫ |k|² |ψ̂_c(k)|² dk`. The manual reduction loop avoids
materialising the `n_pts`-shaped `k_squared .* abs2.(fft_buf)`
temporary every component (saves D × n_pts × 8 B per energy call —
~425 KB per call at 16³ × D=13).
"""
function _kinetic_energy(psi, grid, plans, fft_buf, n_comp, ndim, n_pts, dV)
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
    _grad_kinetic!(grad, psi, ws, fft_buf, k_squared_dev, n_pts, D, ::Val{N})

Add the kinetic contribution to `grad` (BEFORE the outer ×2 Wirtinger
scaling that `energy_gradient!` applies). Per-component FFT round-trip
applying `(1/2) k²` in k-space. Shared `fft_buf` lets the integrator
reuse one ComplexF64 array across all components.
"""
function _grad_kinetic!(
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
    apply_kinetic_step_batched!(psi, ws.batched_kinetic)
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
    _grad_kinetic!(out, psi, ws, fft_buf, k_squared_dev, n_pts, D, Val(N))
    return out
end

function energy_contribution(::KineticTerm, psi::AbstractArray{<:Complex}, ws)
    # Linear: E = Re⟨ψ, H·ψ⟩·dV. Retains the manual reduction form
    # (faster than apply_operator + dot at scale; bit-equivalent for H_kin).
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    dV = cell_volume(ws.grid)
    # Device-aware buffer: matches psi's device so the FFT plan (also
    # ws.fft_plans, matching ws.state.psi's device) operates correctly.
    fft_buf = similar(psi, ComplexF64, ws.grid.config.n_points)
    return _kinetic_energy(
        psi, ws.grid, ws.fft_plans, fft_buf, n_comp, N, n_pts, dV
    )
end

function add_gradient!(grad, ::KineticTerm, psi, ws)
    buf = similar(psi)
    apply_operator!(buf, KineticTerm(), ws, psi)
    grad .+= buf
    return nothing
end

# Context-aware energy: borrow ctx.fft_buf instead of allocating the
# 1.1 MB complex buffer per call (P1).
function energy_contribution(
    ::KineticTerm, psi::AbstractArray{<:Complex}, ws, ctx::EnergyContext
)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    return _kinetic_energy(
        psi, ws.grid, ctx.plans, ctx.fft_buf, n_comp, N, n_pts, ctx.dV
    )
end

# Context-aware specialisation: borrow ctx.fft_buf instead of allocating.
function add_gradient!(grad, ::KineticTerm, psi, ws, ctx::GradientContext)
    N = ndims(psi) - 1
    D = ws.spin_matrices.system.n_components
    k_squared_dev = _to_device(ws.backend, ws.grid.k_squared)
    _grad_kinetic!(grad, psi, ws, ctx.fft_buf, k_squared_dev, ctx.n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{KineticTerm}) = (
    name="KineticTerm: ⟨k²/2⟩ ≥ 0 always",
    predicate=function (psi, ws)
        E = energy_contribution(KineticTerm(), psi, ws)
        return E >= -1e-12  # FFT roundoff floor
    end,
)
