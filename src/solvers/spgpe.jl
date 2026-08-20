# --- Full SPGPE — growth (number-damping) + scattering (energy-damping) reservoirs ---
#
# Rooney, Blakie & Bradley, *The stochastic projected Gross-Pitaevskii equation*,
# PRA **86**, 053634 (2012) [arXiv:1210.0952] — equation numbers below refer to it.
# Dimensionless bookkeeping follows Bradley, Rooney & McDonald, PRA **92**, 033631
# (2015) [arXiv:1507.02023], which states the same theory with ℏ and k_BT placed
# explicitly.
#
# The c-field couples to an incoherent (I) reservoir at (μ, T) through TWO
# processes, Eq. (4):
#
#   (S) dψ = dψ|_H + dψ|_γ + (S) dψ|_M
#
#   • growth / NUMBER damping, Eq. (21) — two I-region atoms collide and one enters
#     the C region. Changes N_C and E_C; grand-canonical. Drives condensate growth.
#
#         dψ|_γ = P{ (γ/ℏ)(μ − L)ψ dt + dW_γ },   ⟨dW_γ* dW_γ⟩ = (2γ k_BT/ℏ) δ_C dt
#
#   • scattering / ENERGY damping, Eq. (27) — a C atom and an I atom collide and
#     exchange energy. Conserves N_C exactly, changes E_C; canonical.
#
#         (S) dψ|_M = P{ −(i/ℏ) V_M ψ dt + i ψ dU },
#         V_M(r) = −ℏ ∫d³r' ε(r−r') ∇'·j(r'),   ⟨dU dU⟩ = (2k_BT/ℏ) ε(r−r') dt
#
# Only the growth term was previously implemented here (`apply_sgpe_step!` with
# `full_hamiltonian=true` IS Eq. (21) — see `_spgpe_number_damping!`). This file
# adds (a) the reservoir formulas that turn γ and ℳ from free knobs into predicted
# numbers, (b) the energy-damping term, and (c) a time-dependent reservoir, which
# is what lets a physical second-scale evaporation ramp be driven rather than
# imposed by a mechanical knife.
#
# INTERNAL UNITS throughout: ℏ = m = ω_ref = 1, so lengths are in a_ho =
# √(ℏ/mω_ref), energies in ℏω_ref, and `T` means k_BT/(ℏω_ref). Both γ and ℳ̄ are
# DIMENSIONLESS in these units (Eq. 30), and the number-damping term collapses to
# `dψ = γ(μ − L)ψ dt + dW` with ⟨dW*dW⟩ = 2γT δ_C dt.

export SPGPEReservoir, spgpe_growth_rate, spgpe_scattering_rate, spgpe_rates
export apply_spgpe_step!, apply_energy_damping_step!, spgpe_callback, tracking_cutoff

using Random

# ---------------------------------------------------------------------------
# Reservoir coefficients
# ---------------------------------------------------------------------------

"""
    spgpe_growth_rate(; T, mu, eps_cut, a_s, n_terms=64, rtol=1e-14) -> Float64

Dimensionless growth (number-damping) rate γ of the SPGPE, Rooney et al. Eq. (19):

```math
γ = γ_0 \\sum_{j=1}^{∞} \\frac{e^{βμ(j+1)}}{e^{2βϵ_{cut}j}}
        Φ\\!\\left[\\frac{e^{βμ}}{e^{βϵ_{cut}}}, 1, j\\right]^2,
\\qquad γ_0 = \\frac{8a^2}{λ_{dB}^2}
```

with `Φ` the Lerch transcendent and `λ_dB = √(2πℏ²/mk_BT)`. In internal units
`λ_dB² = 2π/T`, so `γ_0 = 4a_s²T/π`.

Arguments are all in internal units: `T = k_BT/(ℏω_ref)`, `mu = μ/(ℏω_ref)`,
`eps_cut = ϵ_cut/(ℏω_ref)` (the single-particle energy bounding the C region —
for a plane-wave grid projected at `k_cut`, `ϵ_cut = ½k_cut²`), and `a_s` in units
of `a_ho`.

Requires `eps_cut > mu`; the series diverges otherwise (the C region must extend
above the chemical potential).

# Implementation

Written with the Lerch series regrouped into the numerically stable identity

```math
Φ[x,1,j] = x^{-j}\\sum_{n≥j} x^n/n
    \\quad⟹\\quad
γ = γ_0 \\sum_{j≥1} z^{1-j}\\Big(\\sum_{n≥j} x^n/n\\Big)^2 ,
```

`z = e^{βμ}`, `x = e^{β(μ−ϵ_cut)}`, which avoids forming `e^{βμ(j+1)}` and
`Φ` separately (both large, product small). Successive terms fall off like
`xw = e^{β(μ−2ϵ_{cut})}`, so the sum converges geometrically.
"""
function spgpe_growth_rate(;
    T::Real, mu::Real, eps_cut::Real, a_s::Real,
    n_terms::Int=64, rtol::Real=1e-14,
)
    T > 0 || throw(ArgumentError("spgpe_growth_rate: T must be > 0, got $T"))
    eps_cut > mu || throw(
        ArgumentError(
            "spgpe_growth_rate: need eps_cut > mu (C region must extend above μ); " *
            "got eps_cut=$eps_cut, mu=$mu"),
    )

    β = 1 / Float64(T)
    z = exp(β * Float64(mu))                 # fugacity
    x = exp(β * (Float64(mu) - Float64(eps_cut)))   # < 1 by the check above
    γ0 = 8 * Float64(a_s)^2 / (2π / Float64(T))     # = 4a_s²T/π

    # tail_j = Σ_{n≥j} xⁿ/n, built down from the j=1 value −ln(1−x).
    tail = -log1p(-x)
    total = 0.0
    xn = x                                    # xʲ⁻¹ ... tracks the term removed
    zpow = 1.0                                # z^{1-j}
    for j in 1:n_terms
        term = zpow * tail^2
        total += term
        abs(term) <= rtol * abs(total) && break
        # advance: drop the n=j term, then z^{1-j} → z^{-j}
        tail -= xn / j
        tail <= 0 && break                    # numerical floor
        xn *= x
        zpow /= z
    end
    γ0 * total
end

"""
    spgpe_scattering_rate(; T, mu, eps_cut, a_s) -> Float64

Dimensionless energy-damping (scattering) amplitude ℳ̄ of the SPGPE, from
Rooney et al. Eqs. (26) and (30):

```math
ℳ = \\frac{16πa^2k_BT}{ℏ}\\frac{1}{e^{β(ϵ_{cut}−μ)}−1},
\\qquad
\\barℳ ≡ \\frac{ℳℏ}{k_BT\\,x_0^2} = \\frac{16πa^2/x_0^2}{e^{β(ϵ_{cut}−μ)}−1}
```

In internal units (`x_0 = a_ho = 1`) this is `16π a_s²/(e^{(ϵ_cut−μ)/T} − 1)`.
ℳ̄ sets the strength of the non-local kernel `ε̃(k) = ℳ̄/|k|` in
[`apply_energy_damping_step!`](@ref).

Unlike γ, ℳ̄ has no series: the scattering rate involves a single Bose factor at
the cutoff. It diverges as `ϵ_cut → μ` (the C region boundary sitting at the
chemical potential means unbounded reservoir occupation there).
"""
function spgpe_scattering_rate(; T::Real, mu::Real, eps_cut::Real, a_s::Real)
    T > 0 || throw(ArgumentError("spgpe_scattering_rate: T must be > 0, got $T"))
    eps_cut > mu || throw(
        ArgumentError(
            "spgpe_scattering_rate: need eps_cut > mu; got eps_cut=$eps_cut, mu=$mu"),
    )
    16π * Float64(a_s)^2 / expm1((Float64(eps_cut) - Float64(mu)) / Float64(T))
end

# ---------------------------------------------------------------------------
# Reservoir specification
# ---------------------------------------------------------------------------

"""
    SPGPEReservoir(; T, mu, a_s, k_cut, eps_cut=nothing, number_damping=true,
                     energy_damping=true, gamma=nothing, M=nothing)

The incoherent reservoir the c-field is coupled to. `T`, `mu` and `eps_cut`
accept either a `Number` (held constant) or a [`Waveform`](@ref) — a ramped
`(T(t), μ(t))` is how a **physical evaporation** is driven: the reservoir is
cooled and depleted on the experimental timescale and the c-field condenses in
response, instead of atoms being removed by a mechanical knife on a timescale
chosen for numerical convenience.

All quantities are in internal units (`T = k_BT/ℏω_ref`, `mu = μ/ℏω_ref`,
`a_s` in `a_ho`).

- `k_cut` — the projector cutoff defining the C region. `eps_cut` defaults to
  `½k_cut²`, the single-particle energy at the cutoff on a plane-wave grid.
- `gamma`, `M` — override the reservoir formulas with fixed values. Use for
  convergence checks: SPGPE **equilibria must be independent of γ and ℳ̄**
  (Rooney et al. §III D 3 / §III E 3), which is the sharpest test of an
  implementation. Leave `nothing` for the predicted rates.
- `number_damping`, `energy_damping` — switch either reservoir process off,
  giving the growth SPGPE (Eq. 20) or the scattering SPGPE (Eq. 27) as
  sub-theories.
"""
struct SPGPEReservoir{WT <: Waveform, WM <: Waveform, WE <: Waveform, WK <: Waveform}
    T::WT
    mu::WM
    eps_cut::WE
    k_cut::WK
    derive_eps_cut::Bool    # true ⇒ ϵ_cut = ½k_cut(t)², recomputed each step
    a_s::Float64
    number_damping::Bool
    energy_damping::Bool
    gamma::Float64          # NaN ⇒ derive from the reservoir
    M::Float64              # NaN ⇒ derive from the reservoir
end

_as_waveform(x::Waveform) = x
_as_waveform(x::Number) = ConstantWaveform(Float64(x))

function SPGPEReservoir(;
    T, mu, a_s::Real, k_cut,
    eps_cut=nothing,
    number_damping::Bool=true, energy_damping::Bool=true,
    gamma=nothing, M=nothing, allow_unphysical_rates::Bool=false,
)
    kw = _as_waveform(k_cut)
    if k_cut isa Number
        isfinite(k_cut) && k_cut > 0 ||
            throw(ArgumentError("SPGPEReservoir: k_cut must be finite and > 0, got $k_cut"))
    end
    derive = eps_cut === nothing
    ec = derive ? ConstantWaveform(NaN) : _as_waveform(eps_cut)
    allow_unphysical_rates ||
        _check_rate_against_derived(gamma, M, _as_waveform(T), _as_waveform(mu), kw, a_s)
    SPGPEReservoir(
        _as_waveform(T), _as_waveform(mu), ec, kw, derive, Float64(a_s),
        number_damping, energy_damping,
        gamma === nothing ? NaN : Float64(gamma),
        M === nothing ? NaN : Float64(M),
    )
end

"""
    tracking_cutoff(t_internal, mu, T; n_T=2.5) -> PiecewiseLinearWaveform

`k_cut(t) = √(2(μ(t) + n_T·T(t)))` — the projector cutoff that keeps the C region
a FIXED number of thermal energies deep, `ϵ_cut − μ = n_T·k_BT`.

This is the standard prescription, and holding `k_cut` constant instead is a
mistake with teeth when the ramp has dynamic range in `T`. Both coefficients
depend on the cutoff only through `(ϵ_cut − μ)/T`:

    γ ~ γ_0·(ln(1 − e^{−(ϵ_cut−μ)/T}))²,   ℳ̄ = 16πa²/(e^{(ϵ_cut−μ)/T} − 1)

so a cutoff fixed in absolute energy while `T` falls drives `(ϵ_cut−μ)/T` up and
**both rates collapse exponentially** — the reservoir silently decouples and the
c-field freezes mid-ramp. On the ¹⁵¹Eu evaporation window (`T` falling 8.6×) a
fixed cutoff took γ from 4.8×10⁻⁴ to 6×10⁻¹⁴ and no condensate formed.

`n_T` is set by the standard c-field criterion: the Rayleigh–Jeans occupation at
the cutoff, `T/(ϵ_cut−μ) = 1/n_T`, should be of order 1 — that is what makes a
classical field the right description up to there. `n_T = 1.0` (occupation exactly 1)
is the default. Going deeper is not free: `n_T = 2.5` drops occupation to 0.4,
cuts γ by ~9×, and demands a finer grid, so a ramp of fixed length gets fewer
growth times. Since `n_T` is a genuine free parameter of the method, any result
read off a single value should be checked against a second one.

Note the projector is *shrinking*, so it removes atoms from the C region as the
ramp proceeds. That is physically the reverse flow into the I region, and
[`apply_spgpe_step!`](@ref) reports it as `cutoff_outflow`, measured separately
from the `noise_truncated` bookkeeping (which is ~10³× larger per step and would
otherwise swamp it).
"""
function tracking_cutoff(
    t_internal::AbstractVector, mu::AbstractVector, T::AbstractVector; n_T::Real=1.0
)
    length(t_internal) == length(mu) == length(T) ||
        throw(ArgumentError("tracking_cutoff: t, mu, T must have equal length"))
    k = [sqrt(max(2 * (mu[i] + Float64(n_T) * T[i]), 1e-6)) for i in eachindex(t_internal)]
    PiecewiseLinearWaveform(collect(Float64, t_internal), k)
end

"""
    spgpe_rates(res::SPGPEReservoir, t) -> (; T, mu, eps_cut, gamma, M)

Reservoir state and the two dissipation coefficients at time `t`, in internal
units. Coefficients come from [`spgpe_growth_rate`](@ref) /
[`spgpe_scattering_rate`](@ref) unless overridden on the reservoir.
"""
function spgpe_rates(res::SPGPEReservoir, t::Real)
    tf = Float64(t)
    T = evaluate(res.T, tf)
    mu = evaluate(res.mu, tf)
    k_cut = evaluate(res.k_cut, tf)
    eps_cut = res.derive_eps_cut ? 0.5 * k_cut^2 : evaluate(res.eps_cut, tf)
    γ = if !res.number_damping
        0.0
    elseif isnan(res.gamma)
        spgpe_growth_rate(; T, mu, eps_cut, a_s=res.a_s)
    else
        res.gamma
    end
    M = if !res.energy_damping
        0.0
    elseif isnan(res.M)
        spgpe_scattering_rate(; T, mu, eps_cut, a_s=res.a_s)
    else
        res.M
    end
    (; T, mu, eps_cut, k_cut, gamma=γ, M)
end

# ---------------------------------------------------------------------------
# The step
# ---------------------------------------------------------------------------

"""
    apply_spgpe_step!(ws, res::SPGPEReservoir, dt; t=ws.state.t, seed=nothing,
                      noise=true) -> NamedTuple

One full SPGPE dissipative sub-step at reservoir time `t`, to be composed with
the unitary `split_step!` (which supplies `dψ|_H`). Order:

1. number-damping drift  `ψ ← ψ + γ(μ − L)ψ dt`  (full GP operator `L`, Stoof form)
2. number-damping noise  `ψ ← ψ + √(2γT dt/dV) ξ`
3. energy-damping phase  `ψ ← ψ exp(i(dU − V_M dt))`
4. projection `P` at `k_cut`

The projector comes **last**, so both noises are projected into the C region
within the same step — the literal `P{…}` of Eq. (4). (`apply_sgpe_step!` projects
between damping and noise, leaving one step of unprojected noise; that ordering
is preserved there for reproducibility of existing runs.)

`noise=false` gives the *quiet* SPGPE — the damped/energetically-damped PGPE of
§III D 3 / §III E 3, whose two directional signatures (`N_C` relaxes to the
reservoir μ; `E_C` decreases monotonically) are the sign oracles for this term.

Returns the rates actually used, `(; T, mu, eps_cut, gamma, M)`, so callers can
log the reservoir trajectory.
"""
function apply_spgpe_step!(
    ws::Workspace{N}, res::SPGPEReservoir, dt::Real;
    t::Real=ws.state.t, seed::Union{Nothing, Int}=nothing, noise::Bool=true,
) where {N}
    r = spgpe_rates(res, t)
    dt_f = Float64(dt)

    # Cutoff-shrinkage outflow, measured FIRST and on its own. The incoming field
    # is already projected at the previous step's cutoff, so re-projecting at the
    # current one removes exactly the band the cutoff swept past — atoms leaving
    # the C region for the I region. Measuring this after the noise instead would
    # conflate it with noise truncation, which is a per-step effect two to three
    # orders of magnitude larger and would swamp it.
    cutoff_outflow = apply_projected_gp!(ws, r.k_cut)

    if r.gamma > 0
        _spgpe_number_damping!(ws, r.gamma, r.mu, r.T, dt_f; seed=seed, noise=noise)
    end
    if r.M > 0
        apply_energy_damping_step!(
            ws, r.M, r.T, dt_f;
            seed=seed === nothing ? nothing : seed + 7_919, noise=noise,
            k_cut=r.k_cut,
        )
    end
    # Projection last, so both noises are projected within the same step — the
    # literal P{…} of Eq. (4). What it removes here is the part of the fresh
    # noise that landed above the cutoff; that is bookkeeping of the injection,
    # NOT a physical outflow, so it is reported separately from `cutoff_outflow`.
    noise_truncated = apply_projected_gp!(ws, r.k_cut)
    merge(r, (; cutoff_outflow, noise_truncated))
end

"""
    _spgpe_number_damping!(ws, γ, μ, T, dt; seed, noise)

Growth term, Eq. (21): the Stoof-form drift `ψ ← ψ − γ(Ĥ[ψ] − μ)ψ dt` plus the
FDR noise. Both pieces are the existing SGPE kernels — the `full_hamiltonian`
SGPE step already *is* the SPGPE number-damping term, with γ supplied by hand
instead of by [`spgpe_growth_rate`](@ref). Kept as one call site so there is a
single statement of this physics.
"""
function _spgpe_number_damping!(
    ws::Workspace, γ::Float64, μ::Float64, T::Float64, dt::Float64;
    seed::Union{Nothing, Int}=nothing, noise::Bool=true,
)
    _sgpe_damp_full_hamiltonian!(ws, γ, μ, dt)
    noise && T > 0 && _sgpe_add_noise!(ws, γ, T, dt; seed=seed)
    nothing
end

"""
    apply_energy_damping_step!(ws, M, T, dt; seed=nothing, noise=true) -> Nothing

Scattering (energy-damping) sub-step, Eq. (27) — the number-conserving reservoir
process the growth-only SGPE omits.

```math
(S)\\,dψ|_M = −\\frac{i}{ℏ}V_M ψ\\,dt + iψ\\,dU,
\\qquad
V_M(r) = −ℏ\\!\\int\\! d^3r'\\,ε(r−r')\\,∇'\\!·j(r'),
\\qquad
\\tildeε(k) = \\bar{ℳ}/|k|
```

Three things make this cheap and exact where it matters:

**The divergence needs no current.** `j = Im(ψ*∇ψ)` (ℏ=m=1) gives
`∇·j = Im(∂_dψ*∂_dψ) + Im(ψ*∂_d²ψ)`, and the first term is real, so

    ∇·j = Σ_c Im(ψ_c* ∇²ψ_c)

— one Laplacian per component rather than `N` gradients plus a divergence.

**Both terms are a real phase.** `dψ = iψ(dU − V_M dt/ℏ)` with `V_M`, `dU` real,
so the sub-step is `ψ ← ψ·exp(i(dU − V_M dt))` — exactly norm-preserving BEFORE
projection. In the projected scheme number conservation is only approximate
(Rooney, Blakie & Bradley PRE 89, 013302), because the product of two
band-limited fields reaches 2`k_cut` and the caller projects the state. Keeping
that bite small is why the kernel and the noise are band-limited to the C region,
Eq. (15) — see step 4 for what happens when they are not.

**The noise is coloured by the same kernel.** `⟨dU dU⟩ = 2Tε(r−r')dt` is drawn as
white noise filtered by `√(2TℳdT/|k|)`; the filter is real and even in `k`, so
the result is real automatically.

`V_M` is frozen at the start of the sub-step (first order in `dt`, matching the
semi-implicit Euler the theory requires for multiplicative noise). The `k=0`
component of both kernels is set to zero: `∇·j` has no `k=0` content for a
localised field, and a `k=0` noise is an unobservable global phase with divergent
variance.

Quiet limit (`noise=false`): `dE_C/dt = −ℳ̄∫d³k |k·j̃(k)|²/|k| ≤ 0`, Eq. (29) —
energy decreases monotonically. That sign is the oracle for this term.
"""
function apply_energy_damping_step!(
    ws::Workspace{N}, M::Real, T::Real, dt::Real;
    seed::Union{Nothing, Int}=nothing, noise::Bool=true, k_cut::Real=Inf,
) where {N}
    M_f = Float64(M)
    M_f > 0 || return nothing
    dt_f = Float64(dt)

    psi = ws.state.psi
    D = ws.spin_matrices.system.n_components
    n_pts = ws.grid.config.n_points
    plans = ws.fft_plans
    buf = ws.state.fft_buf
    RT = real(eltype(psi))

    divj, phase_k, ksq, kinv = _energy_damping_buffers(ws, n_pts, Float64(k_cut))

    # 1. ∇·j = Σ_c Im(ψ_c* ∇²ψ_c)
    fill!(divj, 0)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        buf .= psi_c
        plans.forward * buf
        @. buf *= -ksq
        plans.inverse * buf                     # buf = ∇²ψ_c
        @. divj += imag(conj(psi_c) * buf)
    end

    # 2. −V_M dt in k-space:  −Ṽ_M(k) dt = +(ℳ̄/|k|)·F{∇·j}(k)·dt
    buf .= divj
    plans.forward * buf
    @. phase_k = RT(M_f * dt_f) * kinv * buf

    # 3. + dU: white noise coloured by √(2Tℳ̄ dt/|k|), normalised so the discrete
    #    correlator matches ⟨dU dU⟩ = 2T ε(r−r') dt on a grid of cell volume dV.
    if noise && Float64(T) > 0
        dV = cell_volume(ws.grid)
        amp = RT(sqrt(2 * Float64(T) * M_f * dt_f / dV))
        re, _ = _noise_buffers(ws, n_pts)
        rng = seed === nothing ? Random.default_rng() : Random.MersenneTwister(seed)
        _randn_fill!(ws.backend, re, rng)
        buf .= re
        plans.forward * buf
        @. phase_k += amp * sqrt(kinv) * buf
    end

    # 4. ψ ← ψ·exp(i·phase), with the phase BAND-LIMITED to the C region.
    #
    # WHAT THE PROJECTED STEP COSTS IN NUMBER — settled 2026-08-20, after being got
    # wrong twice in opposite directions. Read this before measuring it a third
    # time; `test/dynamics/test_spgpe.jl` gates it.
    #
    # The loss through the caller's projector is a ONE-OFF, not a rate: it is
    # whatever the SEED carried outside the C region, removed the first time the
    # projector runs. Measured with a pre-projected seed (P ψ₀ = ψ₀) the total over
    # 400 steps is 1.1e-13; with the seed carrying 1e-4 outside, the FIRST step
    # removes 1.0e-4 and every step after it costs 2.6e-16; at 1e-2 the first step
    # removes 9.9e-3. Doubling dt changes nothing.
    #
    # It was read as a RATE (~1.25× the growth rate) because that measurement went
    # through `apply_spgpe_step!` with a `tracking_cutoff`. A cutoff that moves
    # every step MANUFACTURES fresh out-of-C content every step, so the one-off is
    # paid again and again and looks stationary. Flatness in resolution — which was
    # taken as proof of a scheme property — is also what a one-off shows.
    #
    # Consequence for callers: a growth problem does NOT need
    # `energy_damping=false`. What it needs is a seed inside its own C region;
    # project it once before starting. If `tracking_cutoff` is used, each cutoff
    # change legitimately bills the band it swept past — that is `cutoff_outflow`,
    # reported separately, and it is physics rather than a defect.
    #
    # The band limit is the load-bearing part, and it was missing. Rooney et al.
    # Eq. (15) carries δ_C(k,−k') in the noise correlator, so the kernel and the
    # noise it colours both live below the cutoff. With 1/|k| left unrestricted the
    # phase had out-of-band structure, multiplying it into ψ scattered weight past
    # k_cut, and the caller's projector removed that weight every step: measured at
    # μ = −1, T = 1.026, k_cut = 2.01, dt = 0.05, the loss was 0.05 % of the norm
    # per step at ℳ̄ = 0.01 and 0.53 % at ℳ̄ = 0.1, taking N from 56.4 to 1.6e-3 and
    # to 1.2e-44 over 20000 steps. The same term with no projector in the path held
    # N to the last bit, which is why the unit test — which calls this function
    # directly — passed throughout. The full SPGPE equilibrated at 55 % of
    # Thomas-Fermi as a result, and every full-SPGPE number on this branch was
    # retracted.
    #
    # Nor is it a discretisation error: the loss per step goes as the phase
    # variance and hence as dt, while the step count goes as 1/dt, so the loss per
    # unit TIME does not depend on dt.
    #
    # Two increment forms were tried before reading the numerical-method paper and
    # both are worse. `ψ + iψφ` has modulus √(1+φ²) > 1 and, with φ_rms ≈ 0.3 per
    # step at ℳ̄ = 0.1, overflows. `ψ(1 + iφ − φ²/2)` is stable but still loses:
    # the product of two band-limited fields extends to 2k_cut, so P{ψφ} is not
    # ψφ and the Itō correction no longer cancels. Rooney, Blakie & Bradley
    # PRE 89, 013302 are explicit that number conservation in the projected scheme
    # is approximate, so the honest statement is a phase that is exactly
    # norm-preserving before projection, with the projector's bite made small by
    # band-limiting rather than argued away.
    plans.inverse * phase_k
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        @. psi_c *= cis(real(phase_k))
    end
    nothing
end

"""
    _energy_damping_buffers(ws, n_pts, k_cut) -> (divj, phase_k, ksq, kinv)

Cached device buffers + k-space kernels for the energy-damping step. `kinv` is
`1/|k|` with the `k=0` entry zeroed and everything above `k_cut` zeroed (see
[`apply_energy_damping_step!`](@ref)); `ksq` is `ws.grid.k_squared` resident on
the device, which the per-call `_to_device` in `apply_projected_gp!` would
otherwise re-upload every step.

**`k_cut` is NOT part of the cache key**, and that is the whole point of this
function's shape. `tracking_cutoff` exists to ramp the cutoff — it is a
`Waveform`, evaluated fresh every reservoir sub-step — so keying on it gives a
distinct entry per step, and `SCRATCH_REGISTRY` holds strong references and never
evicts. Measured 2026-08-19 on a 64³ D=13 SPGPE growth ramp: 34 557 reservoir
sub-steps, four buffers each, and the job died with
`Out of GPU memory trying to allocate 4.000 MiB` at 99.97 % of a 94 GiB H100 —
after the ramp had run to completion often enough to look like a physics result.
A *constant* cutoff hides it completely, which is why every existing test passed.

So the shape-dependent buffers are keyed on shape alone and `kinv` is REBUILT in
place from the cached `ksq` on each call. That is one O(N) device broadcast
against the sub-step's several FFTs, i.e. free, and it removes the failure mode
rather than making its onset later.
"""
function _energy_damping_buffers(
    ws::Workspace, n_pts::NTuple{N, Int}, k_cut::Float64=Inf
) where {N}
    psi = ws.state.psi
    RT = real(eltype(psi))
    key = (typeof(psi), n_pts)
    divj = scratch_get!(:ed_divj, key) do
        _similar(ws.backend, psi, RT, n_pts...)
    end
    phase_k = scratch_get!(:ed_phase, key) do
        _similar(ws.backend, psi, eltype(psi), n_pts...)
    end
    ksq = scratch_get!(:ed_ksq, key) do
        _to_device(ws.backend, convert(Array{RT}, ws.grid.k_squared))
    end
    kinv = scratch_get!(:ed_kinv, key) do
        _similar(ws.backend, psi, RT, n_pts...)
    end
    # Band-limited to the C region, Rooney et al. Eq. (15): the correlator carries
    # δ_C(k,−k'), so both the kernel and the noise it colours live BELOW the
    # cutoff. Leaving 1/|k| unrestricted put out-of-band structure into a phase
    # that multiplies the field, and the product was then removed by the caller's
    # projector — 0.05 % of the norm per step at ℳ̄ = 0.01 and 0.53 % at ℳ̄ = 0.1,
    # which over 20000 steps took N from 56.4 to 1.6e-3 and 1.2e-44.
    kc2 = RT(k_cut^2)
    @. kinv = ifelse((ksq > 0) & (ksq <= kc2), one(RT) / sqrt(max(ksq, floatmin(RT))),
        zero(RT))
    (divj, phase_k, ksq, kinv)
end

"""
    spgpe_callback(res::SPGPEReservoir, dt; every=1, seed=nothing, noise=true,
                   on_rates=nothing) -> Function

`on_step` callback applying [`apply_spgpe_step!`](@ref) every `every` steps with
an effective step `every·dt` (operator splitting between the unitary evolution
and the reservoir). Sub-stepping the reservoir is safe whenever `γ·dt_eff ≪ 1`
and `ℳ̄·dt_eff ≪ 1` — for realistic reservoirs both coefficients are `O(10⁻⁴)`,
so `every ≈ 5–10` costs nothing in accuracy and is the difference between a
second-scale ramp finishing in hours and in days.

`on_rates(t, rates)` is invoked with the reservoir state each time the step
fires, for logging the `(T(t), μ(t), γ, ℳ̄)` trajectory.

The RNG seed advances per step. On GPU the draws come from CURAND, so seed the
device once per trajectory with `seed_device_rng!` — `seed` then only controls
the CPU path.
"""
function spgpe_callback(
    res::SPGPEReservoir, dt::Real;
    every::Int=1, seed::Union{Nothing, Int}=nothing, noise::Bool=true,
    on_rates=nothing,
)
    every >= 1 || throw(ArgumentError("spgpe_callback: every must be ≥ 1, got $every"))
    dt_eff = Float64(dt) * every
    function (ws, step, args...)
        step % every == 0 || return nothing
        r = apply_spgpe_step!(ws, res, dt_eff;
            t=ws.state.t, noise=noise,
            seed=seed === nothing ? nothing : seed + step)
        on_rates === nothing || on_rates(ws.state.t, r)
        nothing
    end
end

# γ and ℳ̄ are not dials: Rooney Eq. 19 and Eq. 26 fix them from (μ, T, ϵ_cut, a_s),
# and `spgpe_growth_rate` / `spgpe_scattering_rate` evaluate them. Passing a number
# instead is a fit, and a fit here is invisible — it breaks no conservation law, no
# GPU/CPU parity, no oracle, so every gate stays green while the dynamics are set by
# a made-up constant.
#
# It happened: a Kibble–Zurek scan ran at γ = 0.002 and 0.02 against a physical
# 8.2e-4 (T=30) to 5.4e-5 (T=2), i.e. 2.4-370× too fast, which put 1/(2γμ) = 40-622
# outside every τ_Q = 2-32 in the scan. The field never condensed, ξ̂ came out flat
# in τ_Q, and the reported exponent was counting phase noise in an uncondensed
# field. The driver printed "γ=0.002 (FIXED)" in its own header throughout.
#
# So: a pinned rate must agree with the derived one to within a factor of 2, at the
# hot and cold ends of the ramp. `allow_unphysical_rates=true` is the escape hatch
# for deliberate parameter studies — the point is that it has to be typed.
const _RATE_TOL = 2.0

function _check_rate_against_derived(gamma, M, Tw, muw, kw, a_s)
    (gamma === nothing && M === nothing) && return nothing
    for t in (0.0, 1.0)                       # ramp endpoints, in waveform time
        T = evaluate(Tw, t)
        mu = evaluate(muw, t)
        kc = evaluate(kw, t)
        (isfinite(T) && isfinite(mu) && isfinite(kc) && T > 0) || continue
        ec = kc^2 / 2
        ec > mu || continue                   # cutoff below μ: nothing to compare
        for (name, given, f) in (
            ("gamma", gamma, spgpe_growth_rate), ("M", M, spgpe_scattering_rate))
            given === nothing && continue
            d = f(; T, mu, eps_cut=ec, a_s)
            (isfinite(d) && d > 0) || continue
            r = Float64(given) / d
            (r > _RATE_TOL || r < 1 / _RATE_TOL) && throw(
                ArgumentError(
                    "SPGPEReservoir: $name = $given is $(round(r; sigdigits=3))× the value " *
                    "derived from (μ=$mu, T=$T, ϵ_cut=$(round(ec; digits=2)), a_s=$a_s), " *
                    "which is $(round(d; sigdigits=3)). $name is fixed by Rooney Eq. 19/26, " *
                    "not free — omit it to derive it, or pass " *
                    "allow_unphysical_rates=true if the mismatch is the point."),
            )
        end
    end
    nothing
end
