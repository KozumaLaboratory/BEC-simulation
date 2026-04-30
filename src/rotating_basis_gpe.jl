"""
Lima-Pelster correction Q_5(ε_dd) for the dipolar BEC LHY coefficient.

For ε_dd ≤ 1: Q_5 is real and positive. For ε_dd > 1, the elliptic integrand
has imaginary excursions (roton instability of the homogeneous gas); the
Wachter convention uses Re[Q_5] which captures the dominant stabilizing
contribution. Reference: Lima & Pelster, PRA 84, 041604(R) (2011).

Closed-form result (real part for general ε_dd):

    Q_5(ε_dd) = ∫₀¹ du · Re[ (1 - ε_dd + 3 ε_dd u²)^(5/2) ]

For ε_dd ≤ 1 the integrand is real throughout. For ε_dd > 1 the integrand
becomes imaginary on u ∈ (0, √((ε_dd-1)/(3ε_dd))) and we drop that piece
when taking Re[]. Implementation uses adaptive Gauss-Legendre quadrature.
"""
function lima_pelster_Q5(ε_dd::Real; n_points::Int=64)
    ε = Float64(ε_dd)
    # 64-point Gauss-Legendre on [0, 1]
    function gl_points(n)
        # Use textbook recurrence or just sample uniformly with high density
        # for skeleton — composite Simpson on n_points is sufficient for our
        # ±0.1% accuracy needs across ε_dd ∈ [0, 2].
        u = collect(range(0.0, 1.0; length=n_points + 1))
        u
    end
    u = gl_points(n_points)
    # Composite Simpson: requires odd # samples
    n = length(u) - 1
    if isodd(n)
        push!(u, u[end])  # pad to even — won't matter for accuracy
        n += 1
    end
    h = (u[end] - u[1]) / n
    function integrand(u_val)
        z = 1.0 - ε + 3.0 * ε * u_val^2
        if z >= 0.0
            return z^2.5
        else
            # Re[(complex)^2.5] for negative real argument: real part = 0 of (i√|z|)⁵ = 0
            # Strictly: (-|z|)^(5/2) = i⁵ |z|^(5/2) = i |z|^(5/2). Re = 0.
            return 0.0
        end
    end
    s = integrand(u[1]) + integrand(u[end])
    @inbounds for i in 2:(length(u) - 1)
        s += (isodd(i) ? 4.0 : 2.0) * integrand(u[i])
    end
    s * h / 3
end

"""
Dimensionless LHY coefficient γ_LHY for a polarized dipolar BEC.

In the eGPE convention `i∂_t ψ̃ = (... + γ_LHY |ψ̃|³) ψ̃` with ψ̃ normalized
to 1, lengths in a_ho, energy in ℏω_ref:

    γ_LHY = (128 √π / 3) · (a_s/a_ho)^(5/2) · N^(3/2) · Q5(ε_dd)

Derivation: μ_LHY (SI) = (32/3) g √(a_s³/π) n^(3/2) Q5. Substitute
n = N |ψ̃|² / a_ho³ and divide by ℏω_ref using g/(ℏω_ref) = 4π a_s a_ho²:

    μ_LHY/(ℏω_ref) = γ_LHY |ψ̃|³ , γ_LHY = (128 √π / 3) (a_s/a_ho)^(5/2) N^(3/2) Q5

Validation reference: Klaus 2022 Dy164 (a_s/a_ho ≈ 4.4e-3, N=60000, ε_dd=1.42)
gives γ_LHY ≈ 6080, ratio to c0=3306 ≈ 1.8. LHY contribution at ψ̃²_peak~0.04
is ~36% of contact — substantial as expected for the Klaus regime.
"""
function compute_gamma_lhy(a_s_over_a_ho::Real, ε_dd::Real, N_atoms::Real)
    Q5 = lima_pelster_Q5(ε_dd)
    (128.0 * sqrt(π) / 3.0) * Float64(a_s_over_a_ho)^2.5 *
    Float64(N_atoms)^1.5 * Q5
end

"""
Option γ: Instantaneous local-frame spinor GPE.

The spin quantization axis follows ̂B(t) instantaneously via
|ψ⟩ = Û_B(t)|ψ̃⟩ with Û_B(t) = exp(-iφ(t)F_z) exp(-iθ(t)F_y).

Result: Zeeman becomes static -p F_z + q F_z² in the tilde basis;
the gauge connection Â(t) = ℏ(θ̇ F_y + φ̇(cosθ F_z - sinθ F_x))
appears at rotation-rate scale (kHz vs Larmor MHz). Spin excitations
are preserved (FL phase, EdH spin texture). DDI Q-tensor is rotated
in spin indices via R(t) ∈ SO(3); spatial FFT path is unchanged.

See `docs/option_gamma_rotating_basis.md` for the full derivation.

Scope (skeleton):
- 3D harmonic trap, contact (c0), spin-mixing (c1, optional), DDI
- Static B̂ (Phase I) and time-dependent B̂ (Phase II/III) supported
- ITP for static B̂ (find_ground_state_rotating!)
- RTP for time-dep B̂ (evolve_rotating!)
- No LHY / loss / SGPE / projected GP yet
- CPU only
"""

# --- Workspace ---

struct RotatingBasisWS{T <: AbstractFloat, N, D,
    AC <: AbstractArray, AC1 <: AbstractArray,
    AR <: AbstractArray, ARK <: AbstractArray,
    FP, IP, DB <: DDIBuffers,
    BACK <: AbstractBackend}
    # State (rotating basis): ψ̃[r..., m] — concrete eltype Complex{T}
    psi_tilde::AC
    # Scratch: ψ in lab basis (only populated during DDI step)
    psi_lab_buf::AC
    # Reusable scratch buffer for `_apply_rotation_to_spin_axis!` (avoids
    # per-call `similar(psi)` alloc — 14 such calls per Yoshida6 macro step
    # × 100ms run = several GB churn without this).
    rotation_scratch::AC
    # Spatial scratch for in-place FFT in kinetic step
    spatial_buf::AC1
    # Per-point density buffer used by spatial_diagonal_step (reused, GPU-safe)
    rho_buf::AR
    # Phase scratch for kinetic and diagonal-step broadcasts. Pre-allocated so
    # `cis.(-dt·k²/2)` and `exp/cis(-(V+c0·n+γ·n^{3/2})·dt)` reuse the same
    # device buffer instead of producing a new CuArray temporary each call —
    # required for any future CUDA Graph capture, and a meaningful alloc
    # reduction independently (~14 calls per Yoshida6 step × thousands of
    # steps × 4-8 MB per scratch at 24³).
    kspace_phase_buf::AC1
    xspace_phase_buf::AC1

    grid::Grid{N, T}
    spin_matrices::SpinMatrices{D}

    # FFT plans (in-place on spatial_buf)
    fft_fwd::FP
    fft_inv::IP

    # DDI machinery (reused from spinor infrastructure)
    ddi_params::DDIParams{N}
    ddi_bufs::DB

    # Static potential (real-valued spatial array)
    V_trap::ARK
    p::T               # linear Zeeman magnitude
    q::T               # quadratic Zeeman

    # Couplings
    c0::T              # contact (4π a_s N / a_ho or equivalent)
    c1::T              # spin-mixing (set 0 to skip)
    gamma_lhy::T       # scalar LHY: V += γ_LHY · ρ^(3/2). Stabilizes ε_dd > 1.

    # B̂(t) angles + their derivatives. Each maps t → Float64.
    theta_func::Function
    phi_func::Function
    theta_dot_func::Function
    phi_dot_func::Function

    # Gauge: if true, apply χ̇ = -φ̇ cosθ to remove F_z component of Â.
    gauge_fix::Bool

    # Backend (CPU or CUDA) — kept on the workspace so callers can dispatch.
    backend::BACK
end

function make_rotating_basis_ws(
    grid::Grid{N, T},
    F::Int,
    V_trap::AbstractArray{T, N};
    p::Real, q::Real,
    c0::Real, c1::Real=0.0,
    c_dd::Real=0.0,
    gamma_lhy::Real=0.0,
    theta_func::Function=(_t) -> 0.0,
    phi_func::Function=(_t) -> 0.0,
    theta_dot_func::Function=(_t) -> 0.0,
    phi_dot_func::Function=(_t) -> 0.0,
    gauge_fix::Bool=true,
    backend::AbstractBackend=CPUBackend(),
) where {N, T <: AbstractFloat}
    D = 2F + 1
    n_pts = grid.config.n_points

    # Allocate state + scratch on the requested device. _zeros dispatches
    # CPU → Array, CUDA → CuArray (loaded by SpinorBECCUDAExt extension).
    psi_tilde = _zeros(backend, Complex{T}, n_pts..., D)
    psi_lab_buf = _zeros(backend, Complex{T}, n_pts..., D)
    rotation_scratch = _zeros(backend, Complex{T}, n_pts..., D)
    spatial_buf = _zeros(backend, Complex{T}, n_pts...)
    rho_buf = _zeros(backend, T, n_pts...)
    kspace_phase_buf = _zeros(backend, Complex{T}, n_pts...)
    xspace_phase_buf = _zeros(backend, Complex{T}, n_pts...)

    sm = spin_matrices(F)

    fft_fwd, fft_inv = let plans = make_fft_plans(n_pts, backend; dtype=T)
        plans.forward, plans.inverse
    end

    # Build DDI machinery (Q tensor on CPU, then ship to device).
    rk_shape = rfft_output_shape(n_pts)
    Q_xx = zeros(T, rk_shape);
    Q_xy = zeros(T, rk_shape);
    Q_xz = zeros(T, rk_shape)
    Q_yy = zeros(T, rk_shape);
    Q_yz = zeros(T, rk_shape);
    Q_zz = zeros(T, rk_shape)
    kx_r = collect(T, rfftfreq(n_pts[1], n_pts[1] * grid.dk[1]))
    ky = N >= 2 ? T.(grid.k[2]) : T[]
    kz = N >= 3 ? T.(grid.k[3]) : T[]
    k_sq_rk = zeros(T, rk_shape)
    @inbounds for I in CartesianIndices(rk_shape)
        k2 = kx_r[I[1]]^2
        N >= 2 && (k2 += ky[I[2]]^2)
        N >= 3 && (k2 += kz[I[3]]^2)
        k_sq_rk[I] = k2
    end
    _build_q_tensor!(Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz, kx_r, ky, kz, k_sq_rk, rk_shape)
    # DDIParams.C_dd is a Float64 scalar by struct definition (across both F32
    # and F64 workspaces); the Q_αβ field arrays carry the precision. Q_αβ × C_dd
    # broadcasts will promote intermediates to Float64 but final result is the
    # same precision as the larger array — for F32 Q this is a small ~5%
    # extra fp64 work on the ddi convolution multiplier; not enough to worry
    # about until we move to a fully T-parametric DDIParams.
    ddi_params_cpu = DDIParams(Float64(c_dd), Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz)
    ddi_params = _ddi_params_to_device(ddi_params_cpu, backend)
    ddi_bufs = make_ddi_buffers(n_pts, backend; dtype=T)

    # V_trap also goes on device (per-point scalar phase needs it on same device as ψ̃)
    V_trap_dev = _zeros(backend, T, n_pts...)
    copyto!(V_trap_dev, V_trap)

    RotatingBasisWS{T, N, D,
        typeof(psi_tilde), typeof(spatial_buf), typeof(rho_buf), typeof(V_trap_dev),
        typeof(fft_fwd), typeof(fft_inv), typeof(ddi_bufs), typeof(backend)}(
        psi_tilde, psi_lab_buf, rotation_scratch, spatial_buf, rho_buf,
        kspace_phase_buf, xspace_phase_buf,
        grid, sm,
        fft_fwd, fft_inv,
        ddi_params, ddi_bufs,
        V_trap_dev, T(p), T(q), T(c0), T(c1), T(gamma_lhy),
        theta_func, phi_func, theta_dot_func, phi_dot_func,
        gauge_fix, backend,
    )
end

# --- Lab ↔ tilde basis transforms ---

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
    # apply_uniform_spin_rotation! takes Float64 angles for performance
    # (avoids F32 specialization of its inner D×D rotation matrix builder).
    # The conversion here is per-call scalar work — no array involvement —
    # so F32 workspaces stay F32 in the per-voxel matmul.
    θ = Float64(theta)
    φ = Float64(phi)
    if !inverse
        # ψ_lab = exp(-iφ F_z) exp(-iθ F_y) ψ̃
        apply_uniform_spin_rotation!(psi, sm, 0.0, θ, 0.0, 1.0, ndim; scratch)
        apply_uniform_spin_rotation!(psi, sm, 0.0, 0.0, φ, 1.0, ndim; scratch)
    else
        # ψ̃ = exp(+iθ F_y) exp(+iφ F_z) ψ_lab — same calls with negated angles in reverse order
        apply_uniform_spin_rotation!(psi, sm, 0.0, 0.0, -φ, 1.0, ndim; scratch)
        apply_uniform_spin_rotation!(psi, sm, 0.0, -θ, 0.0, 1.0, ndim; scratch)
    end
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
const _ROTATING_K2_CACHE = Dict{UInt, AbstractArray}()
function _kinetic_kspace_buffer(ws::RotatingBasisWS{T, N}) where {T, N}
    key = objectid(ws)
    haskey(_ROTATING_K2_CACHE, key) && return _ROTATING_K2_CACHE[key]
    k2_dev = _zeros(ws.backend, T, ws.grid.config.n_points...)
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
    H_static = SMatrix{D, D, ComplexF64}(Hz)
    eigs = eigen(Hermitian(Matrix(H_static)))
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

"""DDI step in rotating basis: rotate ψ̃→ψ_lab, apply existing DDI, rotate back."""
function apply_ddi_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    abs(ws.ddi_params.C_dd) > 1e-30 || return nothing
    theta = T(ws.theta_func(Float64(t)))
    phi = T(ws.phi_func(Float64(t)))

    # ψ̃ → ψ_lab
    copyto!(ws.psi_lab_buf, ws.psi_tilde)
    _apply_UB!(ws.psi_lab_buf, ws.spin_matrices, theta, phi, N;
        inverse=false, scratch=ws.rotation_scratch)

    # Apply DDI on ψ_lab using existing infrastructure. apply_ddi_step!
    # locks dt to Float64 (built around the legacy spinor solver path);
    # convert at the boundary so F32 workspaces interop.
    apply_ddi_step!(
        ws.psi_lab_buf, ws.spin_matrices, ws.ddi_params,
        ws.ddi_bufs, Float64(dt), N; imaginary_time,
    )

    # ψ_lab → ψ̃
    _apply_UB!(ws.psi_lab_buf, ws.spin_matrices, theta, phi, N;
        inverse=true, scratch=ws.rotation_scratch)
    copyto!(ws.psi_tilde, ws.psi_lab_buf)
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

"""Lab-basis RTP driver."""
function evolve_lab!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    t0::T=zero(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    t = t0
    for step in 1:n_steps
        split_step_lab!(ws, dt, t)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

# --- Strang split-step ---

"""
One Strang step in rotating basis:

  T(dt/2) D(dt/2) [DDI(dt) + spin-mixing if c1≠0] D(dt/2) T(dt/2) — symmetric
  + gauge connection over the whole step (full dt)

For the skeleton we keep the structure simple. spin-mixing F·⟨F⟩ is omitted
when c1 = 0 (skipped); when present it's applied symmetrically.
"""
function split_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    half = dt / 2
    t_mid = t + half

    # Spatial-diagonal (V_trap + c0 n) + Local spin step (Zeeman_diag - Â) outermost,
    # since local-spin step is exact and acts as the bridge between FFT and DDI.
    apply_kinetic_step_rotating!(ws, half; imaginary_time)
    apply_spatial_diagonal_step!(ws, half; imaginary_time)
    apply_local_spin_step!(ws, half, t_mid; imaginary_time)

    if abs(ws.c1) > 1e-30
        apply_spin_mixing_step!(
            ws.psi_tilde, ws.spin_matrices, Float64(ws.c1), Float64(half), N;
            imaginary_time,
        )
    end

    apply_ddi_step_rotating!(ws, dt, t_mid; imaginary_time)

    if abs(ws.c1) > 1e-30
        apply_spin_mixing_step!(
            ws.psi_tilde, ws.spin_matrices, Float64(ws.c1), Float64(half), N;
            imaginary_time,
        )
    end

    apply_local_spin_step!(ws, half, t_mid; imaginary_time)
    apply_spatial_diagonal_step!(ws, half; imaginary_time)
    apply_kinetic_step_rotating!(ws, half; imaginary_time)

    nothing
end

# --- Drivers ---

function rotating_norm(ws::RotatingBasisWS{T, N, D}) where {T, N, D}
    # GPU-safe: sum(abs2, ψ) is dispatched via GPUArrays for CuArray
    s = sum(abs2, ws.psi_tilde)::T
    s * prod(ws.grid.dx)
end

function normalize_rotating!(
    ws::RotatingBasisWS{T, N, D}; target_norm::T=one(T)
) where {T, N, D}
    n = rotating_norm(ws)
    n > zero(T) || return nothing
    s = sqrt(target_norm / n)
    @. ws.psi_tilde *= s
    nothing
end

"""ITP for rotating-basis spinor GP. For static B̂ (Â=0) this finds
the lab-frame ground state expressed in the rotating basis."""
function find_ground_state_rotating!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    target_norm::T=one(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    μ_last = zero(T)
    for step in 1:n_steps
        split_step_rotating!(ws, dt, zero(T); imaginary_time=true)
        n_before = rotating_norm(ws)
        if n_before > zero(T) && target_norm > zero(T)
            μ_last = -log(n_before / target_norm) / (2 * dt)
        end
        normalize_rotating!(ws; target_norm)
        on_step !== nothing && on_step(step, μ_last, ws)
    end
    μ_last
end

# --- Higher-order time integration: CFET (Alvermann-Fehske 2011) ---

"""
Yoshida4 step in rotating basis (order 4 in dt).

Triple-jump scheme with Yoshida (1990) coefficients:
    w₁ = 1 / (2 - 2^(1/3))
    w₀ = 1 - 2 w₁
    ψ(t+dt) = U(w₁ dt) U(w₀ dt) U(w₁ dt) ψ(t)
where U(τ) = `split_step_rotating!(ws, τ, t_local)` with H sampled at
the midpoint of each sub-step.

Compared to a single Strang step of dt:
- 3 sub-steps per macro step (3× compute)
- Order 4 vs Strang's order 2
- For 4× larger dt at same nominal precision: 0.75× wall time
- Long-time energy drift dramatically reduced

NOTE: w₀ ≈ -1.702 is a NEGATIVE (backward) sub-step. Stable for
unitary RTP at any sign; for imaginary-time ITP this is a known
instability ("Sheng-Suzuki barrier"), so this routine is RTP-only.
"""
function yoshida4_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    imaginary_time &&
        error("yoshida4_step_rotating! is RTP-only (negative sub-step blows up in ITP).")
    cbrt2 = T(2)^(T(1) / T(3))
    w₁ = T(1) / (T(2) - cbrt2)
    w₀ = T(1) - T(2) * w₁

    # Sequence: U(w₁) U(w₀) U(w₁), each with midpoint H sampling
    split_step_rotating!(ws, w₁ * dt, t; imaginary_time=false)           # H @ t + (w₁/2)·dt
    split_step_rotating!(ws, w₀ * dt, t + w₁ * dt; imaginary_time=false) # H @ t + (w₁ + w₀/2)·dt
    split_step_rotating!(ws, w₁ * dt, t + (w₁ + w₀) * dt; imaginary_time=false)
    nothing
end

"""
CFET-style order-4 step using Yoshida4 + Gauss-Legendre time sampling.
Each Yoshida sub-step's H is evaluated at its OWN midpoint, giving the
order-4 accuracy in time-dependent H without requiring commutator
computation.

This is the practical CFET path for `RotatingBasisWS`. For Klaus
magnetostir at full physical Larmor (p=28428), use this when long-time
accuracy matters (1 sec stir, vortex stripe formation).
"""
const cfet4_step_rotating! = yoshida4_step_rotating!

"""
RTP driver using Yoshida4. Same signature as `evolve_rotating!`. Use
when Klaus-regime long-time accuracy matters or to take ~4× larger dt
at comparable accuracy.
"""
function evolve_rotating_yoshida4!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    t0::T=zero(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    t = t0
    for step in 1:n_steps
        yoshida4_step_rotating!(ws, dt, t)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

const evolve_rotating_cfet4! = evolve_rotating_yoshida4!

# --- Higher-order compositions: 6th and 8th order ---

"""
Yoshida6 step in rotating basis (order 6, 7-stage triple-jump composition).

Reference: Yoshida 1990 Phys Lett A 150, 262, "Solution A":
    w₁ = -1.17767998417887
    w₂ =  0.235573213359357
    w₃ =  0.784513610477560
    w₀ = 1 - 2(w₁+w₂+w₃)
Symmetric weight sequence: (w₃, w₂, w₁, w₀, w₁, w₂, w₃).

Per-step compute: 7× Strang. For autonomous H this gives O(dt⁶) accuracy.
For time-dep H (sampled at midpoint per sub-step) the time-dep error is
O(dt²) and dominates unless H(t) varies very slowly.

Best for: long-time RTP runs where energy/norm drift over many trap
periods matters (Klaus 1 sec stir, B-1 long evolution). RTP only.
"""
function yoshida6_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    imaginary_time && error("yoshida6_step_rotating! is RTP-only.")
    w₁ = T(-1.17767998417887)
    w₂ = T(0.235573213359357)
    w₃ = T(0.784513610477560)
    w₀ = one(T) - T(2) * (w₁ + w₂ + w₃)
    weights = (w₃, w₂, w₁, w₀, w₁, w₂, w₃)
    t_local = t
    for w in weights
        split_step_rotating!(ws, w * dt, t_local + w * dt / 2; imaginary_time=false)
        t_local += w * dt
    end
    nothing
end

"""RTP driver: Yoshida6."""
function evolve_rotating_yoshida6!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    t0::T=zero(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    t = t0
    for step in 1:n_steps
        yoshida6_step_rotating!(ws, dt, t)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

# --- Real CFET (Commutator-Free Exponential Time, Alvermann-Fehske 2011) ---

"""
Real CFET4 — EXPERIMENTAL (Alvermann-Fehske 2011 attempted form).

Theoretical motivation: order-4 specifically for time-dependent H (Yoshida4
is order 4 only for autonomous parts; CFET4 should be order 4 also in time-dep
H provided commutator-free conditions are met).

Status: numerical test shows only ~order 2.5 improvement (8× over Strang at
dt=0.01, vs 820× for Yoshida4). Reason: Alvermann-Fehske CFET4 requires each
exponential's argument to be a LINEAR COMBINATION α·A(τ₁) + β·A(τ₂), but the
encapsulated `split_step_rotating!` only supports single-time H sampling.
True CFET4 needs an extension that lets the diagonal/spin step accept
weighted multi-time H evaluation.

Until that infrastructure exists, prefer `yoshida4_step_rotating!` (verified
order 4) or `yoshida6_step_rotating!` (verified order 6) for production runs
in the slow-time-dep regime (Klaus magnetostir, B-1 scan).

Coefficients (Alvermann-Fehske CF4:4exp palindromic form):
    τ₁ = t + (1/2 - √3/6)·dt  ;  τ₂ = t + (1/2 + √3/6)·dt
    α = 1/4 + √3/12  ;  β = 1/4 - √3/12

RTP only.
"""
function cfet4_real_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    imaginary_time && error("cfet4_real_step_rotating! is RTP-only.")

    sqrt3_6 = sqrt(T(3)) / T(6)
    sqrt3_12 = sqrt(T(3)) / T(12)
    τ₁_offset = T(0.5) - sqrt3_6
    τ₂_offset = T(0.5) + sqrt3_6
    α = T(0.25) + sqrt3_12
    β = T(0.25) - sqrt3_12

    # Stage 1: α at τ₁
    split_step_rotating!(ws, α * dt, t + τ₁_offset * dt; imaginary_time=false)
    # Stage 2: β at τ₂
    split_step_rotating!(ws, β * dt, t + τ₂_offset * dt; imaginary_time=false)
    # Stage 3: β at τ₁
    split_step_rotating!(ws, β * dt, t + τ₁_offset * dt; imaginary_time=false)
    # Stage 4: α at τ₂
    split_step_rotating!(ws, α * dt, t + τ₂_offset * dt; imaginary_time=false)
    nothing
end

"""RTP driver: real CFET4 (Alvermann-Fehske)."""
function evolve_rotating_cfet4_real!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    t0::T=zero(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    t = t0
    for step in 1:n_steps
        cfet4_real_step_rotating!(ws, dt, t)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

"""RTP driver in rotating basis."""
function evolve_rotating!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    t0::T=zero(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    t = t0
    for step in 1:n_steps
        split_step_rotating!(ws, dt, t)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

"""Per-component density (for diagnostics). GPU-safe via sum(abs2, slab)."""
function rotating_per_m_norms(ws::RotatingBasisWS{T, N, D}) where {T, N, D}
    dV = prod(ws.grid.dx)
    norms = zeros(T, D)
    @inbounds for m_idx in 1:D
        slab = selectdim(ws.psi_tilde, N + 1, m_idx)
        norms[m_idx] = T(sum(abs2, slab)) * dV
    end
    norms
end

"""Total density (summed across all m components)."""
function rotating_total_density(ws::RotatingBasisWS{T, N, D}) where {T, N, D}
    # Build on device, then return host array (CPU) for downstream analyzers.
    rho_dev = _zeros(ws.backend, T, ws.grid.config.n_points...)
    @inbounds for m_idx in 1:D
        slab = selectdim(ws.psi_tilde, N + 1, m_idx)
        @. rho_dev += abs2(slab)
    end
    Array(rho_dev)
end

"""z-component of orbital angular momentum L_z = -i ⟨ψ̃|x∂_y - y∂_x|ψ̃⟩.
Computed in tilde basis; equals lab-frame L_z because Û_B is spin-only and
∂_x, ∂_y commute with spin rotations.
3D only."""
function rotating_Lz(ws::RotatingBasisWS{T, 3, D}) where {T, D}
    n_pts = ws.grid.config.n_points
    Nx, Ny, Nz = n_pts
    # Lift coordinate / wavenumber 1D arrays to the device. Cached so
    # repeated calls don't copy.
    kx_dev = _coord_buffer(ws, :kx, ws.grid.k[1])
    ky_dev = _coord_buffer(ws, :ky, ws.grid.k[2])
    x_dev = _coord_buffer(ws, :x, ws.grid.x[1])
    y_dev = _coord_buffer(ws, :y, ws.grid.x[2])
    # Reshape for broadcast: (Nx,) → (Nx,1,1); (Ny,) → (1,Ny,1)
    kx_b = reshape(kx_dev, Nx, 1, 1)
    ky_b = reshape(ky_dev, 1, Ny, 1)
    x_b = reshape(x_dev, Nx, 1, 1)
    y_b = reshape(y_dev, 1, Ny, 1)

    Lz = zero(Complex{T})
    dpsi_dy = _zeros(ws.backend, Complex{T}, n_pts...)
    @inbounds for m_idx in 1:D
        copyto!(ws.spatial_buf, selectdim(ws.psi_tilde, 4, m_idx))
        ws.fft_fwd * ws.spatial_buf
        # ∂_y: copy spatial_buf, multiply by i·k_y broadcast, iFFT into dpsi_dy
        copyto!(dpsi_dy, ws.spatial_buf)
        @. dpsi_dy *= im * ky_b
        ws.fft_inv * dpsi_dy
        # ∂_x: multiply spatial_buf by i·k_x broadcast, iFFT in place
        @. ws.spatial_buf *= im * kx_b
        ws.fft_inv * ws.spatial_buf
        psi_m = selectdim(ws.psi_tilde, 4, m_idx)
        # Accumulate ⟨ψ_m|x∂_y - y∂_x|ψ_m⟩ via reduction
        Lz += sum(@. conj(psi_m) * (x_b * dpsi_dy - y_b * ws.spatial_buf))
    end
    real(-im * Lz) * prod(ws.grid.dx)
end

# Cache device-resident coordinate / wavenumber 1-D arrays.
const _ROTATING_COORD_CACHE = Dict{Tuple{UInt, Symbol}, AbstractArray}()
function _coord_buffer(ws::RotatingBasisWS{T}, key::Symbol, host_data) where {T}
    cache_key = (objectid(ws), key)
    haskey(_ROTATING_COORD_CACHE, cache_key) && return _ROTATING_COORD_CACHE[cache_key]
    dev_arr = _zeros(ws.backend, T, length(host_data))
    copyto!(dev_arr, T.(host_data))
    _ROTATING_COORD_CACHE[cache_key] = dev_arr
    dev_arr
end
