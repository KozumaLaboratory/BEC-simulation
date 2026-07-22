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

function apply_operator!(out::AbstractArray, term::DensityC0Term, ws, psi::AbstractArray)
    # Mean-field nonlinear: δE/δψ̄[I, c] = c0 · n(r) · ψ[I, c] where n(r) = Σ_c' |ψ[r, c']|².
    N = ndims(psi) - 1
    D = size(psi, N + 1)
    n_density = total_density(psi, N)
    @inbounds for c in 1:D
        idx = ntuple(_ -> :, Val(N))
        view(out, idx..., c) .+= term.c0 .* n_density .* view(psi, idx..., c)
    end
    return out
end

function energy_contribution(term::DensityC0Term, psi::AbstractArray{<:Complex}, ws)
    # Mean-field: E = (1/2) · Re⟨ψ, apply_op(ψ)⟩ · dV = (c0/2)·∫n²·dV.
    # Device-generic derived body; Array specialization below is the
    # fused zero-alloc CPU path (P1), gated by the master oracle.
    out = similar(psi)
    fill!(out, zero(eltype(out)))
    apply_operator!(out, term, ws, psi)
    return 0.5 * real(dot(vec(psi), vec(out))) * cell_volume(ws.grid)
end

function energy_contribution(term::DensityC0Term, psi::Array{<:Complex}, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    return _density_interaction_energy(
        psi, term.c0, n_comp, N, n_pts, cell_volume(ws.grid)
    )
end

# Context-aware specialisation: reuse ctx.n_density to skip the recompute.
function apply_operator!(out, term::DensityC0Term, ws, psi, ctx::GradientContext)
    N = ndims(psi) - 1
    # Whole-array broadcast: n_density reshaped to broadcast over the component
    # axis. One GPU kernel instead of D per-component launches (H100 is
    # broadcast-launch-bound at D=13). Bit-identical elementwise accumulate;
    # zero-alloc on CPU (reshape is a view, broadcast fuses in place).
    n_bc = reshape(ctx.n_density, size(ctx.n_density)..., 1)
    out .+= term.c0 .* n_bc .* psi
    return out
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
    _grad_c1_spin!(grad, psi, ws, c1, fx, fy, fz, n_pts, D, ::Val{N})

`∂E_c1/∂ψ*_m`: F_z·m·F_z (diagonal) + (F±·F∓·F_z)/2 (tridiagonal).
`c1` is the SpinC1Term's own coefficient — passed in, NOT read from
`ws.interactions[1]`. (Pre-2026-06-07 this read ws directly, so the
gradient face silently bypassed `term.c1` while the energy face used
it: a single-source violation that coincided in the registry path —
where term.c1 == ws.interactions[1] — but broke for any term built
with a different c1. Found by the master-oracle self-canary.) Caller
pre-populates `fx, fy, fz` scratch via `_compute_spin_density!` or
passes ctx.fx/fy/fz. Active iff `is_active(c1)`.
"""
function _grad_c1_spin!(grad, psi, ws, c1, fx, fy, fz, n_pts, D, ::Val{N}) where {N}
    is_active(c1) || return nothing
    sm = ws.spin_matrices
    F = ws.atom.F
    _compute_spin_density!(fx, fy, fz, psi, sm, Val(D), N, n_pts)
    sl = ntuple(_ -> Colon(), Val(N))
    fx_bc = reshape(fx, size(fx)..., 1)
    fy_bc = reshape(fy, size(fy)..., 1)
    # Fz part (diagonal) — m-vector over components × fz over space, one broadcast.
    mvec = _to_device(
        ws.backend, reshape(Float64[F - (c - 1) for c in 1:D], ntuple(_ -> 1, Val(N))..., D)
    )
    grad .+= c1 .* mvec .* reshape(fz, size(fz)..., 1) .* psi
    # F± ladder (tridiagonal) — two shifted whole-array broadcasts over the D-1
    # component slice (fp-vector over components). Replaces 2·(D-1) per-component
    # launches. Equal to the loop up to add-reordering (~1e-16).
    fpvec = _to_device(
        ws.backend,
        reshape(
            Float64[fp_ladder_coeff(F, F - c + 1) for c in 2:D], ntuple(_ -> 1, Val(N))..., D - 1
        ),
    )
    view(grad, sl..., 1:(D - 1)) .+=
        (c1 * 0.5) .* fpvec .* (fx_bc .- im .* fy_bc) .* view(psi, sl..., 2:D)
    view(grad, sl..., 2:D) .+=
        (c1 * 0.5) .* fpvec .* (fx_bc .+ im .* fy_bc) .* view(psi, sl..., 1:(D - 1))
    nothing
end

function apply_operator!(out::AbstractArray, term::SpinC1Term, ws, psi::AbstractArray)
    is_active(term.c1) || return out
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    fx = similar(psi, ComplexF64, n_pts...)
    fy = similar(psi, ComplexF64, n_pts...)
    fz = similar(psi, ComplexF64, n_pts...)
    _grad_c1_spin!(out, psi, ws, term.c1, fx, fy, fz, n_pts, D, Val(N))
    return out
end

function energy_contribution(term::SpinC1Term, psi::AbstractArray{<:Complex}, ws)
    # Mean-field: E = (1/2)·Re⟨ψ, apply_op(ψ)⟩·dV = (c1/2)·∫|F|²·dV.
    # Device-generic derived body; the fused CPU body and the
    # ctx-aware overload below are the P1 fast paths.
    out = similar(psi)
    fill!(out, zero(eltype(out)))
    apply_operator!(out, term, ws, psi)
    return 0.5 * real(dot(vec(psi), vec(out))) * cell_volume(ws.grid)
end

function energy_contribution(term::SpinC1Term, psi::Array{<:Complex}, ws)
    is_active(term.c1) || return 0.0
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    return _spin_interaction_energy(
        psi, ws.spin_matrices, term.c1, n_comp, N, n_pts, cell_volume(ws.grid)
    )
end

# Context-aware: reuse the shared fx/fy/fz — zero allocation.
function energy_contribution(
    term::SpinC1Term, psi::AbstractArray{<:Complex}, ws, ctx::EnergyContext
)
    is_active(term.c1) || return 0.0
    s = 0.0
    @inbounds for i in eachindex(ctx.fx, ctx.fy, ctx.fz)
        s += ctx.fx[i]^2 + ctx.fy[i]^2 + ctx.fz[i]^2
    end
    return 0.5 * term.c1 * s * ctx.dV
end

# Context-aware: borrow ctx.fx / ctx.fy / ctx.fz to avoid 3× allocation.
function apply_operator!(out, term::SpinC1Term, ws, psi, ctx::GradientContext)
    N = ndims(psi) - 1
    D = ws.spin_matrices.system.n_components
    _grad_c1_spin!(out, psi, ws, term.c1, ctx.fx, ctx.fy, ctx.fz, ctx.n_pts, D, Val(N))
    return out
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
    # Delegates to the audited production kernels with their REAL
    # signatures. The previous body called `apply_singlet_pair_step!`
    # with a stale (sm, c2) signature and a nonexistent
    # `apply_tensor_step!` — dead-wrong code, latent UndefVarError
    # (arch doc App. A defect 2). `apply_singlet_pair_step!` gates on
    # `is_active(c2)` internally.
    F = ws.spin_matrices.system.F
    N = ndims(psi) - 1
    apply_singlet_pair_step!(psi, ws.interactions, F, Float64(dt), N; imaginary_time)
    if ws.tensor_cache !== nothing
        apply_tensor_interaction_step!(
            psi, ws.tensor_cache, ws.spin_matrices, Float64(dt), N; imaginary_time
        )
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
    return E
end

"""c₂ singlet-pair gradient face (anomalous): `(δE/δψ̄)_c += (c₂/√D) σ_c A₀₀
conj(ψ_{c_pair})`, σ_c=(-1)^{F-m_c}, c_pair=D-c+1. Matches the gated reference
`reference_singlet_pair_apply!`; ACCUMULATES."""
function _accumulate_singlet_pair_operator!(out, psi, F, c2, ndim)
    D = 2F + 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    A = singlet_pair_amplitude(psi, F, ndim)
    coeff = c2 / sqrt(Float64(D))
    @inbounds for I in CartesianIndices(n_pts)
        AI = A[I]
        for c in 1:D
            sgn = singlet_pair_sign(F, F - (c - 1))
            out[I, c] += coeff * sgn * AI * conj(psi[I, D - c + 1])
        end
    end
    out
end

# Gradient face = δE/δψ̄ (the ANOMALOUS pairing operator, conj(ψ); NOT the
# Hartree-Fock mean-field the propagator `apply_step!` builds — different
# decompositions of the same quartic energy). Covers c₂ singlet-pair +
# tensor_cache, mirroring `energy_contribution`. Gated by the FD oracle
# `test_term_consistency` + the reference_rhs c₂ statement.
function apply_operator!(out, ::TensorTerm, ws, psi)
    F = ws.spin_matrices.system.F
    N = ndims(psi) - 1
    c2 = get_cn(ws.interactions, 2)
    active_c2 = is_active(c2)
    has_tensor = ws.tensor_cache !== nothing
    (active_c2 || has_tensor) || return out
    active_c2 && _accumulate_singlet_pair_operator!(out, psi, F, c2, N)
    has_tensor && _accumulate_tensor_operator!(out, psi, ws.tensor_cache, N)
    out
end

sign_oracle(::Type{TensorTerm}) = (
    name="TensorTerm: c2 polar singlet ⇒ E_pair ≥ 0 (gradient implemented)",
    predicate=function (psi, ws)
        c2 = get_cn(ws.interactions, 2)
        E = energy_contribution(TensorTerm(), psi, ws)
        is_active(c2) || return isfinite(E)
        return c2 >= 0.0 ? E >= -1e-12 : E <= 1e-12
    end,
)
