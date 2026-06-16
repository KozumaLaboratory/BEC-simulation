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
"""
Base.@kwdef struct EvapParams
    a_s::Float64
    tau_bg::Float64
    K3::Float64 = 0.0
    kappa::Float64 = 1.0
    eta_min::Float64 = 4.0
    evap_scale::Float64 = 1.0
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
    evap_volume_factor(η) -> (V_evap/V_eff, κ̃)

Truncated-Boltzmann evaporation in a 3D harmonic trap (Luiten–Reynolds–Walraven
PRA 53, 381 (1996); Sackett et al.), with **no free parameter**. Returns the ratio
of evaporation to effective volume — the fraction of elastic collisions that eject an
atom — `V_evap/V_eff = e^{-η}(η P(3,η) − 4 P(4,η))/P(3,η)²`, and the excess-energy
parameter `κ̃ = [1 − P(5,η)/P(3,η)]/[η − 4 P(4,η)/P(3,η)]` (energy carried by an
evaporated atom beyond η k_B T, sets `dT/T = (dN/N)(η+κ̃−3)/3`). The `P(a,η)` are
regularized lower incomplete gammas, closed form for integer `a`:
`P(a,η) = 1 − e^{-η} Σ_{k<a} η^k/k!`. The `a=3` (P3,P4) values are the 3D-harmonic
case (`a=2` would be a 2-D trap). → `(η−3)e^{-η}`, `κ̃→0` at large η; positive
(spilling) at low η.
"""
@inline function evap_volume_factor(η::Float64)
    eη = exp(-η)
    P3 = 1 - eη * (1 + η + η^2 / 2)
    P4 = 1 - eη * (1 + η + η^2 / 2 + η^3 / 6)
    P5 = 1 - eη * (1 + η + η^2 / 2 + η^3 / 6 + η^4 / 24)
    P3 <= 1e-9 && return (0.0, 0.0)
    factor = max(eη * (η * P3 - 4 * P4) / P3^2, 0.0)
    denom = η - 4 * P4 / P3
    κ̃ = abs(denom) > 1e-9 ? (1 - P5 / P3) / denom : 0.0
    (factor, κ̃)
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
    γel = n * 8π * p.a_s^2 * v̄ / sqrt(2)             # per-atom elastic rate, γ = n σ v̄/√2
    # evaporation: 3D-harmonic truncated-Boltzmann (Luiten), no free parameter.
    evap_factor, κ̃ = evap_volume_factor(η)
    dN_evap = -Nev * γel * p.evap_scale * evap_factor
    dTT_evap = Nev > 0 ? (dN_evap / Nev) * (η + κ̃ - 3) / 3 : 0.0
    # three-body loss + antievaporative heating (center-weighted, ⟨n²⟩ = n²/3^{3/2})
    dN_3b = -p.K3 * (n^2 / 3.0^1.5) * Nev
    dTT_3b = Nev > 0 ? -(dN_3b / Nev) * (1.0 / 3.0) : 0.0
    # adiabatic compression/expansion from the ramped trap (T ∝ ω̄)
    (dN_evap + dN_3b, T * (dTT_evap + dTT_3b + dlnω_dt))
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
