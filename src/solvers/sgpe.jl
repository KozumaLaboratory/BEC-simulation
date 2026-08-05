# --- P4.3: SGPE — Stochastic Projected Gross-Pitaevskii ---

export apply_sgpe_step!, sgpe_callback

# Finite-temperature classical-field formulation. The full Hamiltonian step
# is already provided by the unitary split-step; SGPE adds
#
#   (a) γ-damping of the coherent part, in one of two forms:
#       - simple-growth (Bradley-Gardiner): ψ̂(k) → exp(-γ (ε(k) - μ) dt) ψ̂(k)
#         damps only the kinetic dispersion ε(k)=½k². Cheap, exact in k, but
#         the equilibrium ignores the interaction (Hartree-Fock) μ-shift.
#       - full-Hamiltonian (Stoof):        ψ(x) → ψ - γ (Ĥ[ψ] - μ) ψ dt
#         damps the FULL GP residual Ĥ[ψ]ψ (kinetic + trap + c₀ + c₁ + DDI +
#         LHY), assembled by `apply_operator_via_registry!`. The asymptotic
#         equilibrium is then the correct interacting thermal state — this is
#         what strongly-interacting / dipolar regimes (Eu) need.
#   (b) Gaussian white noise:             ψ(x) → ψ(x) + √(2γT dt / dV) · ξ(x)
#
# where ξ(x) ~ 𝒩_ℂ(0, 1) independent per grid point and per spin component,
# and T is the dimensionless temperature T · k_B / (ℏ ω_ref). The
# fluctuation-dissipation noise (b) is identical for both damping forms; only
# the deterministic drift (a) differs.
#
# Optionally high-k projection (PGP) can be applied per step; set `k_cut` to
# a finite value to truncate. Noise is injected in position space *after*
# the damping and projection so fluctuations above the cutoff are immediately
# removed. For the Stoof form a finite `k_cut` is recommended: it bounds the
# kinetic stiffness so the explicit (Euler) full-H drift stays stable.
#
# Intended use: call `apply_sgpe_step!` from an `on_step` callback (or pair
# with `sgpe_callback`) so the standard unitary split-step stays untouched.

using Random

"""
    apply_sgpe_step!(ws, γ, T, dt; μ=0.0, k_cut=Inf, seed=nothing) -> Nothing

One SGPE sub-step: damping in momentum space + thermal Gaussian noise in
position space. Conservative in the γ→0 limit (no-op).

- `γ` — dimensionless damping coefficient.
- `T` — dimensionless temperature (k_B T / (ℏω_ref)).
- `dt` — time step (must match the caller's split-step dt).
- `μ` — chemical potential shift subtracted from the kinetic phase; the damping
  preserves ψ̂(k=0) exactly when μ=0.
- `k_cut` — optional momentum cutoff; if finite, `apply_projected_gp!` is called
  between damping and noise injection.
- `seed` — RNG seed for reproducibility. The callback variant auto-increments
  per step so consecutive steps draw fresh noise.

Fluctuation–dissipation consistency: for a Bose gas in thermal equilibrium at
(μ, T) the damping and noise amplitudes combine to target the classical-field
occupation n(k) = T / (ε(k) - μ) for modes below ε ≪ k_B T. Pinned by
`test_sgpe_fdr.jl` (Rayleigh-Jeans slope check).

# Limitations: "simple-growth" form

This is the Bradley-Gardiner *simple-growth* SGPE: only the coherent kinetic
phase is damped. Interaction terms (c₀, c₁, DDI, LHY, …) are NOT included in
the damping kernel — i.e. the Hartree-Fock μ-shift from interactions does not
back-react on γ. Consequences:

- Early-time relaxation (e.g. Kibble-Zurek defect dynamics) is faithful: the
  fast modes rapidly reach the Rayleigh-Jeans distribution.
- Long-time asymptotic equilibrium is biased for strongly-interacting cases:
  the Hartree-Fock-corrected μ_eff ≠ μ in the damping target.
- For Eu (DDI ε_dd ~ 0.5, c₀ × n_peak ~ O(10²) ≫ T) the bias is significant.
  Treat asymptotic SGPE temperatures as a *control parameter*, not the true
  thermodynamic temperature.

Full-Hamiltonian damping (Stoof-form SGPE) is available via
`full_hamiltonian=true`: the kinetic-only exp-damp is replaced by the explicit
full GP-residual drift `ψ ← ψ - γ(Ĥ[ψ]-μ)ψ dt`, which removes the interaction
bias above (the asymptotic equilibrium becomes the correct interacting state).
Recommended with a finite `k_cut` for stability. `false` (default) keeps the
cheap simple-growth form and all its existing behaviour.

Per-component noise is independent across spinor components. For F=6 dipolar
regimes where spin-coherent thermal correlations matter, this *under*-couples
the spin modes to the bath. Document if running long-T simulations.
"""
function apply_sgpe_step!(
    ws::Workspace{N}, γ::Real, T::Real, dt::Real;
    μ::Real=0.0, mu::Real=μ,            # both spellings
    k_cut::Real=Inf,
    full_hamiltonian::Bool=false,
    seed::Union{Nothing, Int}=nothing,
) where {N}
    γ_f = Float64(γ);
    T_f = Float64(T);
    dt_f = Float64(dt);
    μ_f = Float64(mu)
    γ_f <= 0 && T_f <= 0 && return nothing

    # 1. Coherent γ-damping: full GP residual (Stoof) or kinetic-only (simple-growth).
    if γ_f > 0
        if full_hamiltonian
            _sgpe_damp_full_hamiltonian!(ws, γ_f, μ_f, dt_f)
        else
            _sgpe_damp_kinetic!(ws, γ_f, μ_f, dt_f)
        end
    end

    # 2. High-k projection (classical-field support).
    isfinite(k_cut) && apply_projected_gp!(ws, Float64(k_cut))

    # 3. Thermal Gaussian noise in position space.
    γ_f > 0 && T_f > 0 && _sgpe_add_noise!(ws, γ_f, T_f, dt_f; seed=seed)

    nothing
end

"""
    _sgpe_damp_kinetic!(ws, γ, μ, dt)

ψ̂(k) ← exp(-γ·(½k² − μ)·dt) · ψ̂(k), applied per spin component. The k=0
mode is preserved when μ=0 (preserves total atom number in expectation).
"""
function _sgpe_damp_kinetic!(ws::Workspace{N}, γ::Float64, μ::Float64, dt::Float64) where {N}
    psi = ws.state.psi
    D = ws.spin_matrices.system.n_components
    n_pts = ws.grid.config.n_points
    plans = ws.fft_plans
    fft_buf = ws.state.fft_buf
    T = real(eltype(psi))
    k_squared = ws.grid.k_squared
    half_T = T(0.5)
    γT = T(γ);
    μT = T(μ);
    dtT = T(dt)

    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        fft_buf .= psi_c
        plans.forward * fft_buf
        @. fft_buf *= exp(-γT * (half_T * k_squared - μT) * dtT)
        plans.inverse * fft_buf
        psi_c .= fft_buf
    end
    nothing
end

"""
    _sgpe_damp_full_hamiltonian!(ws, γ, μ, dt)

Stoof-form dissipative drift: `ψ ← ψ − γ·(Ĥ[ψ] − μ)·ψ·dt`, where `Ĥ[ψ]ψ` is
the FULL GP operator action (kinetic + trap + c₀ + c₁ + DDI + LHY) assembled by
`apply_operator_via_registry!` — the same single-source operator the LBFGS
gradient and the energy decomposition use. Unlike the kinetic-only
`_sgpe_damp_kinetic!`, the damping target is the interacting GP fixed point
`Ĥ[ψ]ψ = μψ`, so the asymptotic thermal equilibrium carries the correct
Hartree-Fock + dipolar μ-shift.

Explicit (Euler) in the residual; a finite `k_cut` projection (applied by the
caller after this drift) bounds the kinetic stiffness ½k² and keeps the step
stable for `γ·dt·½k_cut² ≲ 1`. In the free limit (c₀=c₁=0, no DDI/LHY) this
reduces to the simple-growth kinetic drift (to first order in dt), so the
free-field Rayleigh-Jeans FDR is recovered.
"""
function _sgpe_damp_full_hamiltonian!(
    ws::Workspace{N}, γ::Float64, μ::Float64, dt::Float64
) where {N}
    psi = ws.state.psi
    hpsi = ws.state.psi_scratch            # full-size scratch (same shape/device as psi)
    apply_operator_via_registry!(hpsi, ws) # hpsi = Ĥ[ψ]ψ  (zeroes hpsi, then accumulates)
    T = real(eltype(psi))
    a = T(γ * dt);
    μT = T(μ)
    @. psi -= a * (hpsi - μT * psi)
    nothing
end

"""
    _sgpe_add_noise!(ws, γ, T, dt; seed)

ψ(x) ← ψ(x) + σ · ξ(x) with σ = √(2γT·dt/dV), ξ ~ 𝒩_ℂ(0,1) independent per
spin component and grid point. `dV` is the cell volume so the noise density
is dimensionally consistent (∫|noise|² dV ≈ 2γT·dt per component).
"""
function _sgpe_add_noise!(
    ws::Workspace{N}, γ::Float64, T::Float64, dt::Float64;
    seed::Union{Nothing, Int}=nothing,
) where {N}
    psi = ws.state.psi
    D = ws.spin_matrices.system.n_components
    n_pts = ws.grid.config.n_points
    dV = cell_volume(ws.grid)
    σ = sqrt(2.0 * γ * T * dt / dV)
    σ <= 0 && return nothing

    rng = seed === nothing ? Random.default_rng() : Random.MersenneTwister(seed)
    re, im_ = _noise_buffers(ws, n_pts)
    a = real(eltype(psi))(σ / sqrt(2.0))
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        # Independent real + imaginary parts, each 𝒩(0, σ²/2) so that the
        # complex sum has variance σ² — matches |ξ|² expectation 1·σ².
        # `randn!` consumes `rng` in the same order as `randn(rng, Float64, n_pts)`,
        # so CPU streams are bit-identical to the pre-2026-07-28 host path; the GPU
        # path fills in place via CURAND (see `_randn_fill!`).
        _randn_fill!(ws.backend, re, rng)
        _randn_fill!(ws.backend, im_, rng)
        @. psi_c += a * complex(re, im_)
    end
    nothing
end

"""
    _noise_buffers(ws, n_pts) -> (re, im)

Two cached real spatial buffers on `ws`'s device, for drawing complex Gaussian
noise without allocating per step. Float64 regardless of `eltype(psi)` so the
CPU RNG stream is independent of mixed-precision settings.
"""
function _noise_buffers(ws::Workspace, n_pts::NTuple{N, Int}) where {N}
    key = (typeof(ws.state.psi), n_pts)
    re = scratch_get!(:sgpe_noise_re, key) do
        _similar(ws.backend, ws.state.psi, Float64, n_pts...)
    end
    im_ = scratch_get!(:sgpe_noise_im, key) do
        _similar(ws.backend, ws.state.psi, Float64, n_pts...)
    end
    (re, im_)
end

"""
    sgpe_callback(γ, T, dt; μ=0, k_cut=Inf, seed=nothing, every=1) -> Function

`on_step` callback for `run_simulation!`. Advances SGPE every `every` steps
and auto-increments the RNG seed so step-to-step draws are independent.
"""
function sgpe_callback(
    γ::Real, T::Real, dt::Real;
    μ::Real=0.0, k_cut::Real=Inf,
    full_hamiltonian::Bool=false,
    seed::Union{Nothing, Int}=nothing,
    every::Int=1,
)
    # SimulationCallbacks.on_step signature is `(ws, step, times, energies)`
    # — accept the trailing two as varargs so this also works as a manually
    # invoked `(ws, step, n_steps)` callback (older convention used by some
    # callers in the codebase).
    function (ws, step, args...)
        step % every == 0 || return nothing
        apply_sgpe_step!(ws, γ, T, dt;
            μ=μ, k_cut=k_cut, full_hamiltonian=full_hamiltonian,
            seed=seed === nothing ? nothing : seed + step)
        nothing
    end
end
