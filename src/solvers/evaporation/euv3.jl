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
    euv3_evap_trap(; waists, alpha, wavelength=1064e-9, directions=euv3 default,
                   positions=origin, mass=Eu151.mass, gravity_axis=3) -> EvapTrap

Build the euv3 crossed FORT geometry. `waists` is a 3-vector [m] (H, V, S) or a
single scalar applied to all three; `alpha` is the Eu scalar polarizability
[J/(W/m²)]. All but `waists`/`alpha` have lab-typical defaults.
"""
function euv3_evap_trap(; waists, alpha::Real, wavelength::Real=1064e-9,
    directions=_EUV3_DIRECTIONS, positions=fill((0.0, 0.0, 0.0), 3),
    mass::Real=Eu151.mass, gravity_axis::Int=3)
    w = waists isa Real ? fill(Float64(waists), 3) : collect(Float64, waists)
    EvapTrap(; wavelength=Float64(wavelength), alpha=Float64(alpha), waists=w,
        directions=directions, positions=positions, mass=Float64(mass), gravity_axis=gravity_axis)
end

"""
    run_euv3_evaporation(; waists, alpha, N0, T0, tau_bg=10.0, K3=0.0, a_s=Eu151.a_s,
                         trap_kwargs...) -> EvapResult

One-call evaporation of the euv3 ramp: build the trap from `waists`/`alpha`
(+ optional geometry overrides), then `run_evaporation` over `euv3_evaporation_ramp`
from `(N0, T0)`. `a_s`, `tau_bg`, `K3` set `EvapParams`.
"""
function run_euv3_evaporation(; waists, alpha::Real, N0::Real, T0::Real,
    tau_bg::Real=10.0, K3::Real=0.0, a_s::Real=Eu151.a_s, trap_kwargs...)
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
function optimize_euv3_evaporation(; waists, alpha::Real, N0::Real, T0::Real,
    tau_bg::Real=10.0, K3::Real=0.0, a_s::Real=Eu151.a_s,
    bounds::Vector{Tuple{Float64, Float64}}=[(1.0, 5.0), (0.005, 0.05), (0.5, 3.0)],
    n_init::Int=8, n_iter::Int=40, trap_kwargs...)
    trap = euv3_evap_trap(; waists=waists, alpha=alpha, trap_kwargs...)
    p = EvapParams(; a_s=Float64(a_s), tau_bg=Float64(tau_bg), K3=Float64(K3))
    optimize_evaporation_ramp(trap, p, euv3_evaporation_ramp();
        N0=Float64(N0), T0=Float64(T0), bounds=bounds, n_init=n_init, n_iter=n_iter)
end
