# PhiOneReg.jl
# =================================================================
# φ_1^reg(t) evaluator for spinor LHY corrections.
#
# Definition (Petrov-prescribed, UKU 2010):
#   φ_1^reg(t) = (15/(8√2)) ∫₀^∞ x²[(x²+t+1) - Re√((x²+t)(x²+t+2)) - 1/(2x²)] dx
#
# Implementation:
#   1. Cubic Hermite spline on 39 knots over t ∈ [-1, 50] (50-digit reference
#      values from mpmath, cast to Float64).
#   2. Asymptotic extrapolation φ → (15π/(32√2))·√(t+1) + B/√(t+1) + D/(t+1)^(3/2)
#      for t > 50, with B,D matched to (φ, φ') at t=50 for C¹ continuity.
#   3. Petrov saturation for t < -1 (clamp to φ_1^reg(-1) = 0.31770...).
#
# F-independent: any spinor LHY using the closed form re-uses this evaluator.

export phi_1_reg, T_KNOTS, VAL_KNOTS, DERIV_KNOTS

const T_KNOTS = Float64[
    -1.0000, -0.9990, -0.9900, -0.9500, -0.9000, -0.8500, -0.8000,
    -0.7000, -0.6000, -0.5000, -0.4000, -0.3000, -0.2000, -0.1000,
    -0.0500,
    0.0000,
    0.0500, 0.1000, 0.2000, 0.3000, 0.4000, 0.5000, 0.6000,
    0.7000, 0.8000, 0.9000, 1.0000, 1.5000, 2.0000, 2.5000,
    3.0000, 4.0000, 5.0000, 7.0000, 10.0000, 15.0000, 20.0000,
    30.0000, 50.0000,
]

const VAL_KNOTS = Float64[
    0.31770490679774216, 0.31828450362752838, 0.32351867417163341,
    0.34716210543430415, 0.37755668273747379, 0.40883129537893681,
    0.44092633668996673, 0.50732640640198181, 0.57622393729516851,
    0.64702745247755411, 0.71906689721688190, 0.79156015647248093,
    0.86354994052655719, 0.93375737292571053, 0.96760158599254380,
    1.00000000000000000,
    1.03007731246705127, 1.05858348084013981, 1.11232097655171223,
    1.16273180061066990, 1.21052783456148107, 1.25615817386468931,
    1.29993916479234896, 1.34210805767644169, 1.38285029262353713,
    1.42231517762779940, 1.46062566400473048, 1.63799129277251722,
    1.79721035210338831, 1.94306042530015902, 2.07849323582017171,
    2.32549016700101354, 2.54843154685409220, 2.94380147662090641,
    3.45271058010759413, 4.16469399619134965, 4.77150096643054700,
    5.79752830310962925, 7.43628498994603830,
]

const DERIV_KNOTS = Float64[
    0.57941819248909325, 0.57979524974139083, 0.58334786995573732,
    0.59870535580242643, 0.61688666135736650, 0.63389923718283987,
    0.64969544098641300, 0.67741980115921370, 0.69954822881279926,
    0.71541057734461189, 0.72408438606131883, 0.72420595276689358,
    0.71351812095880395, 0.68740200636004172, 0.66486977100289114,
    0.62500000000000000,
    0.58374703792053155, 0.55767392863925689, 0.51921585036025507,
    0.49013232741030527, 0.46651872251274882, 0.44660721839048726,
    0.42940375802730847, 0.41428067257666613, 0.40081130014914315,
    0.38869027062311733, 0.37769049533354694, 0.33454201091716699,
    0.30386348439580892, 0.28049535371879344, 0.26188643678819781,
    0.23372807241396901, 0.21311382806614829, 0.18434888816889020,
    0.15710398202239951, 0.13021032106430847, 0.11363939257387169,
    0.09352068828989872, 0.07290829469977799,
]

const N_KNOTS = length(T_KNOTS)
const ASYMP_C1 = 15.0 * π / (32.0 * sqrt(2.0))   # ≈ 1.04143

@inline function _hermite_eval(t::Float64,
    t0::Float64, t1::Float64,
    p0::Float64, p1::Float64,
    m0::Float64, m1::Float64)
    h = t1 - t0
    s = (t - t0) / h
    s2 = s * s
    s3 = s2 * s
    h00 = 2.0 * s3 - 3.0 * s2 + 1.0
    h10 = s3 - 2.0 * s2 + s
    h01 = -2.0 * s3 + 3.0 * s2
    h11 = s3 - s2
    return h00 * p0 + h10 * h * m0 + h01 * p1 + h11 * h * m1
end

@inline function _phi1_asymptotic(t::Float64)
    t0 = T_KNOTS[end]
    p0 = VAL_KNOTS[end]
    m0 = DERIV_KNOTS[end]

    s = sqrt(t0 + 1.0)
    s3 = s * s * s
    s5 = s3 * s * s

    p0_resid = p0 - ASYMP_C1 * s
    m0_resid = m0 - ASYMP_C1 / (2.0 * s)

    det = -1.0 / (s5 * s)
    B = ((-3.0 / (2.0 * s5)) * p0_resid - (1.0 / s3) * m0_resid) / det
    D = ((1.0 / s) * m0_resid + (1.0 / (2.0 * s3)) * p0_resid) / det

    sqrt_tp1 = sqrt(t + 1.0)
    return ASYMP_C1 * sqrt_tp1 + B / sqrt_tp1 + D / (sqrt_tp1 * sqrt_tp1 * sqrt_tp1)
end

"""
    phi_1_reg(t::Real) -> Float64

Petrov-regularised universal LHY function evaluated at the dimensionless
gap parameter `t = ξ/|Δ| - 1`.

  - `t ≤ -1`:  Petrov saturation, returns `φ_1^reg(-1) = 0.31770490679774216`.
  -  `-1 < t < 50`: cubic Hermite spline on the 39-knot reference table.
  -  `t ≥ 50`: asymptotic extrapolation.
"""
@inline function phi_1_reg(t::Real)
    tF = Float64(t)
    tF <= T_KNOTS[1] && return VAL_KNOTS[1]
    tF >= T_KNOTS[end] && return _phi1_asymptotic(tF)
    @inbounds begin
        lo, hi = 1, N_KNOTS
        while hi - lo > 1
            mid = (lo + hi) >> 1
            if T_KNOTS[mid] <= tF
                lo = mid
            else
                hi = mid
            end
        end
        return _hermite_eval(tF,
            T_KNOTS[lo], T_KNOTS[hi],
            VAL_KNOTS[lo], VAL_KNOTS[hi],
            DERIV_KNOTS[lo], DERIV_KNOTS[hi])
    end
end
