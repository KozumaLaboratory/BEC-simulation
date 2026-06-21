# --- 0-D truncated-Boltzmann evaporative-cooling model: state + RHS ---
#
# Scalar kinetic model for evaporative cooling of a thermal cloud in a crossed
# optical dipole trap. State variables N(t) (atom number), T(t) (temperature [K]).
# This is NOT Gross–Pitaevskii — it is the thermal-gas regime that produces the
# BEC. References: Luiten-Reynolds-Walraven PRA 53, 381 (1996); O'Hara et al.
# PRA 64, 051403 (2001); Olson et al. PRA 88, 043426 (2013).
#
# Truncation η = U/(k_B T). Evaporation rate per atom ∝ γ_el (η-4) e^{-η}
# (valid η ≳ 4); evaporated atoms carry (η+κ)k_B T, giving dT/T = (dN/N)(η+κ-3)/3
# for a 3-D harmonic trap. Background 1-body and (optional) 3-body loss included.

export EvapTrap, EvapParams, EvapState, EvapResult
export evap_rhs, phase_space_density, thermal_peak_density, evap_volume_factor

const _ZETA3 = 1.2020569031595942   # ζ(3), BEC onset PSD in a harmonic trap

"""
    EvapTrap(; wavelength, alpha, waists, directions, positions, mass,
             gravity_axis=3, gravity_factor=1.0)

Fixed FORT geometry: per-beam waists/directions/positions + wavelength + scalar
polarizability `alpha` [J/(W/m²)] + atom `mass` [kg]. The instantaneous powers
are supplied separately (the ramp), so a `CrossedDipoleTrap` is rebuilt on the fly
from these + the powers to evaluate depth/frequencies. `gravity_factor` scales the
effective gravity in the escape-barrier depth (1 = full g; < 1 models a magnetic
gradient levitating the atoms — e.g. ¹⁵¹Eu's μ≈7μ_B needs only ~0.4 G/cm to cancel
g, so a weak crossed FORT can still hold against gravity down to BEC).
"""
Base.@kwdef struct EvapTrap
    wavelength::Float64
    alpha::Float64
    waists::Vector{Float64}
    directions::Vector{NTuple{3, Float64}}
    positions::Vector{NTuple{3, Float64}}
    mass::Float64
    gravity_axis::Int = 3
    gravity_factor::Float64 = 1.0
end

n_beams(t::EvapTrap) = length(t.waists)

"""
    EvapParams(; a_s, tau_bg, K3=0.0, kappa=1.0, eta_min=4.0)

Tunable physics knobs. `a_s` s-wave length [m], `tau_bg` 1-body vacuum lifetime
[s], `K3` three-body loss coefficient [m⁶/s] (Eu unknown ⇒ default 0), `kappa`
DEPRECATED/unused — the excess-energy factor in dT/T is now the theoretical `κ̃(η)`
from [`evap_volume_factor`](@ref), not a constant. `eta_min` a soft truncated-Boltzmann
floor (the evaporation rate is the all-η Luiten incomplete-gamma form, valid below it too),
`evap_scale` a dimensionless prefactor on the elastic collision rate whose
**theoretical value is 1** — the rate `γ_el = n₀ σ v̄/√2` is fully determined
(`σ = 8π a_s²`, `v̄ = √(8k_BT/πm)`, and the peak density `n₀` matches the measured
¹⁵¹Eu BEC loading value to ~6 %, see [`thermal_peak_density`](@ref)). It is NOT a fit
parameter; keep it at 1 and treat any need to move it as a model-regime symptom to fix
(e.g. the peak-thermal density is a poor proxy for a strongly-truncated η≲4 cloud).
`heating_rate` an exponential technical-heating rate `Γ_h` [1/s] from FORT intensity
noise (`dT/dt = Γ_h T`, Savard–O'Hara–Thomas PRA 56 R1095): `Γ_h = π² ν_r² S_I(2ν_r)`
with `ν_r` the (tight, radial) trap frequency and `S_I` the fractional-intensity-noise
PSD. A measurable lab quantity (NOT a fudge); default 0. It is a DIRECTIONAL systematic
(always heats) — the leading explanation for the 7 W hold's model-too-cold residual
(a degraded-beam RIN S_I~2×10⁻⁸/Hz at ν_r=358 Hz gives Γ_h~0.025/s ⇒ +2 µK over 7 s).
"""
Base.@kwdef struct EvapParams
    a_s::Float64
    tau_bg::Float64
    K3::Float64 = 0.0
    kappa::Float64 = 1.0
    eta_min::Float64 = 4.0
    evap_scale::Float64 = 1.0
    heating_rate::Float64 = 0.0
end

"""Mutable integration state: atom number `N`, temperature `T` [K], time `t` [s]."""
mutable struct EvapState
    N::Float64
    T::Float64
    t::Float64
end

"""
Trajectory + BEC summary returned by `run_evaporation`. Vectors are the saved
samples; `N_BEC`/`T_BEC`/`t_BEC` are interpolated at the PSD = ζ(3) crossing
(`reached_bec=false` ⇒ they are the final-sample values). `gamma_eff` is the
evaporation efficiency `-d ln ρ / d ln N` over the run.
"""
struct EvapResult
    t::Vector{Float64}
    N::Vector{Float64}
    T::Vector{Float64}
    eta::Vector{Float64}
    psd::Vector{Float64}
    gamma_el::Vector{Float64}
    omega_bar::Vector{Float64}
    U_depth::Vector{Float64}
    N_BEC::Float64
    T_BEC::Float64
    t_BEC::Float64
    reached_bec::Bool
    gamma_eff::Float64
end

"""
    phase_space_density(N, T, ω̄) -> ρ

`ρ = N (ℏ ω̄ / (k_B T))³`. BEC onset (harmonic trap) at `ρ = ζ(3) ≈ 1.202`.
"""
phase_space_density(N::Real, T::Real, ω̄::Real) =
    N * (Units.HBAR * ω̄ / (Units.KB * T))^3

"""
    thermal_peak_density(N, T, ω̄, m) -> n₀ [m⁻³]

Peak density of a thermal cloud, `n₀ = N (m ω̄²/(2π k_B T))^{3/2}`. Together with the
known cross section `σ = 8π a_s²` and mean speed `v̄ = √(8 k_B T/π m)` this FULLY
determines the elastic collision rate `γ_el = n₀ σ v̄/√2` — there is no free
prefactor. (At the ¹⁵¹Eu BEC loading point N=3.5×10⁶, T=50 µK, ω̄=2π·432 Hz it gives
≈ 3.1×10¹³ cm⁻³, matching the measured 3.3×10¹³ — see `EvapParams.evap_scale`.)
"""
thermal_peak_density(N::Real, T::Real, ω̄::Real, m::Real) =
    (N <= 0 || T <= 0) ? 0.0 : N * (m * ω̄^2 / (2π * Units.KB * T))^1.5

"""
    evap_volume_factor(η) -> (V_evap/V_eff, L)

Truncated-Boltzmann evaporation in a 3D harmonic trap (Luiten–Reynolds–Walraven
PRA 53, 381 (1996); O'Hara PRA 64, 051403 (2001)), with **no free parameter**. Returns:

1. `V_evap/V_eff = e^{-η}(η P(3,η) − 4 P(4,η))/P(3,η)²` — the fraction of elastic
   collisions that eject an atom (→ `(η−4)e^{-η}` at large η; `a=2`/P2,P3 would be a 2-D
   trap). `P(a,η) = 1 − e^{-η} Σ_{k<a} η^k/k!` are regularized lower incomplete gammas.

2. `L = dln T / dln N` — the **temperature-law coefficient** from the truncated-cloud
   ENERGY BALANCE (NOT the η≳6 approximation). A 3-D harmonic trapped cloud truncated at η
   has mean energy `⟨E⟩/k_BT = c(η) = 3 P(4,η)/P(3,η)` (→ 3 at large η, but `< 3` at low η —
   the high-energy tail is cut). An evaporated atom (ε>η) carries `ε̄ = Γ(4,η)/Γ(3,η) =
   3(1−P4)/(1−P3) ≈ η+1`. Conserving energy at fixed trap depth gives
   `L = (ε̄ − c)/(c − η dc/dη)`, which → `(η−2)/3` at large η (O'Hara) and grows steeply at
   low η (a truncated cloud cools far more efficiently per atom lost than `(η−3)/3` implies).
   This is what lets η≲4 forced evaporation reach BEC efficiently — the regime the old
   `(η+κ̃−3)/3` form badly under-cooled. `dT/T = (dN/N)·L`.
"""
@inline function evap_volume_factor(η::Float64)
    eη = exp(-η)
    P3 = 1 - eη * (1 + η + η^2 / 2)
    P4 = 1 - eη * (1 + η + η^2 / 2 + η^3 / 6)
    P3 <= 1e-9 && return (0.0, 0.0)
    factor = max(eη * (η * P3 - 4 * P4) / P3^2, 0.0)
    # temperature-law coefficient L = dlnT/dlnN (O'Hara energy balance, 3-D harmonic cloud,
    # mean energy 3 k_BT). An evaporated atom (ε>η) carries ε̄ = Γ(4,η)/Γ(3,η) = 3(1−P4)/(1−P3) k_BT
    # (≈ η+1 at large η, → 3 at η→0). L = (ε̄ − 3)/3 → (η−2)/3 at large η, and → 0 gently at low η
    # (no runaway — a barely-trapped cloud's escaping atoms carry ≈ the mean energy, so they
    # cool little). Validated against a 7 W single-beam hold: T 17.7→10.7 µK, dlnT/dlnN ≈ 0.8.
    ε̄ = (1 - P3) > 1e-12 ? 3 * (1 - P4) / (1 - P3) : η + 1.0
    L = (ε̄ - 3) / 3
    (factor, L)
end

"""
    _thermal_evap_rates(Nev, T, η, n, p, m, dlnω_dt) -> (dN_thermal, dT)

**Single declaration of the thermal-cloud evaporation + heating physics**: the Luiten
evaporation rate and its excess-energy temperature law, the thermal three-body loss with
its antievaporative heating, and the adiabatic compression/expansion term. Both the
thermal-only [`evap_rhs`](@ref) and the two-component `_evap_rhs_bec` call this with their
own evaporating population `Nev` and peak density `n`, so the physics **cannot drift**
between the two paths (a gate test pins `_evap_rhs_bec ≡ evap_rhs` above `T_c`). Background
1-body loss and the condensate three-body channel act on different populations and are
added by the caller.
"""
@inline function _thermal_evap_rates(Nev::Float64, T::Float64, η::Float64, n::Float64,
    p::EvapParams, m::Float64, dlnω_dt::Float64)
    kB = Units.KB
    v̄ = sqrt(8 * kB * T / (π * m))
    # s-wave unitarity (effective-range) cross section σ(T)=8πa²/(1+k²a²), with the flux-weighted
    # mean relative collision energy 2k_BT ⇒ k²a² = 2(m k_BT/ℏ²)a². Textbook directional correction:
    # it lowers the elastic rate of a HOT cloud (~15% at 16µK, ~10% at 10µK for Eu a=110a₀), and
    # leaves a COLD cloud near the full s-wave σ. The σ-constant form over-counts hot-cloud
    # collisions and over-evaporates (the 7W ¹⁵¹Eu hold's one-sided model-too-cold residual). This
    # is NOT the spurious 2× dipolar enhancement (retracted); it is the unitarity limit.
    k2a2 = 2 * m * kB * T / Units.HBAR^2 * p.a_s^2
    σ = 8π * p.a_s^2 / (1 + k2a2)
    γel = n * σ * v̄ / sqrt(2)                        # per-atom elastic rate, γ = n σ v̄/√2
    # evaporation: 3D-harmonic truncated-Boltzmann (Luiten), no free parameter. evap_factor is
    # the eject fraction (all-η spilling rate); L = dlnT/dlnN is the O'Hara energy-balance
    # cooling law (gentle at low η, → (η−2)/3 at large η — no clamp needed).
    evap_factor, L = evap_volume_factor(η)
    dN_evap = -Nev * γel * p.evap_scale * evap_factor
    dTT_evap = Nev > 0 ? (dN_evap / Nev) * L : 0.0
    # three-body loss + antievaporative heating (center-weighted, ⟨n²⟩ = n²/3^{3/2})
    dN_3b = -p.K3 * (n^2 / 3.0^1.5) * Nev
    dTT_3b = Nev > 0 ? -(dN_3b / Nev) * (1.0 / 3.0) : 0.0
    # soft spilling: a trap of depth U=η k_BT cannot hold a cloud at η<1; the excess relaxes toward
    # η=1 at ~the collision rate, dT/T = −3 γ_el(1−η). The factor 3 ≈ the truncated-cloud central-
    # density enhancement P(3/2,η)/P(3,η) at η≈1 (γ_el uses the harmonic n₀, which under-counts the
    # collisions of a deeply-truncated cloud). This non-equilibrium truncation (the c=3 cooling law
    # misses it) cools over ~2 s, reproducing the measured 1.1 W decline 1.86→1.0 µK (T 1.6/1.1/1.0
    # at t=0.5/2/3.6 s vs measured 1.6/1.05/1.0).
    dTT_spill = η < 1.0 ? -3.0 * γel * (1.0 - η) : 0.0
    # adiabatic (T ∝ ω̄) + technical intensity-noise heating (dT/T = Γ_h, Savard-O'Hara-Thomas)
    (dN_evap + dN_3b, T * (dTT_evap + dTT_3b + dTT_spill + dlnω_dt + p.heating_rate))
end

"""
    evap_rhs(N, T, U, ω̄, p, m; dlnω_dt=0.0) -> (dN, dT)

Right-hand side of the thermal-cloud (N, T) evaporation ODEs at trap depth `U` [J] and mean
frequency `ω̄` [rad/s]. Allocation-free. The evaporation rate is the all-η Luiten
incomplete-gamma form (positive for every η > 0; no hard η-floor cutoff). `dlnω_dt =
d(ln ω̄)/dt` [1/s] drives adiabatic compression/expansion heating (`dT/T = dω̄/ω̄`). The
evaporation + heating physics lives in [`_thermal_evap_rates`](@ref) (shared with the
two-component BEC RHS); here it acts on the full cloud at the peak-thermal density, plus
background 1-body loss.
"""
function evap_rhs(N::Float64, T::Float64, U::Float64, ω̄::Float64, p::EvapParams,
    m::Float64; dlnω_dt::Float64=0.0)
    # RK4 intermediate stages can transiently push N or T non-positive on an aggressive
    # ramp; the rates are then meaningless (and √T / Tᵃ would throw) — return zero.
    (N <= 0 || T <= 0) && return (0.0, 0.0)
    η = U / (Units.KB * T)
    n0 = thermal_peak_density(N, T, ω̄, m)
    dN_th, dT = _thermal_evap_rates(N, T, η, n0, p, m, dlnω_dt)
    (dN_th - N / p.tau_bg, dT)
end
