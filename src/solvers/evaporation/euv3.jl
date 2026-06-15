# --- euv3 lab FORT calibration + the experimental evaporation ramp ---
#
# Site-measured FORT power ↔ control-voltage calibration and the actual
# evaporation power schedule, transcribed from the Kozuma-lab sequence control
# program `euv3 r14`. The control script specifies FORT powers directly in Watts
# (e.g. `vHFORTPow(6)`), so `euv3_evaporation_ramp` needs no lab unknowns — only
# the trap GEOMETRY (waists, α) is still a notebook input for `EvapTrap`.
#
# Power calibrations (control voltage `V` as a function of power `P` [W]):
#   vHFORT(P) = (P + 0.0010) / 0.6198     (≤ 6.0 W @ I_amp 7000 mA)
#   vVFORT(P) = (P + 0.0027) / 0.5739     (≤ 5.5 W)
#   vSFORT(P) = (P - 0.0024) / 0.5246     (≤ 2.0 W)
# (2023-10-13 slope, 2023-12-12 low-power offset.) Inverses give P(V).

export hfort_volts, vfort_volts, sfort_volts
export hfort_power, vfort_power, sfort_power
export euv3_evaporation_ramp, euv3_evap_trap, run_euv3_evaporation, optimize_euv3_evaporation
export euv3_defaults, calibrate_polarizability

# --- Researched TENTATIVE defaults (Miyazawa/Matsui et al., PRL 129, 223401 (2022),
# arXiv:2207.11692). Replace with the current euv3 r14 notebook values when known. ---
# ODT 1550 nm fiber laser; horizontal waist 31 µm, vertical 42 µm; 2 beams (H+V,
# the euv3 SFORT is off in the 縦横 config). Start of evaporation 3.5e6 atoms @ 50 µK;
# BEC 5.02e4 atoms @ 349 nK. a_s = 110 a₀ (Eu151).
const _EUV3_WAVELENGTH = 1550e-9
const _EUV3_WAISTS = [31e-6, 42e-6, 42e-6]   # H, V, S(unused)
# α ≈ 1.25e-36 J/(W/m²) (≈ 400 a.u.): CALIBRATED from the measured final-trap
# frequencies (νx,νy,νz)=(97,226,217) Hz at the euv3 ramp-endpoint powers
# (HFORT 0.14 W / VFORT 0.09 W) — νz (H 31 µm, 0.14 W) ⇒ 1.21e-36 and νx
# (V 42 µm, 0.09 W) ⇒ 1.26e-36 agree, so α ≈ 1.25e-36. Eu ⁸S₇/₂ is an S-state ⇒
# scalar/near-static; this is NOT a published number — pin it with
# `calibrate_polarizability` once a direct light-shift / trap-freq + power is known.
# (At this α the euv3 start (HFORT 6 W) gives η ≈ 7 at 50 µK, so evaporation runs.)
const _EUV3_ALPHA = 1.25e-36
const _EUV3_N0 = 3.5e6
const _EUV3_T0 = 50e-6
const _EUV3_TAU_BG = 15.0                    # not in the paper; typical lanthanide ODT
# K3 ≈ 1e-40 m⁶/s: a single-parameter FIT, not a measurement — Eu's 3-body rate is
# unmeasured. With α/τ_bg/ramp fixed, K3=1e-40 brings the predicted endpoint to
# N_BEC ≈ 4.9e4, T_BEC ≈ 0.53 µK, matching the measured 5.0e4 @ 349 nK to ~1.5×.
# 3-body loss limits N at the high density near BEC (K3=0 over-predicts N by ~20×).
# In the lanthanide range (Dy/Er ~1e-41…1e-40). Refit once Eu K3 / current data exist.
const _EUV3_K3 = 1e-40

hfort_volts(P_W::Real) = (P_W + 0.0010) / 0.6198
vfort_volts(P_W::Real) = (P_W + 0.0027) / 0.5739
sfort_volts(P_W::Real) = (P_W - 0.0024) / 0.5246

hfort_power(V::Real) = 0.6198 * V - 0.0010
vfort_power(V::Real) = 0.5739 * V - 0.0027
sfort_power(V::Real) = 0.5246 * V + 0.0024

"""
    euv3_evaporation_ramp() -> FortRamp

The `euv3 r14` evaporative-cooling power schedule (Watts), beams ordered
`[HFORT, VFORT, SFORT]`. Nine linear segments over 2.7 s ending in the
"縦横" (vertical+horizontal) trap config; SFORT stays off (the "横横" alternative
that ramps SFORT is commented out in the lab script). Breakpoint times are the
cumulative segment durations: 0.3, 0.5, 0.4, 0.6, 0.3, 0.2, 0.1, 0.2, 0.1 s.
"""
function euv3_evaporation_ramp()
    times = [0.0, 0.3, 0.8, 1.2, 1.8, 2.1, 2.3, 2.4, 2.6, 2.7]
    hfort = [6.0, 4.0, 2.0, 1.0, 0.56, 0.26, 0.16, 0.12, 0.099, 0.14]
    vfort = [0.0, 1.8, 1.7, 1.6, 1.5, 1.4, 1.0, 0.6, 0.09, 0.09]
    sfort = zeros(length(times))
    FortRamp(times, permutedims(hcat(hfort, vfort, sfort)))
end

# Default euv3 crossed-trap beam axes: HFORT horizontal (x), VFORT vertical (z),
# SFORT second horizontal (y). All cross at the origin.
const _EUV3_DIRECTIONS = [(1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)]

"""
    euv3_evap_trap(; waists, alpha, wavelength, directions, positions, mass, gravity_axis)
        -> EvapTrap

Build the euv3 crossed FORT geometry. `waists` is a 3-vector [m] (H, V, S) or a
single scalar applied to all three; `alpha` is the Eu scalar polarizability
[J/(W/m²)]. Every argument defaults to `euv3_defaults()` (1550 nm, H 31 µm/V 42 µm,
calibrated α).
"""
function euv3_evap_trap(; waists=_EUV3_WAISTS, alpha::Real=_EUV3_ALPHA,
    wavelength::Real=_EUV3_WAVELENGTH,
    directions=_EUV3_DIRECTIONS, positions=fill((0.0, 0.0, 0.0), 3),
    mass::Real=Eu151.mass, gravity_axis::Int=3)
    w = waists isa Real ? fill(Float64(waists), 3) : collect(Float64, waists)
    EvapTrap(; wavelength=Float64(wavelength), alpha=Float64(alpha), waists=w,
        directions=directions, positions=positions, mass=Float64(mass), gravity_axis=gravity_axis)
end

"""
    run_euv3_evaporation(; waists, alpha, N0, T0, tau_bg, K3, a_s, trap_kwargs...) -> EvapResult

One-call evaporation of the euv3 ramp: build the trap from `waists`/`alpha`
(+ optional geometry overrides), then `run_evaporation` over `euv3_evaporation_ramp`
from `(N0, T0)`. All default to `euv3_defaults()`; with those defaults the predicted
endpoint (N_BEC ≈ 4.9e4 @ 0.53 µK) matches the measured 5.0e4 @ 349 nK (the K3=1e-40
default is fitted to that — see `_EUV3_K3`).
"""
function run_euv3_evaporation(; waists=_EUV3_WAISTS, alpha::Real=_EUV3_ALPHA,
    N0::Real=_EUV3_N0, T0::Real=_EUV3_T0,
    tau_bg::Real=_EUV3_TAU_BG, K3::Real=_EUV3_K3, a_s::Real=Eu151.a_s, trap_kwargs...)
    trap = euv3_evap_trap(; waists=waists, alpha=alpha, trap_kwargs...)
    p = EvapParams(; a_s=Float64(a_s), tau_bg=Float64(tau_bg), K3=Float64(K3))
    run_evaporation(trap, euv3_evaporation_ramp(), p; N0=Float64(N0), T0=Float64(T0))
end

"""
    optimize_euv3_evaporation(; waists, alpha, N0, T0, tau_bg=10.0, K3=0.0,
                              a_s=Eu151.a_s, bounds, n_init, n_iter, trap_kwargs...)

One-call Bayesian optimization of the euv3 FORT ramp (3-parameter transform of the
lab schedule) to maximize `N_BEC`. Returns `(; bo, ramp, result)`.
"""
function optimize_euv3_evaporation(; waists=_EUV3_WAISTS, alpha::Real=_EUV3_ALPHA,
    N0::Real=_EUV3_N0, T0::Real=_EUV3_T0,
    tau_bg::Real=_EUV3_TAU_BG, K3::Real=_EUV3_K3, a_s::Real=Eu151.a_s,
    bounds::Vector{Tuple{Float64, Float64}}=[(1.0, 5.0), (0.005, 0.05), (0.5, 3.0)],
    n_init::Int=8, n_iter::Int=40, trap_kwargs...)
    trap = euv3_evap_trap(; waists=waists, alpha=alpha, trap_kwargs...)
    p = EvapParams(; a_s=Float64(a_s), tau_bg=Float64(tau_bg), K3=Float64(K3))
    optimize_evaporation_ramp(trap, p, euv3_evaporation_ramp();
        N0=Float64(N0), T0=Float64(T0), bounds=bounds, n_init=n_init, n_iter=n_iter)
end

"""
    euv3_defaults() -> NamedTuple

The researched TENTATIVE lab inputs used as defaults, with provenance. From
Miyazawa/Matsui et al. PRL 129, 223401 (2022) (arXiv:2207.11692) unless noted.
`alpha` and `tau_bg` are estimates (see field notes); replace with current euv3 r14
notebook values. Also carries the measured BEC endpoint for validation.
"""
euv3_defaults() = (
    wavelength=_EUV3_WAVELENGTH,           # 1550 nm fiber-laser ODT
    waists=copy(_EUV3_WAISTS),             # H 31 µm, V 42 µm (S unused)
    alpha=_EUV3_ALPHA,                     # ≈400 a.u., calibrated from measured trap freqs — NOT published
    N0=_EUV3_N0,                           # 3.5e6 atoms at start of evaporation
    T0=_EUV3_T0,                           # 50 µK
    tau_bg=_EUV3_TAU_BG,                   # 15 s estimate (not in paper)
    K3=_EUV3_K3,                           # 1e-40 m⁶/s FIT to reproduce N_BEC — NOT measured
    a_s=Eu151.a_s,                         # 110 a₀
    measured_N_BEC=5.02e4,                 # validation target
    measured_T_BEC=349e-9,                 # 349 nK
    measured_trap_freqs_Hz=(97.0, 226.0, 217.0),
    source="Miyazawa/Matsui PRL 129, 223401 (2022); α,τ_bg estimated")

"""
    calibrate_polarizability(; waist, power_W, freq_Hz, mass=Eu151.mass) -> α [J/(W/m²)]

Back out the scalar polarizability from a single-beam RADIAL trap-frequency
measurement: `ω_r = √(8 α P / (π m w₀⁴))` ⇒ `α = ω_r² π m w₀⁴ / (8 P)`. Use this to
replace the placeholder `alpha` once a light-shift / trap-frequency + power is known.
"""
function calibrate_polarizability(;
    waist::Real, power_W::Real, freq_Hz::Real, mass::Real=Eu151.mass
)
    ωr = 2π * freq_Hz
    ωr^2 * π * mass * waist^4 / (8 * power_W)
end
