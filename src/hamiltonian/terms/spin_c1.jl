# --- SpinC1Term HamTerm ---
#
# H_c1 = (c1/2) ∫ |F|² d³r where F = ψ̄·F̂·ψ is the spin density vector.
# Sign of c1 picks polar (>0) or FM (<0) ground state.

"""Spin (c1) interaction `H = (c1/2)·|F|²`. Sign of c1 picks polar/FM."""
struct SpinC1Term <: HamTerm
    c1::Float64
end

@inline _spin_sign(term::SpinC1Term) = +term.c1

function apply_step!(term::SpinC1Term, psi, dt::Real, imaginary_time::Bool, ws)
    # Delegate to existing spin-mixing step.
    is_active(term.c1) || return nothing
    apply_spin_mixing_step!(
        psi, ws.spin_matrices, term.c1, dt, ndims(psi) - 1;
        imaginary_time=imaginary_time,
    )
    return nothing
end

# ============================================================================
# Canonical energy + gradient kernels. Propagator `apply_spin_mixing_step!`
# stays in `interactions/spin_mixing.jl` — that file owns the D=3 Rodrigues
# fast path + general-D Euler batched-gemm rotation, with measured 2-3×
# speedup at D=3 that splitting would lose.
# ============================================================================

"""
    _spin_interaction_energy_core(psi, sm, c1, n_comp, ndim, n_pts, dV)

`E_c1 = (c1/2) ∫ |F(r)|² d³r` where `F = ψ̄·F̂·ψ` is the spin density.
Manual reduction loop inlines `fx² + fy² + fz²` — avoids the
`n_pts`-shaped temporary that broadcast materialised pre-2026-05-23.
"""
function _spin_interaction_energy_core(psi, sm, c1, n_comp, ndim, n_pts, dV)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    s = 0.0
    @inbounds for i in eachindex(fx, fy, fz)
        s += fx[i]^2 + fy[i]^2 + fz[i]^2
    end
    0.5 * c1 * s * dV
end

"""
    _grad_c1_spin_core!(grad, psi, ws, fx, fy, fz, n_pts, D, ::Val{N})

`∂E_c1/∂ψ*_m`: F_z·m·F_z (diagonal) + (F±·F∓·F_z)/2 (tridiagonal).
Caller pre-populates `fx, fy, fz` scratch via `_compute_spin_density!`
or passes ctx.fx/fy/fz. Active iff `is_active(c1)`.
"""
function _grad_c1_spin_core!(grad, psi, ws, fx, fy, fz, n_pts, D, ::Val{N}) where {N}
    c1 = ws.interactions[1]
    is_active(c1) || return nothing
    sm = ws.spin_matrices
    F = ws.atom.F
    _compute_spin_density!(fx, fy, fz, psi, sm, Val(D), N, n_pts)
    # Fz part (diagonal)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        m = Float64(F - (c - 1))
        view(grad, idx...) .+= c1 .* m .* fz .* view(psi, idx...)
    end
    # F+/F− parts (tridiagonal)
    for c in 2:D
        idx_c = _component_slice(N, n_pts, c)
        idx_cm1 = _component_slice(N, n_pts, c - 1)
        fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
        view(grad, idx_cm1...) .+= c1 .* 0.5 .* fp .* (fx .- im .* fy) .* view(psi, idx_c...)
        view(grad, idx_c...) .+= c1 .* 0.5 .* fp .* (fx .+ im .* fy) .* view(psi, idx_cm1...)
    end
    nothing
end

# ============================================================================
# Trinity authoritative kernel: apply_operator!
# H_c1 mean-field: δE/δψ̄ = c1·(F_z·m + (F_+·F_- + F_-·F_+)/2) summed channel-wise.
# `_grad_c1_spin_core!` already implements this; apply_operator! is a fill-then-call.
# ============================================================================

function apply_operator!(out::AbstractArray, term::SpinC1Term, ws, psi::AbstractArray)
    fill!(out, zero(eltype(out)))
    is_active(term.c1) || return out
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    fx = similar(psi, ComplexF64, n_pts...)
    fy = similar(psi, ComplexF64, n_pts...)
    fz = similar(psi, ComplexF64, n_pts...)
    _grad_c1_spin_core!(out, psi, ws, fx, fy, fz, n_pts, D, Val(N))
    return out
end

# ============================================================================
# Derived: energy + gradient from the single source.
# ============================================================================

function energy_contribution(term::SpinC1Term, psi::AbstractArray{<:Complex}, ws)
    # Mean-field: E = (1/2)·Re⟨ψ, apply_op(ψ)⟩·dV = (c1/2)·∫|F|²·dV
    out = similar(psi)
    fill!(out, zero(eltype(out)))
    apply_operator!(out, term, ws, psi)
    return 0.5 * real(dot(vec(psi), vec(out))) * cell_volume(ws.grid)
end

function add_gradient!(grad, term::SpinC1Term, psi, ws)
    buf = similar(psi)
    fill!(buf, zero(eltype(buf)))
    apply_operator!(buf, term, ws, psi)
    grad .+= buf
    return nothing
end

# Context-aware: borrow ctx.fx / ctx.fy / ctx.fz to avoid 3× allocation.
function add_gradient!(grad, term::SpinC1Term, psi, ws, ctx::GradientContext)
    N = ndims(psi) - 1
    D = ws.spin_matrices.system.n_components
    _grad_c1_spin_core!(grad, psi, ws, ctx.fx, ctx.fy, ctx.fz, ctx.n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{SpinC1Term}) = (
    name="SpinC1Term: sign(c1) matches sign(E_c1)",
    predicate=function (psi, ws)
        E = energy_contribution(SpinC1Term(ws.interactions[1]), psi, ws)
        c1 = ws.interactions[1]
        return c1 >= 0.0 ? E >= -1e-12 : E <= 1e-12
    end,
)
