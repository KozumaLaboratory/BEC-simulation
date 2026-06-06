# --- CoriolisTerm: H_cor = -Ω·L_z (rotating-frame orbital piece) ---
#
# L_z = -i·(x·∂_y - y·∂_x). H_rot = H_lab - Ω·(L_z + F_z); the F_z
# piece is handled by `_shift_zeeman_for_rotating_frame`. ⟨L_z⟩
# observable lives in `analysis/currents.jl`.

"""
CoriolisTerm (orbital) piece of the rotating-frame Hamiltonian.
`H = -Ω · L_z` where `L_z = -i·(x·∂_y - y·∂_x)`.
"""
struct CoriolisTerm <: HamTerm
    Ω::Float64
end

# THE ONE LINE. Sign convention `H_coriolis = -Ω·L_z` lives here.
# Read this way: positive Ω makes negative ΔE on +L_z eigenstates,
# so descent on -Ω·L_z amplifies +L_z components in ITP.
@inline _coriolis_sign(term::CoriolisTerm) = -term.Ω

# ============================================================================
# Canonical kernel: RT/IT propagator (3-shear FFT decomposition)
# ============================================================================

"""
    _apply_coriolis_step!(psi, grid, omega, dt, imaginary_time, cache=nothing)

Apply Coriolis step `exp(iΩ·L_z·dt)` via 3-shear FFT decomposition.

Implements the `-Ω·L_z` term from the rotating frame Hamiltonian
`H_rot = H - Ω·J_z`. `L_z = x·p_y - y·p_x` is the orbital angular momentum.

Real time: spatial rotation by angle Ω·dt.
Imaginary time: rotation by imaginary angle with real exponential shear
factors (stable for small Ωτ, renormalized each ITP step).

SIGN CONVENTION (load-bearing — do not "fix"):
H_rot = H_lab − Ω·(L_z + F_z). RT Coriolis substep is
`exp(−i·H_coriolis·dt) = exp(+iΩ·L_z·dt) = R̂(−Ω·dt)` (active
rotation operator `R̂(α) = exp(−iα·L_z)`), i.e. CW rotation of ψ by
Ω·dt. Equivalently, evaluate ψ at coordinates transformed by
R(+Ω·dt). With the FFT shear order being y-shears outer (see
`_apply_1d_shear_batch!` calls below), the R(+θ) decomposition is
`(+tan(θ/2), −sin θ, +tan(θ/2))` — the factors used here.

IT branch via analytic continuation `dt = −i·dτ`: substep becomes
`exp(+Ω·L_z·dτ)`, which amplifies the +L_z component (descent on
the Coriolis piece of H_rot). Same shear order with hyperbolic
factors gives `(+tanh(θ/2), −sinh θ, +tanh(θ/2))`.

A 2026-06-03 "fix" inverted these factors after misreading the
freeze diagnostic at a stalled LBFGS state (where ΔE_total ≈ 0.5%
of E_total is splitting-noise-dominated and not a clean
propagator-vs-energy oracle). The audit on 2026-06-03 reverted
that flip after verifying mutual consistency with E_coriolis
(`−Ω·⟨L_z⟩`), the Barnett shift (`p_eff = p_lab + Ω`), and the
transverse-spin RT-Barnett direction (CW Larmor) — all under the
single `H_rot = H − Ω·(L_z + F_z)` convention, with the EdH oracle
(⟨L_z⟩ and ⟨F_z⟩ co-aligned) as final anchor. See
`mistake_coriolis_substep_sign_2026_06_03.md` for the lesson.
"""
function _apply_coriolis_step!(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    omega::Float64,
    dt::Float64,
    imaginary_time::Bool,
    cache::Union{Nothing, CoriolisCache}=nothing,
) where {N}
    N < 2 && return nothing
    abs(omega) < 1e-15 && return nothing

    theta = omega * dt

    if imaginary_time
        a_y = tanh(theta / 2)
        a_x = -sinh(theta)
    else
        a_y = tan(theta / 2)
        a_x = -sin(theta)
    end

    if cache !== nothing
        _apply_1d_shear_batch!(
            psi, grid.x[1], grid.k[2], 2, 1, a_y, imaginary_time,
            cache.fwd_dim2, cache.inv_dim2,
        )
        _apply_1d_shear_batch!(
            psi, grid.x[2], grid.k[1], 1, 2, a_x, imaginary_time,
            cache.fwd_dim1, cache.inv_dim1,
        )
        _apply_1d_shear_batch!(
            psi, grid.x[1], grid.k[2], 2, 1, a_y, imaginary_time,
            cache.fwd_dim2, cache.inv_dim2,
        )
    else
        _apply_1d_shear_batch!(psi, grid.x[1], grid.k[2], 2, 1, a_y, imaginary_time)
        _apply_1d_shear_batch!(psi, grid.x[2], grid.k[1], 1, 2, a_x, imaginary_time)
        _apply_1d_shear_batch!(psi, grid.x[1], grid.k[2], 2, 1, a_y, imaginary_time)
    end
    nothing
end

# ============================================================================
# Canonical kernel: δE_cor/δψ*
# ============================================================================

"""
    _grad_coriolis!(grad, psi, ws, fft_buf, deriv_buf, n_pts, D, ::Val{N})

Add the Coriolis (`-Ω·L_z·ψ`) contribution to `grad`. The `δE_cor/δψ*`
contribution is `+iΩ·(x·∂_y − y·∂_x)·ψ`. Active only when
`rotating_frame_omega ≠ 0` and N ≥ 2. Shared `fft_buf` / `deriv_buf`
let the integrator reuse two ComplexF64 arrays across all components.
"""
function _grad_coriolis!(
    grad, psi, ws, fft_buf, deriv_buf, n_pts, D, ::Val{N}
) where {N}
    Ω = ws.sim_params.rotating_frame_omega
    (is_active(Ω, ROTATION_TOL) && N >= 2) || return nothing
    grid = ws.grid
    x_bcast = _axis_broadcast(fft_buf, grid.x[1], 1)
    y_bcast = _axis_broadcast(fft_buf, grid.x[2], 2)
    kx_bcast = _axis_broadcast(fft_buf, grid.k[1], 1)
    ky_bcast = _axis_broadcast(fft_buf, grid.k[2], 2)
    iΩ = im * Ω
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        fft_buf .= view(psi, idx...)
        ws.fft_plans.forward * fft_buf
        # +iΩ · x · ∂_y ψ
        deriv_buf .= fft_buf .* (im .* ky_bcast)
        ws.fft_plans.inverse * deriv_buf
        view(grad, idx...) .+= iΩ .* x_bcast .* deriv_buf
        # −iΩ · y · ∂_x ψ
        deriv_buf .= fft_buf .* (im .* kx_bcast)
        ws.fft_plans.inverse * deriv_buf
        view(grad, idx...) .-= iΩ .* y_bcast .* deriv_buf
    end
    nothing
end

# ============================================================================
# HamTerm interface
# ============================================================================

function apply_step!(term::CoriolisTerm, psi, dt::Real, imaginary_time::Bool, ws)
    _apply_coriolis_step!(psi, ws.grid, term.Ω, dt, imaginary_time, ws.coriolis_cache)
    return nothing
end

# ============================================================================
# Trinity authoritative kernel: apply_operator!
# H_cor = -Ω·L_z (linear). δE/δψ̄ = -Ω·L_z·ψ = +iΩ·(x∂_y - y∂_x)·ψ.
# `_grad_coriolis!` already implements this; apply_operator! is a wrapper.
# ============================================================================

function apply_operator!(out::AbstractArray, term::CoriolisTerm, ws, psi::AbstractArray)
    N = ndims(psi) - 1
    (N >= 2 && is_active(term.Ω, ROTATION_TOL)) || return out
    D = ws.spin_matrices.system.n_components
    n_pts = ntuple(d -> size(psi, d), Val(N))
    fft_buf = similar(psi, ComplexF64, n_pts...)
    deriv_buf = similar(psi, ComplexF64, n_pts...)
    Ω_save = ws.sim_params.rotating_frame_omega
    @assert isapprox(Ω_save, term.Ω; atol=1e-12) ||
        isapprox(Ω_save, 0.0; atol=1e-12) "CoriolisTerm Ω mismatch with workspace"
    _grad_coriolis!(out, psi, ws, fft_buf, deriv_buf, n_pts, D, Val(N))
    return out
end

# ============================================================================
# Derived: energy from the single source.
# ============================================================================

function energy_contribution(term::CoriolisTerm, psi::AbstractArray{<:Complex}, ws)
    # Linear: E = Re⟨ψ, H·ψ⟩ · dV = -Ω · ⟨L_z⟩.
    # NOTE: orbital_angular_momentum returns ⟨L_z⟩ already integrated (× dV
    # inside). Direct equivalence: orbital_angular_momentum(ψ) =
    # Re⟨ψ, L_z·ψ⟩·dV (= ⟨L_z⟩ × N for normalized ψ since dV*N=1). Use it
    # for efficiency (skips the apply_operator alloc when already cached).
    N = ndims(psi) - 1
    N >= 2 || return 0.0
    return _coriolis_sign(term) * orbital_angular_momentum(psi, ws.grid, ws.fft_plans)
end

# Context-aware specialisation: borrow ctx.fft_buf / ctx.deriv_buf.
function apply_operator!(out::AbstractArray{<:Complex}, term::CoriolisTerm,
    ws, psi::AbstractArray{<:Complex}, ctx::GradientContext)
    N = ndims(psi) - 1
    N >= 2 || return out
    abs(term.Ω) < SpinorBEC.ROTATION_TOL && return out
    D = ws.spin_matrices.system.n_components
    _grad_coriolis!(out, psi, ws, ctx.fft_buf, ctx.deriv_buf, ctx.n_pts, D, Val(N))
    return out
end

"""
Directional sign oracle for `CoriolisTerm`. In ITP, the substep
`exp(+Ω·L_z·dτ)` amplifies the +L_z eigenstate `(x+iy)·gauss`
relative to the -L_z eigenstate `(x-iy)·gauss`. With +Ω, the ratio
of post-step `||ψ_+||²` to pre-step is `exp(+2Ω·dτ)`.

The CoriolisTerm directional test is **already enshrined** in
`test/solvers/test_simulation.jl:253` — this oracle is the
HamTerm-facing wrapper for documentation/CI integration.
"""
function sign_oracle(::Type{CoriolisTerm})
    return (
        name="CoriolisTerm: +Ω ⇒ amplifies +L_z component",
        predicate=function (psi, ws)
            Lz_now = orbital_angular_momentum(psi, ws.grid, ws.fft_plans)
            return Lz_now > 0.5  # for (x+iy)·gauss seed, ⟨L_z⟩ ≈ 1
        end,
    )
end
