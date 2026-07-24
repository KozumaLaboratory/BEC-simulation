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
    EvapParams(; a_s, tau_bg, K3=0.0, eta_min=4.0, heating_rate=0.0)

Physics inputs — **no fit parameters** (the truncated-Boltzmann rates are fully determined
by these + the trap geometry). `a_s` s-wave length [m]; `tau_bg` 1-body vacuum lifetime [s];
`K3` three-body loss coefficient [m⁶/s] in the **atoms-lost convention `dN/dt = −K₃⟨n²⟩N`**,
i.e. `K₃ ≡` the thesis's Söding `L₃` (atom-loss coefficient; 3 atoms leave per recombination
event are folded into `K₃`). Eu measured ⇒ `L ∼ 10⁻²⁹ cm⁶/s = 1×10⁻⁴¹ m⁶/s` (thesis Fig 7.5,
consistent with the universal-van-der-Waals estimate — see `euv3.jl`). `eta_min` is a **validity/reporting flag
only**: the LRW evaporation rate is the all-η incomplete-gamma form and is NOT gated by it —
the truncated-Boltzmann model itself degrades as η→1 (LRW require kT≪ε_t), and `eta_min` just
marks where to distrust the output. `heating_rate` an exponential technical-heating rate `Γ_h`
[1/s] from FORT intensity noise (`dT/dt = Γ_h T`, Savard–O'Hara–Thomas PRA 56 R1095):
`Γ_h = π² ν_r² S_I(2ν_r)`, `ν_r` the tight radial frequency, `S_I` the fractional-intensity-
noise PSD. A measurable lab quantity (NOT a fudge); default 0. Directional (always heats) — the
leading explanation for the 7 W hold's model-too-cold residual (RIN S_I~2×10⁻⁸/Hz at ν_r=358 Hz
⇒ Γ_h~0.025/s ⇒ +2 µK over 7 s).
"""
Base.@kwdef struct EvapParams
    a_s::Float64
    tau_bg::Float64
    K3::Float64 = 0.0
    eta_min::Float64 = 4.0
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

Peak density of an UNtruncated thermal harmonic cloud, `n_pk = N (m ω̄²/(2π k_B T))^{3/2}`.
The LRW evaporation/collision rate uses the **reference** density `n₀ = n_pk/P(3,η)` (the
truncated-Boltzmann partition correction, [`evap_volume_factor`](@ref)); `n_pk` itself sets the
three-body `⟨n²⟩ = n_pk²/3^{3/2}`. (At the ¹⁵¹Eu BEC loading point N=3.5×10⁶, T=50 µK,
ω̄=2π·432 Hz `n_pk ≈ 3.1×10¹³ cm⁻³`, matching the measured 3.3×10¹³.)
"""
thermal_peak_density(N::Real, T::Real, ω̄::Real, m::Real) =
    (N <= 0 || T <= 0) ? 0.0 : N * (m * ω̄^2 / (2π * Units.KB * T))^1.5

"""
    evap_volume_factor(η) -> (factor, L)

Truncated-Boltzmann (Luiten–Reynolds–Walraven PRA 53 381 (1996); O'Hara PRA 64 051403 (2001);
Gehm thesis §2.4.2) evaporation kinetics for a 3-D harmonic trap — **parameter-free**, from the
regularized lower incomplete gammas `P(a,η) = 1 − e^{-η} Σ_{k<a} η^k/k!` (elementary at integer a).

1. `factor = e^{-η}(η P(3,η) − 4 P(4,η))/P(3,η)²` — the eject factor s.t. the per-atom
   evaporation rate is `dN/dt|_evap = −N · n_pk σ v̄ · factor`, i.e. `−N · n₀ σ v̄ · e^{-η}(η −
   4P4/P3)` with the LRW **reference** density `n₀ = n_pk/P(3,η)` (the `1/P(3,η)` — folded into
   the `P(3,η)²` denominator here — is the truncated-cloud partition correction; there is NO
   free prefactor and `v̄ = √(8k_BT/πm)` carries NO extra 1/√2). → `(η−4)e^{-η}` at large η;
   `max(·,0)` clamps it where `η P(3,η) − 4 P(4,η) ≤ 0` (the trap can no longer eject — the
   first-principles replacement for a hard η floor).

2. `L = dln T/dln N` — the **EXACT** truncated-cloud energy-balance cooling law at fixed depth.
   A cloud truncated at η has mean energy per atom `c(η) = 3 P(4,η)/P(3,η)` (→ 3 at large η, `< 3`
   at low η — the tail is cut). Each **evaporated** atom carries `ε_ev = ε_t + W_ev/V_ev = η + 1 −
   P(5,η)/V_ev`, `V_ev = η P(3,η) − 4 P(4,η)` (LRW Eq 40-42; NOT the mean tail energy). Energy
   conservation gives `L = (ε_ev − c)/(c − η dc/dη)`, `dc/dη = 3(P₃P₄′ − P₄P₃′)/P₃²`,
   `P_a′ = η^{a-1}e^{-η}/(a-1)!`. → `(η−2)/3` at large η (O'Hara); GROWS at low η (a truncated
   cloud's reduced heat capacity `c − η dc/dη` cools it far more per atom lost — the physics that
   lets η≲5 forced evaporation reach BEC). `dT/T = (dN/N)·L`.

The trap-lowering (adiabatic) term `dT/T = dω̄/ω̄` is added SEPARATELY by the caller; on a fixed-η
lowered-ODT trajectory (ω̄²∝U∝T ⇒ dω̄/ω̄ = ½ dT/T) the two combine to O'Hara's `2(η'−3)/3`
(Gehm Eq 2.32) — the separation is exact, not double-counted.
"""
@inline function evap_volume_factor(η::Float64)
    eη = exp(-η)
    P3 = 1 - eη * (1 + η + η^2 / 2)
    P4 = 1 - eη * (1 + η + η^2 / 2 + η^3 / 6)
    P5 = 1 - eη * (1 + η + η^2 / 2 + η^3 / 6 + η^4 / 24)
    P3 <= 1e-9 && return (0.0, 0.0)
    Vev = η * P3 - 4 * P4                                 # V_ev/(λ³ζ∞), harmonic
    factor = Vev > 0 ? eη * Vev / P3^2 : 0.0             # eject factor (reference density folded in)
    Vev <= 1e-12 && return (factor, 0.0)                 # trap cannot eject ⇒ no evap cooling
    ε_ev = η + 1 - P5 / Vev                              # energy per evaporated atom, ε_t + W_ev/V_ev
    c = 3 * P4 / P3                                      # mean energy per atom, → 3
    dP3 = η^2 * eη / 2                                   # P(a,η)′ = η^{a-1} e^{-η}/(a-1)!
    dP4 = η^3 * eη / 6
    dc = 3 * (P3 * dP4 - P4 * dP3) / P3^2
    denom = c - η * dc                                   # reduced (truncated) heat capacity per atom
    # denom stays > 1.7 for η ≳ 5 (the valid regime); floor it only as an RK4 safety rail against
    # excursions into the η ≲ 2 model-breakdown region (LRW require kT ≪ ε_t).
    L = (ε_ev - c) / max(denom, 0.1)
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
    # LRW evaporation rate dN/dt = −N · n_pk σ v̄ · factor (Eq 37 + 42a), fully determined — no free
    # prefactor, no 1/√2 (v̄ = √(8k_BT/πm) is already the mean relative speed). `factor` folds in the
    # reference-density 1/P(3,η) correction; `n` is the untruncated peak n_pk. The s-wave unitarity
    # σ(T)=8πa²/(1+k²a²) [k²a²=2(m k_BT/ℏ²)a², flux-weighted 2k_BT] is real physics beyond bare LRW —
    # it lowers the elastic rate of a HOT cloud (~15% at 16µK for Eu a=110a₀), leaves a COLD cloud at
    # full s-wave σ. NOT the retracted 2× dipolar enhancement.
    evap_factor, L = evap_volume_factor(η)
    dN_evap = -Nev * n * σ * v̄ * evap_factor
    dTT_evap = Nev > 0 ? (dN_evap / Nev) * L : 0.0
    # three-body loss, atoms-lost convention dN = −K₃⟨n²⟩N with ⟨n²⟩ = n_pk²/3^{3/2} (thermal
    # harmonic cloud) + antievaporation heating: 3-body removes the densest/coldest atoms
    # (ε̄_lost = 2k_BT vs cloud 3k_BT) ⇒ dT/T = −(1/3) dN/N (derived, not fitted).
    dN_3b = -p.K3 * (n^2 / 3.0^1.5) * Nev
    dTT_3b = Nev > 0 ? -(dN_3b / Nev) * (1.0 / 3.0) : 0.0
    # adiabatic (T ∝ ω̄) + technical intensity-noise heating (dT/T = Γ_h, Savard-O'Hara-Thomas)
    (dN_evap + dN_3b, T * (dTT_evap + dTT_3b + dlnω_dt + p.heating_rate))
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
