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
export euv3_evaporation_ramp

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
