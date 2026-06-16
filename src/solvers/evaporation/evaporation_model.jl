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
export evap_rhs, phase_space_density

const _ZETA3 = 1.2020569031595942   # ζ(3), BEC onset PSD in a harmonic trap

"""
    EvapTrap(; wavelength, alpha, waists, directions, positions, mass, gravity_axis=3)

Fixed FORT geometry: per-beam waists/directions/positions + wavelength + scalar
polarizability `alpha` [J/(W/m²)] + atom `mass` [kg]. The instantaneous powers
are supplied separately (the ramp), so a `CrossedDipoleTrap` is rebuilt on the fly
from these + the powers to evaluate depth/frequencies.
"""
Base.@kwdef struct EvapTrap
    wavelength::Float64
    alpha::Float64
    waists::Vector{Float64}
    directions::Vector{NTuple{3, Float64}}
    positions::Vector{NTuple{3, Float64}}
    mass::Float64
    gravity_axis::Int = 3
end

n_beams(t::EvapTrap) = length(t.waists)

"""
    EvapParams(; a_s, tau_bg, K3=0.0, kappa=1.0, eta_min=4.0)

Tunable physics knobs. `a_s` s-wave length [m], `tau_bg` 1-body vacuum lifetime
[s], `K3` three-body loss coefficient [m⁶/s] (Eu unknown ⇒ default 0), `kappa`
the excess-energy factor in dT/T, `eta_min` a soft truncated-Boltzmann floor (the
evaporation rate is the all-η Luiten incomplete-gamma form, valid below it too),
`evap_scale` a dimensionless calibration prefactor on the elastic collision rate
(< 1 when the cloud is less dense than the peak-thermal estimate, e.g. gravity sag).
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
    evap_rhs(N, T, U, ω̄, p, m; dlnω_dt=0.0) -> (dN, dT)

Right-hand side of the (N, T) evaporation ODEs at trap depth `U` [J] and mean
frequency `ω̄` [rad/s]. Allocation-free. The evaporation rate is the all-η Luiten
incomplete-gamma form (positive for every η > 0; no hard η-floor cutoff).
`dlnω_dt = d(ln ω̄)/dt` [1/s] is the instantaneous logarithmic rate of change of the
trap frequency from the ramp; it drives adiabatic compression/expansion heating
(`dT/T = dω̄/ω̄`, since `T ∝ ω̄` keeps the phase-space density invariant under a
pure harmonic-trap change). Without it, re-tightening the trap would raise ρ for
free — a non-physical path the optimizer exploits.
"""
function evap_rhs(N::Float64, T::Float64, U::Float64, ω̄::Float64, p::EvapParams,
    m::Float64; dlnω_dt::Float64=0.0)
    kB = Units.KB
    η = U / (kB * T)
    # peak density n₀ = N (m ω̄² / (2π k_B T))^{3/2}
    n0 = N * (m * ω̄^2 / (2π * kB * T))^1.5
    v̄ = sqrt(8 * kB * T / (π * m))
    σ = 8π * p.a_s^2
    γel = n0 * σ * v̄ / sqrt(2)                       # per-atom elastic rate

    # evaporation (truncated Boltzmann, Luiten-Reynolds-Walraven incomplete-gamma form,
    # valid for ALL η): rate ∝ e^{-η}(η·P(2,η) − 3·P(3,η))/P(2,η)², with the regularized
    # lower incomplete gammas P(2,η)=1−e^{-η}(1+η), P(3,η)=1−e^{-η}(1+η+η²/2) in closed
    # form. → ~(η−3)e^{-η} at large η, stays positive (spilling) at low η — no hard cutoff.
    eη = exp(-η)
    P2 = 1 - eη * (1 + η)
    P3 = 1 - eη * (1 + η + η^2 / 2)
    evap_factor = P2 > 1e-9 ? max(eη * (η * P2 - 3 * P3) / P2^2, 0.0) : 0.0
    dN_evap = -N * γel * p.evap_scale * evap_factor
    dTT_evap = N > 0 ? (dN_evap / N) * (η + p.kappa - 3) / 3 : 0.0

    # background 1-body loss
    dN_bg = -N / p.tau_bg

    # three-body loss + antievaporative heating (center-weighted, ⟨n²⟩ = n₀²/3^{3/2})
    n2avg = n0^2 / 3.0^1.5
    dN_3b = -p.K3 * n2avg * N
    dTT_3b = N > 0 ? -(dN_3b / N) * (1.0 / 3.0) : 0.0

    # adiabatic compression/expansion from the ramped trap (T ∝ ω̄)
    dTT_adia = dlnω_dt

    dN = dN_evap + dN_bg + dN_3b
    dT = T * (dTT_evap + dTT_3b + dTT_adia)
    (dN, dT)
end
