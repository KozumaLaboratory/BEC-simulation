# --- Option γ substep propagators + lab-basis reference path ---
#
# Per-substep operators in the rotating basis: kinetic, spatial-diagonal,
# local-spin, DDI, gauge. Plus the lab-basis reference operators used for
# Phase III equivalence checks.

"""
ψ_lab = Û_B(t) ψ̃  with  Û_B = exp(-iφ F_z) exp(-iθ F_y).

`apply_uniform_spin_rotation!(psi, sm, φ_x, φ_y, φ_z, dt)` realizes
exp(-i (φ_x F_x + φ_y F_y + φ_z F_z) dt). To get exp(-iα F_z) we
call with (0, 0, α) and dt=1.

Direction "tilde→lab": apply exp(-iθ F_y) first, then exp(-iφ F_z).
"""
function _apply_UB!(
    psi::AbstractArray{<:Complex}, sm::SpinMatrices{D}, theta::T, phi::T, ndim::Int;
    inverse::Bool=false, scratch=nothing,
) where {T, D}
    θ = Float64(theta)
    φ = Float64(phi)
    abs(θ) + abs(φ) < 1e-30 && return nothing
    R = _UB_combined_rotation(sm, θ, φ, inverse)
    _apply_rotation_to_spin_axis!(psi, R, ndim; scratch=scratch)
    nothing
end

"""
    _apply_UB_to!(dst, src, sm, theta, phi, ndim; inverse=false) → dst

Same Û_B rotation as `_apply_UB!` but writes to `dst` reading from `src`,
so callers can pipeline `src → dst → src` through DDI without paying a
`copyto!` over the full spinor at each Û_B call. Used by
`apply_ddi_step_rotating!`.
"""
function _apply_UB_to!(
    dst::AbstractArray{<:Complex}, src::AbstractArray{<:Complex},
    sm::SpinMatrices{D}, theta::T, phi::T, ndim::Int;
    inverse::Bool=false,
) where {T, D}
    θ = Float64(theta)
    φ = Float64(phi)
    if abs(θ) + abs(φ) < 1e-30
        copyto!(dst, src)
        return dst
    end
    R = _UB_combined_rotation(sm, θ, φ, inverse)
    _apply_rotation_to_spin_axis_to!(dst, src, R, ndim)
    dst
end

# Build the composed Û_B rotation R = R_z(±φ) · R_y(±θ) once. Forward
# (inverse=false) gives ψ̃ → ψ_lab; inverse=true gives ψ_lab → ψ̃ via
# the conj-order product R_y(-θ) · R_z(-φ).
@inline function _UB_combined_rotation(
    sm::SpinMatrices{D}, θ::Float64, φ::Float64, inverse::Bool
) where {D}
    sgn = inverse ? -1.0 : 1.0
    R_y = _compute_uniform_rotation_matrix(sm, 0.0, sgn * θ, 0.0, 1.0, false)
    R_z = _compute_uniform_rotation_matrix(sm, 0.0, 0.0, sgn * φ, 1.0, false)
    inverse ? R_y * R_z : R_z * R_y
end

# --- Substep operators ---

"""Kinetic step: per-component FFT. GPU-safe via broadcasts. k_squared is
lazily lifted to the device on first call and cached. The phase factor
`cis(-dt·k²/2)` is computed once into `ws.kspace_phase_buf` and reused
across all D spinor components — turns D×N broadcast temps into one."""
function apply_kinetic_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T; imaginary_time::Bool=false
) where {T, N, D}
    k2_dev = _kinetic_kspace_buffer(ws)
    if imaginary_time
        @. ws.kspace_phase_buf = exp(-T(dt) * k2_dev / 2)
    else
        @. ws.kspace_phase_buf = cis(-T(dt) * k2_dev / 2)
    end
    @inbounds for m_idx in 1:D
        copyto!(ws.spatial_buf, selectdim(ws.psi_tilde, N + 1, m_idx))
        ws.fft_fwd * ws.spatial_buf
        @. ws.spatial_buf *= ws.kspace_phase_buf
        ws.fft_inv * ws.spatial_buf
        copyto!(selectdim(ws.psi_tilde, N + 1, m_idx), ws.spatial_buf)
    end
    nothing
end

# Lazy device-side cache of k_squared; one entry per workspace identity.
# Stored as `Any` so a single Dict can hold both CPU `Array{T,N}` and GPU
# `CuArray{T,N}` for different workspaces; the typed wrapper below asserts
# the concrete element type (`AR` from the workspace's parametrisation)
# at the lookup site so callers see a fully-typed buffer in their broadcasts.
const _ROTATING_K2_CACHE = Dict{UInt, Any}()
function _kinetic_kspace_buffer(
    ws::RotatingBasisWS{T, N, D, AC, AC1, AR}
) where {T, N, D, AC, AC1, AR}
    key = objectid(ws)
    haskey(_ROTATING_K2_CACHE, key) && return _ROTATING_K2_CACHE[key]::AR
    k2_dev = _zeros(ws.backend, T, ws.grid.config.n_points...)::AR
    copyto!(k2_dev, ws.grid.k_squared)
    _ROTATING_K2_CACHE[key] = k2_dev
    k2_dev
end

"""Spatial-diagonal step: apply exp(-i (V_trap + c0 n + γ_LHY n^(3/2)) dt)
per spinor component. GPU-safe via broadcasts on slabs. Phase factor is
computed once into `ws.xspace_phase_buf` and reused across all D spinor
slabs — turns D inner-loop temporaries into one (alloc-stable for any
future CUDA Graph capture)."""
function apply_spatial_diagonal_step!(
    ws::RotatingBasisWS{T, N, D}, dt::T; imaginary_time::Bool=false
) where {T, N, D}
    # Compute total density rho = Σ_m |ψ̃_m|² via broadcasts on slabs.
    fill!(ws.rho_buf, zero(T))
    @inbounds for m_idx in 1:D
        slab = selectdim(ws.psi_tilde, N + 1, m_idx)
        @. ws.rho_buf += abs2(slab)
    end

    γ = ws.gamma_lhy
    c0 = ws.c0
    V = ws.V_trap
    ρ = ws.rho_buf
    Φ = ws.xspace_phase_buf
    # LHY term `γ ρ^(3/2)` delegates to the shared `_lhy_V` dispatcher (the
    # scalar production formula `c_lhy n √n`), so the closed form lives in
    # ONE place instead of being hand-inlined here.
    if imaginary_time
        if γ == zero(T)
            @. Φ = exp(-(V + c0 * ρ) * dt)
        else
            @. Φ = exp(-(V + c0 * ρ + _lhy_V(ρ, γ)) * dt)
        end
    else
        if γ == zero(T)
            @. Φ = cis(-(V + c0 * ρ) * dt)
        else
            @. Φ = cis(-(V + c0 * ρ + _lhy_V(ρ, γ)) * dt)
        end
    end
    @inbounds for m_idx in 1:D
        slab = selectdim(ws.psi_tilde, N + 1, m_idx)
        @. slab *= Φ
    end
    nothing
end

"""Local spin step: applies a single D×D unitary U(t,dt) = exp(-i H_spin(t) dt)
to every grid point of ψ̃, with H_spin(t) = -p F_z + q F_z² - Â(t).

Both Zeeman_diag (-p F_z + q F_z²) and the gauge connection
Â(t) = ℏ[θ̇ F_y + φ̇(cosθ F_z - sinθ F_x)] are spin-only, spatial-constant
operators. They do NOT commute (off-diagonal Â vs diagonal Zeeman with large
gap p·F), so Strang-splitting them produces O(p·F·|Â|·dt²) errors per step
that accumulate destructively for Klaus-regime p ≈ 30000. Combining them
into one matrix exponential is exact at any dt.

For ITP the imaginary-time path uses exp(-H_spin·dt) shifted to keep the
lowest-energy mode bounded by 1 (constant shift removed via norm
renormalization).

When Â = 0 (static field) H_spin is diagonal, so U is a per-component phase:
the step takes a fast path (`_apply_diagonal_spin_phase!`) that skips the
eigendecomposition and the full D×D rotation entirely.
"""
function apply_local_spin_step!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    sm = ws.spin_matrices

    # Static field (Â = 0): H_spin = -p F_z + q F_z² is diagonal, so U is a
    # per-component phase. Take the fast path that skips BOTH the
    # eigendecomposition and the full D×D spin-axis rotation (per-voxel cost
    # D² → D) — the common case for ITP ground states and static-B̂ RTP.
    has_gauge =
        !iszero(ws.theta_dot_func(Float64(t))) || !iszero(ws.phi_dot_func(Float64(t)))
    if !has_gauge
        _apply_diagonal_spin_phase!(ws, dt; imaginary_time)
        return nothing
    end

    # Gauge-active path: H_spin = (-p F_z + q F_z²) - Â(t) is dense. Build the
    # Zeeman part via the shared `zeeman_field_matrix!` (sign single-sourced
    # with the registry's `_diag_coef(ZeemanTerm)`), subtract the gauge
    # connection Â, and exponentiate eigen-exactly.
    Fz = sm.Fz
    Hz = MMatrix{D, D, ComplexF64}(undef)
    zeeman_field_matrix!(Hz, sm, ws.p, ws.q, 0.0, 0.0, 1.0)

    theta = ws.theta_func(Float64(t))
    a_x, a_y, a_z = _gauge_connection_vector(
        theta, ws.theta_dot_func(Float64(t)), ws.phi_dot_func(Float64(t)), ws.gauge_fix
    )
    Fx = sm.Fx
    Fy = sm.Fy
    @inbounds for j in 1:D, i in 1:D
        Hz[i, j] -= a_x * Fx[i, j] + a_y * Fy[i, j] + a_z * Fz[i, j]
    end

    U_loc = _eigenexact_unitary(ws, Hz, dt; imaginary_time)
    _apply_rotation_to_spin_axis!(ws.psi_tilde, U_loc, N; scratch=ws.rotation_scratch)
    nothing
end

# THE gauge connection Â(t)/ℏ = θ̇ F_y + φ̇(cosθ F_z - sinθ F_x), returned as
# the component vector (Âx, Ây, Âz). With gauge_fix the F_z piece is absorbed
# (χ̇ = -φ̇ cosθ ⇒ Âz = 0). Single declaration consumed by BOTH the
# gauge-active local-spin step (which folds -Â into H) and `apply_gauge_step!`
# (which applies the generator -Â directly); the sign relationship between the
# two consumers is explicit at their call sites. Pinned in
# `test/oracles/test_redundancy_gates.jl (g)`.
@inline function _gauge_connection_vector(
    theta::Real, theta_dot::Real, phi_dot::Real, gauge_fix::Bool
)
    a_x = -phi_dot * sin(theta)
    a_y = theta_dot
    a_z = gauge_fix ? 0.0 : phi_dot * cos(theta)
    return (a_x, a_y, a_z)
end

# Diagonal spin step for a static field (n̂ = ẑ, no gauge connection): multiply
# each spinor component c by exp(-i E_c dt) (RTP) / the shifted
# exp(-(E_c - E_min) dt) (ITP), where E_c = -p m + q m² is the diagonal Zeeman
# energy — single-sourced from `zeeman_field_matrix!` (n̂=ẑ). GPU-safe: scalar
# phase broadcast per spinor slab, like `apply_spatial_diagonal_step!`.
function _apply_diagonal_spin_phase!(
    ws::RotatingBasisWS{T, N, D}, dt::T; imaginary_time::Bool
) where {T, N, D}
    Hd = MMatrix{D, D, ComplexF64}(undef)
    zeeman_field_matrix!(Hd, ws.spin_matrices, ws.p, ws.q, 0.0, 0.0, 1.0)
    E = ntuple(c -> real(Hd[c, c]), Val(D))
    phases = if imaginary_time
        E_min = minimum(E)
        ntuple(c -> ComplexF64(exp(-(E[c] - E_min) * dt)), Val(D))
    else
        ntuple(c -> cis(-E[c] * dt), Val(D))
    end
    @inbounds for c in 1:D
        ph = phases[c]
        slab = selectdim(ws.psi_tilde, N + 1, c)
        @. slab *= ph
    end
    nothing
end

# ----------------------------------------------------------------------------
# Eigen-exact matrix exponential of a Hermitian D×D spin Hamiltonian, shared
# by the rotating local-spin (n̂=ẑ) and lab-spin (n̂=B̂(t)) steps. Build
# U = exp(-iH·dt) (RTP) / exp(-H·dt + shift) (ITP) via eigendecomposition,
# fusing U[i,j] = Σ_k V[i,k]·phase[k]·conj(V[j,k]) directly into an MMatrix to
# drop the Diagonal-Vector + 2 intermediate matmul heap allocations. A
# per-workspace cached dense buffer + `eigen!` avoids paying `Matrix(H)`
# (~2.7 KB) every call; eigen!'s own LAPACK heevr allocations remain.
# ----------------------------------------------------------------------------
function _eigenexact_unitary(
    ws::RotatingBasisWS{T, N, D}, H::AbstractMatrix, dt::T; imaginary_time::Bool
) where {T, N, D}
    H_dense = _eigenexact_h_buffer(ws)
    @inbounds for j in 1:D, i in 1:D
        H_dense[i, j] = H[i, j]
    end
    eigs = eigen!(Hermitian(H_dense))
    λ = eigs.values
    Vmat = eigs.vectors
    phases = if imaginary_time
        λ_min = minimum(λ)
        ntuple(k -> ComplexF64(exp(-(λ[k] - λ_min) * dt)), Val(D))
    else
        ntuple(k -> cis(-λ[k] * dt), Val(D))
    end
    U_buf = MMatrix{D, D, ComplexF64}(undef)
    @inbounds for j in 1:D, i in 1:D
        s = zero(ComplexF64)
        for k in 1:D
            s += Vmat[i, k] * phases[k] * conj(Vmat[j, k])
        end
        U_buf[i, j] = s
    end
    return SMatrix{D, D, ComplexF64}(U_buf)
end

# Per-workspace cache of the D×D dense buffer `_eigenexact_unitary` feeds to
# `eigen!` without rebuilding `Matrix(H)` per call. Same pattern as
# `_ROTATING_K2_CACHE` / `_ROTATION_RT_CACHE`: objectid-keyed lookup so
# multiple workspaces don't collide. Local and lab spin steps never
# interleave on one ws (a run uses one or the other; each is called twice
# sequentially per Strang step), so they safely share the entry.
const _EIGENEXACT_H_CACHE = Dict{UInt, Matrix{ComplexF64}}()
function _eigenexact_h_buffer(ws::RotatingBasisWS{T, N, D}) where {T, N, D}
    key = objectid(ws)
    haskey(_EIGENEXACT_H_CACHE, key) && return _EIGENEXACT_H_CACHE[key]
    buf = Matrix{ComplexF64}(undef, D, D)
    _EIGENEXACT_H_CACHE[key] = buf
    buf
end

"""DDI step in rotating basis. Pipeline:

    ψ̃ ──Û_B (gemm)──▶ rotation_scratch ──DDI (in place)──▶ rotation_scratch ──Û_B† (gemm)──▶ ψ̃

Earlier the Û_B step did `mul!(buf, ψ̃) + copyto!(ψ̃, buf)` per call, paying
two full-array memcopies per DDI rotation. Now the forward Û_B writes
directly to `rotation_scratch`, DDI mutates `rotation_scratch` in place,
and the inverse Û_B writes back to `ψ̃` — no `copyto!` over the spinor
field at all. Saves ~50 µs / call at 16³ × D=13 vs the previous
`_apply_UB!` + in-place chain."""
function apply_ddi_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    abs(ws.ddi_params.C_dd) > 1e-30 || return nothing
    theta = T(ws.theta_func(Float64(t)))
    phi = T(ws.phi_func(Float64(t)))

    # ψ̃ → rotation_scratch (gemm only, no copy).
    _apply_UB_to!(ws.rotation_scratch, ws.psi_tilde,
        ws.spin_matrices, theta, phi, N; inverse=false)

    # DDI mutates rotation_scratch in place. apply_ddi_step!'s rotation
    # cache is keyed by (sm, N_spatial, D, typeof(psi).name, CT), so it
    # shares the same cache entry whether the underlying buffer is
    # ψ̃ or rotation_scratch (same shape + same Array typename).
    apply_ddi_step!(
        ws.rotation_scratch, ws.spin_matrices, ws.ddi_params,
        ws.ddi_bufs, Float64(dt), N; imaginary_time,
    )

    # rotation_scratch → ψ̃ (gemm only, no copy).
    _apply_UB_to!(ws.psi_tilde, ws.rotation_scratch,
        ws.spin_matrices, theta, phi, N; inverse=true)
    nothing
end

"""Gauge connection step: ψ̃ ← exp(+i Â dt / ℏ) ψ̃ where
Â/ℏ = θ̇ F_y + φ̇(cosθ F_z - sinθ F_x).

Equivalently (applied as exp(-i (φ_x F_x + φ_y F_y + φ_z F_z) dt)):
  φ_x = +φ̇ sinθ
  φ_y = -θ̇
  φ_z = -φ̇ cosθ  (or 0 with gauge_fix)
"""
function apply_gauge_step!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    theta = ws.theta_func(Float64(t))
    theta_dot = ws.theta_dot_func(Float64(t))
    phi_dot = ws.phi_dot_func(Float64(t))

    abs(theta_dot) + abs(phi_dot) < 1e-30 && return nothing

    # Generator is -Â: applying exp(-i(-Â)·F dt) = exp(+iÂ·F dt). Â comes from
    # the single `_gauge_connection_vector` declaration shared with the
    # gauge-active local-spin step.
    a_x, a_y, a_z = _gauge_connection_vector(theta, theta_dot, phi_dot, ws.gauge_fix)

    apply_uniform_spin_rotation!(
        ws.psi_tilde, ws.spin_matrices,
        Float64(-a_x), Float64(-a_y), Float64(-a_z),
        Float64(dt), N;
        imaginary_time, scratch=ws.rotation_scratch,
    )
    nothing
end

# --- Lab-basis RTP (Phase III reference for comparison) ---

"""Apply H_lab(t) = -p F·B̂(t) + q (F·B̂(t))² eigen-exactly to ψ stored
in the SAME spinor array. This is the lab-frame counterpart of
`apply_local_spin_step!` and exists so Phase III can compare Option γ
vs lab-frame on identical infrastructure.
"""
function apply_lab_spin_step!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    sm = ws.spin_matrices
    theta = ws.theta_func(Float64(t))
    phi = ws.phi_func(Float64(t))
    bx = sin(theta) * cos(phi)
    by = sin(theta) * sin(phi)
    bz = cos(theta)

    # H_lab = -p (F·B̂) + q (F·B̂)² — the SAME field-direction Zeeman as the
    # rotating local-spin step, here with n̂=B̂(t). One shared declaration,
    # one shared eigen-exact exponential.
    Hb = MMatrix{D, D, ComplexF64}(undef)
    zeeman_field_matrix!(Hb, sm, ws.p, ws.q, bx, by, bz)

    U_loc = _eigenexact_unitary(ws, Hb, dt; imaginary_time)
    _apply_rotation_to_spin_axis!(ws.psi_tilde, U_loc, N; scratch=ws.rotation_scratch)
    nothing
end

"""Lab-basis split-step: T(dt/2) D(dt/2) S(dt/2) DDI(dt) S(dt/2) D(dt/2) T(dt/2),
where S = exp(-i H_lab(t) dt) at midpoint t. ψ stored in `ws.psi_tilde`
is INTERPRETED as ψ_lab here (no basis transform; ws.theta/phi only used
to build H_lab from B̂(t)). DDI is applied directly without Û_B wrap.
"""
function split_step_lab!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    half = dt / 2
    t_mid = t + half

    apply_kinetic_step_rotating!(ws, half; imaginary_time)
    apply_spatial_diagonal_step!(ws, half; imaginary_time)
    apply_lab_spin_step!(ws, half, t_mid; imaginary_time)

    # DDI directly in lab basis (no Û_B wrap). apply_ddi_step! locks dt
    # to Float64 (spinor solver path); convert at the boundary so
    # F32 workspaces interop. Per-voxel array work stays at workspace T.
    if abs(ws.ddi_params.C_dd) > 1e-30
        apply_ddi_step!(ws.psi_tilde, ws.spin_matrices, ws.ddi_params,
            ws.ddi_bufs, Float64(dt), N; imaginary_time)
    end

    apply_lab_spin_step!(ws, half, t_mid; imaginary_time)
    apply_spatial_diagonal_step!(ws, half; imaginary_time)
    apply_kinetic_step_rotating!(ws, half; imaginary_time)
    nothing
end
