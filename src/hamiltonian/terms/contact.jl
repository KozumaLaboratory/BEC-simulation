# --- Contact-interaction family: DensityC0Term + SpinC1Term + TensorTerm ---
#
# Three pieces of the rotationally-symmetric contact interaction:
#
#   DensityC0Term : H = (c0/2) n²                  (rank-0 channel)
#   SpinC1Term    : H = (c1/2) |F|²                (rank-1 channel)
#   TensorTerm    : H = (c2/2) |A|² + Σ c_S P_S    (rank-≥2 channels; KNOWN-LIMIT op=0)
#
# c0 sets the scalar contact (always present), c1 picks polar (>0) / FM
# (<0) ground state, c2 and higher tensor coefficients are zero in the
# Eu Phase-1 model (c0+c1+DDI) — see the [[sbi-telos-tensor-gradient-prereq]]
# memo for the forward note on lifting Tensor's apply_operator KNOWN-LIMIT
# when SBI structure-inference is run on all 7 channels.
#
# Consolidation rationale: all three are auto-selected together via
# `make_workspace` (the c₀/c₁ path vs scattering-lengths path branches on
# the same interactions Dict). Grouping the trinity methods in one file
# keeps the contact-channel audit fit in a single screen.

# ============================================================================
# DensityC0Term — H = (c0/2) · n²
# ============================================================================

"""Density (c0) interaction term `H = (c0/2)·n²`."""
struct DensityC0Term <: HamTerm
    c0::Float64
end

@inline _density_sign(term::DensityC0Term) = +term.c0   # positive c0 = repulsive

function apply_operator!(out::AbstractArray, term::DensityC0Term, ws, psi::AbstractArray)
    # Mean-field nonlinear: δE/δψ̄[I, c] = c0 · n(r) · ψ[I, c] where n(r) = Σ_c' |ψ[r, c']|².
    N = ndims(psi) - 1
    D = size(psi, N + 1)
    n_density = total_density(psi, N)
    @inbounds for c in 1:D
        idx = ntuple(_ -> :, Val(N))
        view(out, idx..., c) .= term.c0 .* n_density .* view(psi, idx..., c)
    end
    return out
end

function energy_contribution(term::DensityC0Term, psi::AbstractArray{<:Complex}, ws)
    # Mean-field: E = (1/2) · Re⟨ψ, apply_op(ψ)⟩ · dV = (c0/2)·∫n²·dV.
    out = similar(psi)
    fill!(out, zero(eltype(out)))
    apply_operator!(out, term, ws, psi)
    return 0.5 * real(dot(vec(psi), vec(out))) * cell_volume(ws.grid)
end

function add_gradient!(grad, term::DensityC0Term, psi, ws)
    buf = similar(psi)
    fill!(buf, zero(eltype(buf)))
    apply_operator!(buf, term, ws, psi)
    grad .+= buf
    return nothing
end

# Context-aware specialisation: reuse ctx.n_density to skip the recompute.
function add_gradient!(grad, term::DensityC0Term, psi, ws, ctx::GradientContext)
    N = ndims(psi) - 1
    D = ws.spin_matrices.system.n_components
    @inbounds for c in 1:D
        idx = ntuple(_ -> :, Val(N))
        view(grad, idx..., c) .+= term.c0 .* ctx.n_density .* view(psi, idx..., c)
    end
    return nothing
end

function apply_step!(term::DensityC0Term, psi, dt::Real, imaginary_time::Bool, ws)
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

"""
    _density_interaction_energy(psi, c0, n_comp, ndim, n_pts, dV)

`E_c0 = (c0/2) ∫ n²·dV`. Body used by `_energy_decomposition_cpu`.
Fuses density build + square-sum in one pass — avoids the
`n_pts`-sized temporary `total_density` materialises (~2.3 KB per call
at 16² — the bulk of `energy_decomposition`'s per-call alloc on small grids).
"""
function _density_interaction_energy(psi, c0, n_comp, ndim, n_pts, dV)
    s = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        nI = 0.0
        for c in 1:n_comp
            nI += abs2(psi[I, c])
        end
        s += nI * nI
    end
    0.5 * c0 * s * dV
end

"""
    _grad_c0_density!(grad, psi, ws, n_density, n_pts, D, ::Val{N})

Add c0·n·ψ contribution to `grad`. Body used by `energy_gradient!`,
shares `n_density` scratch with sibling terms (LHY) for performance.
"""
function _grad_c0_density!(grad, psi, ws, n_density, n_pts, D, ::Val{N}) where {N}
    c0 = ws.interactions[0]
    is_active(c0) || return nothing
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= c0 .* n_density .* view(psi, idx...)
    end
    nothing
end

sign_oracle(::Type{DensityC0Term}) = (
    name="DensityC0Term: +c0 ⇒ E_c0 > 0 (repulsive contact)",
    predicate=function (psi, ws)
        E = energy_contribution(DensityC0Term(), psi, ws)
        c0 = ws.interactions[0]
        return c0 >= 0.0 ? E >= -1e-12 : E <= 1e-12
    end,
)

# ============================================================================
# SpinC1Term — H = (c1/2) |F|²
# ============================================================================

"""Spin (c1) interaction `H = (c1/2)·|F|²`. Sign of c1 picks polar/FM."""
struct SpinC1Term <: HamTerm
    c1::Float64
end

@inline _spin_sign(term::SpinC1Term) = +term.c1

function apply_step!(term::SpinC1Term, psi, dt::Real, imaginary_time::Bool, ws)
    is_active(term.c1) || return nothing
    apply_spin_mixing_step!(
        psi, ws.spin_matrices, term.c1, dt, ndims(psi) - 1;
        imaginary_time=imaginary_time,
    )
    return nothing
end

"""
    _spin_interaction_energy(psi, sm, c1, n_comp, ndim, n_pts, dV)

`E_c1 = (c1/2) ∫ |F(r)|² d³r` where `F = ψ̄·F̂·ψ`. Manual reduction
loop inlines `fx² + fy² + fz²` — avoids the `n_pts`-shaped temporary
that broadcast materialised pre-2026-05-23.
"""
function _spin_interaction_energy(psi, sm, c1, n_comp, ndim, n_pts, dV)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    s = 0.0
    @inbounds for i in eachindex(fx, fy, fz)
        s += fx[i]^2 + fy[i]^2 + fz[i]^2
    end
    0.5 * c1 * s * dV
end

"""
    _grad_c1_spin!(grad, psi, ws, fx, fy, fz, n_pts, D, ::Val{N})

`∂E_c1/∂ψ*_m`: F_z·m·F_z (diagonal) + (F±·F∓·F_z)/2 (tridiagonal).
Caller pre-populates `fx, fy, fz` scratch via `_compute_spin_density!`
or passes ctx.fx/fy/fz. Active iff `is_active(c1)`.
"""
function _grad_c1_spin!(grad, psi, ws, fx, fy, fz, n_pts, D, ::Val{N}) where {N}
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

function apply_operator!(out::AbstractArray, term::SpinC1Term, ws, psi::AbstractArray)
    fill!(out, zero(eltype(out)))
    is_active(term.c1) || return out
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    fx = similar(psi, ComplexF64, n_pts...)
    fy = similar(psi, ComplexF64, n_pts...)
    fz = similar(psi, ComplexF64, n_pts...)
    _grad_c1_spin!(out, psi, ws, fx, fy, fz, n_pts, D, Val(N))
    return out
end

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
    _grad_c1_spin!(grad, psi, ws, ctx.fx, ctx.fy, ctx.fz, ctx.n_pts, D, Val(N))
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

# ============================================================================
# TensorTerm — singlet-pair (c2) + higher-rank tensor channels (c4, c6, …)
# ============================================================================
#
# Covers c2 singlet-pair and higher-rank tensor channels via the
# existing tensor_cache + _singlet_pair_energy paths. Gradient is NOT
# implemented in the legacy `energy_gradient!` (LBFGS warns and falls
# back to ITP for these); we mirror that limitation here.

"""Tensor (singlet-pair + higher-rank) spin-spin interaction."""
struct TensorTerm <: HamTerm end

function apply_step!(::TensorTerm, psi, dt::Real, imaginary_time::Bool, ws)
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

"""
    _singlet_pair_energy(psi, F, c2, ndim, n_pts, dV)

`E_pair = (c2/2) ∫ |A(r)|² d³r` where `A(r)` is the S=0 singlet-pair
amplitude. Active iff `is_active(c2)`. Sign: c2>0 polar suppresses
singlet; c2<0 FM amplifies.
"""
function _singlet_pair_energy(psi, F, c2, ndim, n_pts, dV)
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
        E += _singlet_pair_energy(psi, F, c2, N, n_pts, dV)
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

# Operator-trinity KNOWN-LIMIT: TensorTerm gradient (c2/c4/...) was never
# implemented in legacy `energy_gradient!`. LBFGS falls back to ITP for
# tensor-active configurations. apply_operator! is nil to match — propagator
# (apply_step!) is the active path for ITP.
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
