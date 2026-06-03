# --- Option γ (rotating-basis) workspace + γ_LHY estimation + lab↔tilde transforms ---
#
# The RotatingBasisWS struct, the `make_rotating_basis_ws` factory, and the
# U_B / U_B† basis-change helpers. The Lima-Pelster Q5 closed form lives in
# `src/hamiltonian/interactions/interactions.jl` (canonical, F64-exact); the
# earlier composite-Simpson copy here was an O(numerical-integration) duplicate
# and was removed during the LHY refactor (commit C4).
# Extracted from rotating_basis_gpe.jl 2026-05-01.

"""
Dimensionless LHY coefficient γ_LHY for a polarized dipolar BEC.

In the eGPE convention `i∂_t ψ̃ = (... + γ_LHY |ψ̃|³) ψ̃` with ψ̃ normalized
to 1, lengths in a_ho, energy in ℏω_ref:

    γ_LHY = (128 √π / 3) · (a_s/a_ho)^(5/2) · N^(3/2) · Q5(ε_dd)

Derivation: μ_LHY (SI) = (32/3) g √(a_s³/π) n^(3/2) Q5. Substitute
n = N |ψ̃|² / a_ho³ and divide by ℏω_ref using g/(ℏω_ref) = 4π a_s a_ho²:

    μ_LHY/(ℏω_ref) = γ_LHY |ψ̃|³ , γ_LHY = (128 √π / 3) (a_s/a_ho)^(5/2) N^(3/2) Q5

Validation reference: Dy Innsbruck 2022 [arXiv:2206.12265] Dy164 (a_s/a_ho ≈ 4.4e-3, N=60000, ε_dd=1.42)
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

See `docs/design/option_gamma_rotating_basis.md` for the full derivation.

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
    BACK <: AbstractBackend,
    TF, PF, TDF, PDF,
    SM}
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
    # NOTE: typed as `::SM` (concrete `SpinMatrices{D, M}`) rather than
    # `::SpinMatrices{D}`. The latter leaves `M <: SMatrix` abstract, which
    # makes `Fz[i, j]` flow through dynamic dispatch — measured at ~500
    # allocs / 19 KB per `apply_local_spin_step!` just from the diagonal
    # `Hz[i, j] = -p * Fz[i, j]` initialisation loop alone.
    spin_matrices::SM

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

    # B̂(t) angles + their derivatives. Each maps t → Float64. Stored
    # under their concrete callable type (TF/PF/TDF/PDF) — declaring
    # `::Function` here would force every call site through dynamic
    # dispatch, so the per-step `ws.theta_func(t)` return values would
    # be boxed and allocate ~496 B per call (~2 K allocs per
    # `apply_local_spin_step!`).
    theta_func::TF
    phi_func::PF
    theta_dot_func::TDF
    phi_dot_func::PDF

    # Gauge: if true, apply χ̇ = -φ̇ cosθ to remove F_z component of Â.
    gauge_fix::Bool

    # Optional loss channels (K3 / γ_dr / evap). LossParams() with all
    # zeros is the inactive default and apply_loss_step! short-circuits
    # via `_is_active(loss)`, so adding this field is free for callers
    # that don't supply a loss block. K3 / γ_dr act on |ψ̃|² which is
    # basis-invariant so applying the spinor-path step on ψ̃ is correct.
    loss::LossParams

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
    # Untyped kwargs so each callable's concrete type flows into the
    # `RotatingBasisWS{...,TF,PF,TDF,PDF}` specialization. Annotating
    # `::Function` here would erase the closure type and trigger
    # ~496 B/call boxing in the per-step ws.theta_func(t) calls.
    theta_func=(_t) -> 0.0,
    phi_func=(_t) -> 0.0,
    theta_dot_func=(_t) -> 0.0,
    phi_dot_func=(_t) -> 0.0,
    gauge_fix::Bool=true,
    loss::LossParams=LossParams(),
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
        typeof(fft_fwd), typeof(fft_inv), typeof(ddi_bufs), typeof(backend),
        typeof(theta_func), typeof(phi_func),
        typeof(theta_dot_func), typeof(phi_dot_func),
        typeof(sm)}(
        psi_tilde, psi_lab_buf, rotation_scratch, spatial_buf, rho_buf,
        kspace_phase_buf, xspace_phase_buf,
        grid, sm,
        fft_fwd, fft_inv,
        ddi_params, ddi_bufs,
        V_trap_dev, T(p), T(q), T(c0), T(c1), T(gamma_lhy),
        theta_func, phi_func, theta_dot_func, phi_dot_func,
        gauge_fix, loss, backend,
    )
end

# --- Lab ↔ tilde basis transforms ---
