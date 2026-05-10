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
    # Compose the two spin-only rotations into a single D×D unitary, then
    # apply it via one gemm against the spin axis of psi. The previous code
    # path (two sequential apply_uniform_spin_rotation! calls) cost two
    # gemms over the full spatial × D array — at 16³ × D=13 each gemm is
    # ~280 μs, so this folds 4 gemms into 2 inside apply_ddi_step_rotating!.
    # angles converted to Float64 — D×D builder + composition stays on the
    # host; per-voxel gemm uses workspace eltype.
    θ = Float64(theta)
    φ = Float64(phi)
    abs(θ) + abs(φ) < 1e-30 && return nothing

    sgn = inverse ? -1.0 : 1.0
    R_y = _compute_uniform_rotation_matrix(sm, 0.0, sgn * θ, 0.0, 1.0, false)
    R_z = _compute_uniform_rotation_matrix(sm, 0.0, 0.0, sgn * φ, 1.0, false)
    # Forward (sgn=+1): ψ_lab = exp(-iφ F_z) · exp(-iθ F_y) · ψ̃ → R_z * R_y
    # Inverse (sgn=-1): ψ̃ = exp(+iθ F_y) · exp(+iφ F_z) · ψ_lab → R_y * R_z
    R_combined = inverse ? R_y * R_z : R_z * R_y
    _apply_rotation_to_spin_axis!(psi, R_combined, ndim; scratch=scratch)
    nothing
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
    ws::RotatingBasisWS{T, N, D, AC, AC1, AR},
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
    if imaginary_time
        if γ == zero(T)
            @. Φ = exp(-(V + c0 * ρ) * dt)
        else
            @. Φ = exp(-(V + c0 * ρ + γ * ρ * sqrt(ρ)) * dt)
        end
    else
        if γ == zero(T)
            @. Φ = cis(-(V + c0 * ρ) * dt)
        else
            @. Φ = cis(-(V + c0 * ρ + γ * ρ * sqrt(ρ)) * dt)
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
"""
function apply_local_spin_step!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    sm = ws.spin_matrices

    # Zeeman_diag: -p F_z + q F_z²
    Fz = sm.Fz
    Hz = MMatrix{D, D, ComplexF64}(undef)
    @inbounds for j in 1:D, i in 1:D
        Hz[i, j] = -ws.p * Fz[i, j]
    end
    # Add q F_z² (only diagonal contributes since Fz is diagonal)
    if abs(ws.q) > 1e-30
        @inbounds for i in 1:D
            mval = ws.spin_matrices.system.m_values[i]
            Hz[i, i] += ws.q * mval * mval
        end
    end

    # Â / ℏ contribution
    if !iszero(ws.theta_dot_func(Float64(t))) || !iszero(ws.phi_dot_func(Float64(t)))
        theta = ws.theta_func(Float64(t))
        theta_dot = ws.theta_dot_func(Float64(t))
        phi_dot = ws.phi_dot_func(Float64(t))
        # Â / ℏ = θ̇ F_y + φ̇(cosθ F_z - sinθ F_x). With gauge fix (χ̇=-φ̇cosθ),
        # the F_z piece is absorbed: Â/ℏ → θ̇ F_y - φ̇ sinθ F_x.
        a_x = -phi_dot * sin(theta)
        a_y = theta_dot
        a_z = ws.gauge_fix ? 0.0 : phi_dot * cos(theta)
        Fx = sm.Fx;
        Fy = sm.Fy
        @inbounds for j in 1:D, i in 1:D
            Hz[i, j] -= a_x * Fx[i, j] + a_y * Fy[i, j] + a_z * Fz[i, j]
        end
    end

    # Build U = exp(-iH·dt) (RTP) / exp(-H·dt + shift) (ITP) via eigendecomp.
    # Fuse U[i,j] = Σ_k V[i,k]·phase[k]·conj(V[j,k]) directly into MMatrix to
    # drop the Diagonal-Vector + 2 intermediate matmul heap allocations.
    # Use a per-workspace cached Matrix buffer + eigen! so we don't pay
    # `Matrix(H_static)` (~2.7 KB) every call. eigen!'s own values/vectors
    # allocations remain (LAPACK heevr internals), but the dense-copy is
    # gone — saves ~6 allocs / 6 KB / call.
    H_dense = _local_spin_h_buffer(ws)
    @inbounds for j in 1:D, i in 1:D
        H_dense[i, j] = Hz[i, j]
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
    U_loc = SMatrix{D, D, ComplexF64}(U_buf)

    # Apply U_loc to every grid point of ψ̃ via the existing
    # spatially-uniform spin-axis rotation helper.
    _apply_rotation_to_spin_axis!(ws.psi_tilde, U_loc, N; scratch=ws.rotation_scratch)
    nothing
end

# Per-workspace cache of the D×D dense buffer used by `apply_local_spin_step!`
# to feed `eigen!` without rebuilding `Matrix(H_static)` per call. Same pattern
# as `_ROTATING_K2_CACHE` / `_ROTATION_RT_CACHE`: objectid-keyed lookup so
# multiple workspaces don't collide.
const _LOCAL_SPIN_H_CACHE = Dict{UInt, Matrix{ComplexF64}}()
function _local_spin_h_buffer(ws::RotatingBasisWS{T, N, D}) where {T, N, D}
    key = objectid(ws)
    haskey(_LOCAL_SPIN_H_CACHE, key) && return _LOCAL_SPIN_H_CACHE[key]
    buf = Matrix{ComplexF64}(undef, D, D)
    _LOCAL_SPIN_H_CACHE[key] = buf
    buf
end

"""DDI step in rotating basis: rotate ψ̃→ψ_lab in place, apply existing DDI,
rotate back in place. Earlier code copied ψ̃ into `psi_lab_buf`, ran the
forward Û_B + DDI + inverse Û_B on the buffer, then copied back. The buf
round-trip is unnecessary — `_apply_UB!` and `apply_ddi_step!` both mutate
their first argument in place, so operating directly on `psi_tilde`
returns the same final state and saves two `copyto!` over the full
spinor array (~24 µs at 16³ × D=13)."""
function apply_ddi_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    abs(ws.ddi_params.C_dd) > 1e-30 || return nothing
    theta = T(ws.theta_func(Float64(t)))
    phi = T(ws.phi_func(Float64(t)))

    # ψ̃ → ψ_lab (in place)
    _apply_UB!(ws.psi_tilde, ws.spin_matrices, theta, phi, N;
        inverse=false, scratch=ws.rotation_scratch)

    # Apply DDI on ψ_lab using existing infrastructure. apply_ddi_step!
    # locks dt to Float64 (built around the legacy spinor solver path);
    # convert at the boundary so F32 workspaces interop.
    apply_ddi_step!(
        ws.psi_tilde, ws.spin_matrices, ws.ddi_params,
        ws.ddi_bufs, Float64(dt), N; imaginary_time,
    )

    # ψ_lab → ψ̃ (in place)
    _apply_UB!(ws.psi_tilde, ws.spin_matrices, theta, phi, N;
        inverse=true, scratch=ws.rotation_scratch)
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

    phi_x = phi_dot * sin(theta)
    phi_y = -theta_dot
    phi_z = ws.gauge_fix ? zero(Float64) : -phi_dot * cos(theta)

    apply_uniform_spin_rotation!(
        ws.psi_tilde, ws.spin_matrices,
        Float64(phi_x), Float64(phi_y), Float64(phi_z),
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
    Fx = sm.Fx;
    Fy = sm.Fy;
    Fz = sm.Fz

    Hb = MMatrix{D, D, ComplexF64}(undef)
    @inbounds for j in 1:D, i in 1:D
        Hb[i, j] = -ws.p * (bx * Fx[i, j] + by * Fy[i, j] + bz * Fz[i, j])
    end
    if abs(ws.q) > 1e-30
        # (F·B̂)² is dense but Hermitian; build it
        FB = MMatrix{D, D, ComplexF64}(undef)
        @inbounds for j in 1:D, i in 1:D
            FB[i, j] = bx * Fx[i, j] + by * Fy[i, j] + bz * Fz[i, j]
        end
        FB_sq = FB * FB
        @inbounds for j in 1:D, i in 1:D
            Hb[i, j] += ws.q * FB_sq[i, j]
        end
    end

    H_static = SMatrix{D, D, ComplexF64}(Hb)
    Hh = Hermitian(Matrix(H_static))
    eigs = eigen(Hh)
    λ = eigs.values
    Vmat = eigs.vectors
    U_loc = if imaginary_time
        λ_min = minimum(λ)
        SMatrix{D, D, ComplexF64}(Vmat * Diagonal([exp(-(λ[i] - λ_min) * dt) for i in 1:D]) * Vmat')
    else
        SMatrix{D, D, ComplexF64}(Vmat * Diagonal([cis(-λ[i] * dt) for i in 1:D]) * Vmat')
    end

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
    # to Float64 (legacy spinor solver path); convert at the boundary so
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
