# --- euv3 lab magnetic-field coil calibration (Kozuma setup) ---
#
# Site-measured coil constants transcribed from the euv3 r14 control program.
# Maps physical fields (Gauss) / gradients (G/cm) ↔ control voltages, including
# the NON-ORTHOGONAL horizontal bias coils (Coil2 Xp at -10°, Yp at +98°). Lets a
# desired magnetic environment be expressed in physical units and converted to
# the experiment's control voltages (and the inverse, for interpreting logs).
#
# Coil2 (main bias): Xp 2.4 G/A, Yp 4.6 G/A, Z 7.0 G/A, Q 11.4 G/cm/A, all at
# 1/11 A/V. Coil1 (MOT/quadrupole): V 1.09 G/A @0.2 A/V, W 1.09 G/A @0.16 A/V,
# Z 2.32 G/A (+0.11 A offset) @0.291 A/V, Q 12.6 G/cm/A @1.8 A/V.

export bxpyp, coil2_xp_volts, coil2_yp_volts, coil2_z_volts, coil2_q_volts
export coil2_xp_field, coil2_yp_field, coil2_z_field, coil2_q_grad
export coil1_v_volts, coil1_w_volts, coil1_z_volts, coil1_q_volts
export horizontal_bias_volts, euv3_bias_field

const _EUV3_THETA_XP = -10.0 / 180 * π    # Coil2 Xp axis direction [rad]
const _EUV3_THETA_YP = +98.0 / 180 * π    # Coil2 Yp axis direction [rad]

"""
    bxpyp(theta) -> (s, t)

Project a unit horizontal field at angle `theta` [rad] (x = glass-cell axis) onto
the two non-orthogonal Coil2 axes (Xp at -10°, Yp at +98°): the field is
`B·[s, t]` applied on `[Coil2Xp, Coil2Yp]`. Solves the 2×2 non-orthogonal basis.
"""
function bxpyp(theta::Real)
    dotXpYp = cos(_EUV3_THETA_YP - _EUV3_THETA_XP)
    dotBXp = cos(theta - _EUV3_THETA_XP)
    dotBYp = cos(theta - _EUV3_THETA_YP)
    denom = 1 - dotXpYp^2
    s = (dotBXp - dotBYp * dotXpYp) / denom
    t = (dotBYp - dotBXp * dotXpYp) / denom
    (s, t)
end

# Coil2 (main bias): field/gradient → control voltage, and inverses.
coil2_xp_volts(bxp::Real) = bxp / 2.4 * 11
coil2_yp_volts(byp::Real) = byp / 4.6 * 11
coil2_z_volts(bz::Real) = bz / 7.0 * 11
coil2_q_volts(gbyp::Real) = gbyp / 11.4 * 11

coil2_xp_field(V::Real) = V * 2.4 / 11
coil2_yp_field(V::Real) = V * 4.6 / 11
coil2_z_field(V::Real) = V * 7.0 / 11
coil2_q_grad(V::Real) = V * 11.4 / 11

# Coil1 (MOT / quadrupole): field/gradient → control voltage.
coil1_v_volts(bv::Real) = bv / 1.09 / 0.2
coil1_w_volts(bw::Real) = bw / 1.09 / 0.16
coil1_z_volts(bz::Real) = (bz / 2.32 - 0.11) / 0.291
coil1_q_volts(gbz::Real) = gbz / 12.6 / 1.8

"""
    horizontal_bias_volts(B_gauss, theta) -> (V_xp, V_yp)

Control voltages for the two horizontal Coil2 coils to apply a bias field of
magnitude `B_gauss` [G] at horizontal angle `theta` [rad]. Combines `bxpyp` with
the per-coil G→V calibration.
"""
function horizontal_bias_volts(B_gauss::Real, theta::Real)
    s, t = bxpyp(theta)
    (coil2_xp_volts(B_gauss * s), coil2_yp_volts(B_gauss * t))
end

"""
    euv3_bias_field(; v_xp, v_yp, v_z) -> (Bx, By, Bz)

Net Cartesian bias field [G] at the atoms from the three Coil2 bias control
voltages, resolving the non-orthogonal horizontal coils (Xp at -10°, Yp at +98°
in-plane; x = glass-cell axis) into lab x/y and the vertical Z coil into z. Feeds
the GP simulator's B-block (`B: {Bx, By, Bz}` in Gauss). Inverse of
`horizontal_bias_volts` for the in-plane part.
"""
function euv3_bias_field(; v_xp::Real=0.0, v_yp::Real=0.0, v_z::Real=0.0)
    Bxp = coil2_xp_field(v_xp)
    Byp = coil2_yp_field(v_yp)
    Bx = Bxp * cos(_EUV3_THETA_XP) + Byp * cos(_EUV3_THETA_YP)
    By = Bxp * sin(_EUV3_THETA_XP) + Byp * sin(_EUV3_THETA_YP)
    Bz = coil2_z_field(v_z)
    (Bx, By, Bz)
end
