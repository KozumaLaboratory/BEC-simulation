"""
Wigner 3j and 6j symbols with half-integer support via 2j convention.

All quantum-number arguments are passed as twice their value (integer):
    wigner_3j_2j(2j1, 2j2, 2j3, 2m1, 2m2, 2m3)
    wigner_6j_2j(2j1, 2j2, 2j3, 2j4, 2j5, 2j6)

This avoids half-integer floating-point comparisons and keeps the Racah
sums in exact integer arithmetic (factorials in log-space for stability).
"""

# --- log-factorial & log triangle (local copies, integer args) ---

function _log_fact(n::Int)
    n < 0 && return -Inf
    n <= 1 && return 0.0
    s = 0.0
    @inbounds for i in 2:n
        s += log(i)
    end
    s
end

"""
Δ(j1,j2,j3)² = (j1+j2-j3)!(j1-j2+j3)!(-j1+j2+j3)! / (j1+j2+j3+1)!

Input: 2j values (integers). Returns log Δ², or -Inf if triangle violated
or sums are non-integer (odd 2j1+2j2+2j3).
"""
function _log_tri_2j(tj1::Int, tj2::Int, tj3::Int)
    isodd(tj1 + tj2 + tj3) && return -Inf
    a = tj1 + tj2 - tj3
    b = tj1 - tj2 + tj3
    c = -tj1 + tj2 + tj3
    d = tj1 + tj2 + tj3
    (a < 0 || b < 0 || c < 0) && return -Inf
    (_log_fact(a ÷ 2) + _log_fact(b ÷ 2) + _log_fact(c ÷ 2)
        - _log_fact(d ÷ 2 + 1))
end

"""
    wigner_3j_2j(tj1, tj2, tj3, tm1, tm2, tm3)

Wigner 3-j symbol with quantum numbers as 2j integers. Half-integer j, m
are allowed (pass 2j, 2m).
"""
function wigner_3j_2j(tj1::Int, tj2::Int, tj3::Int,
                      tm1::Int, tm2::Int, tm3::Int)
    # selection rules
    (tm1 + tm2 + tm3) != 0 && return 0.0
    (tj1 < 0 || tj2 < 0 || tj3 < 0) && return 0.0
    abs(tj1 - tj2) > tj3 && return 0.0
    (tj1 + tj2) < tj3 && return 0.0
    # (j_i - m_i) must be integer ⇒ same parity
    (isodd(tj1 - tm1) || isodd(tj2 - tm2) || isodd(tj3 - tm3)) && return 0.0
    # |m| ≤ j
    (abs(tm1) > tj1 || abs(tm2) > tj2 || abs(tm3) > tj3) && return 0.0

    log_tri = _log_tri_2j(tj1, tj2, tj3)
    log_tri == -Inf && return 0.0

    # factorials of (j_i ± m_i)
    jm1p = (tj1 + tm1) ÷ 2; jm1m = (tj1 - tm1) ÷ 2
    jm2p = (tj2 + tm2) ÷ 2; jm2m = (tj2 - tm2) ÷ 2
    jm3p = (tj3 + tm3) ÷ 2; jm3m = (tj3 - tm3) ÷ 2
    log_num = (_log_fact(jm1p) + _log_fact(jm1m) +
               _log_fact(jm2p) + _log_fact(jm2m) +
               _log_fact(jm3p) + _log_fact(jm3m))

    # summation bounds
    # t runs over integers; define in terms of half-sums
    j12m3 = (tj1 + tj2 - tj3) ÷ 2
    jmm1  = (tj1 - tm1) ÷ 2
    jpm2  = (tj2 + tm2) ÷ 2
    jmj3mm1 = (tj3 - tj2 + tm1) ÷ 2   # note: integer because parities match
    jmj3pm2 = (tj3 - tj1 - tm2) ÷ 2   # may be negative → lower bound
    t_min = max(0, -jmj3mm1, -jmj3pm2)
    t_max = min(j12m3, jmm1, jpm2)
    t_min > t_max && return 0.0

    s = 0.0
    @inbounds for t in t_min:t_max
        log_den = (_log_fact(t) +
                   _log_fact(j12m3 - t) +
                   _log_fact(jmm1 - t) +
                   _log_fact(jpm2 - t) +
                   _log_fact(jmj3mm1 + t) +
                   _log_fact(jmj3pm2 + t))
        sgn = iseven(t) ? 1.0 : -1.0
        s += sgn * exp(-log_den)
    end

    # phase (-1)^(j1 - j2 - m3) = (-1)^((tj1 - tj2 - tm3)/2)
    ph_exp = (tj1 - tj2 - tm3) ÷ 2
    phase = iseven(ph_exp) ? 1.0 : -1.0
    phase * exp(0.5 * (log_tri + log_num)) * s
end

"""
    clebsch_gordan_2j(tj1, tm1, tj2, tm2, tJ, tM)

Clebsch-Gordan coefficient ⟨j1 m1; j2 m2 | J M⟩ via:
    CG = (-1)^(j1-j2+M) √(2J+1) × 3j(j1,j2,J, m1,m2,-M)
Arguments are 2j/2m integers.
"""
function clebsch_gordan_2j(tj1::Int, tm1::Int, tj2::Int, tm2::Int,
                           tJ::Int, tM::Int)
    (tm1 + tm2) != tM && return 0.0
    # phase (-1)^(j1-j2+M) = (-1)^((tj1-tj2+tM)/2)
    ph_exp = (tj1 - tj2 + tM)
    isodd(ph_exp) && return 0.0  # non-integer exponent ⇒ selection rule viol.
    phase = iseven(ph_exp ÷ 2) ? 1.0 : -1.0
    phase * sqrt(tJ + 1) * wigner_3j_2j(tj1, tj2, tJ, tm1, tm2, -tM)
end

"""
    wigner_6j_2j(tj1, tj2, tj3, tj4, tj5, tj6)

Wigner 6j symbol {j1 j2 j3; j4 j5 j6} with half-integer support (2j args).
Requires all four triangles (j1,j2,j3), (j1,j5,j6), (j4,j2,j6),
(j4,j5,j3) to be satisfied.
"""
function wigner_6j_2j(tj1::Int, tj2::Int, tj3::Int,
                      tj4::Int, tj5::Int, tj6::Int)
    lt1 = _log_tri_2j(tj1, tj2, tj3)
    lt2 = _log_tri_2j(tj1, tj5, tj6)
    lt3 = _log_tri_2j(tj4, tj2, tj6)
    lt4 = _log_tri_2j(tj4, tj5, tj3)
    (lt1 == -Inf || lt2 == -Inf || lt3 == -Inf || lt4 == -Inf) && return 0.0

    log_tri_sum = 0.5 * (lt1 + lt2 + lt3 + lt4)

    # Summation variable t (integer).
    # Classic Racah: t_min = max of the four triad sums; t_max = min of the
    # three pair sums. In 2j convention, these must all be even (triangles
    # ensure that), divide by 2 to get integer t bounds.
    a1 = (tj1 + tj2 + tj3) ÷ 2
    a2 = (tj1 + tj5 + tj6) ÷ 2
    a3 = (tj4 + tj2 + tj6) ÷ 2
    a4 = (tj4 + tj5 + tj3) ÷ 2
    b1 = (tj1 + tj2 + tj4 + tj5) ÷ 2
    b2 = (tj2 + tj3 + tj5 + tj6) ÷ 2
    b3 = (tj1 + tj3 + tj4 + tj6) ÷ 2
    t_min = max(a1, a2, a3, a4)
    t_max = min(b1, b2, b3)
    t_min > t_max && return 0.0

    s = 0.0
    @inbounds for t in t_min:t_max
        log_num = _log_fact(t + 1)
        log_den = (_log_fact(t - a1) + _log_fact(t - a2) +
                   _log_fact(t - a3) + _log_fact(t - a4) +
                   _log_fact(b1 - t) + _log_fact(b2 - t) +
                   _log_fact(b3 - t))
        sgn = iseven(t) ? 1.0 : -1.0
        s += sgn * exp(log_num - log_den)
    end
    exp(log_tri_sum) * s
end

"""
    wigner_9j_2j(tj1, tj2, tj3, tj4, tj5, tj6, tj7, tj8, tj9)

Wigner 9j symbol

    {j1 j2 j3}
    {j4 j5 j6}
    {j7 j8 j9}

in 2j-integer convention. Evaluated via the summation formula

    9j = Σ_k (-1)^{2k} (2k+1) × {j1 j4 j7; j8 j9 k}
                              × {j2 j5 j8; j4 k  j6}
                              × {j3 j6 j9; k  j1 j2}

which is exact and numerically stable for the ranges required in
atomic scattering (j ≲ 10). Row- and column-triangle selection rules
are checked up front.
"""
function wigner_9j_2j(tj1::Int, tj2::Int, tj3::Int,
                      tj4::Int, tj5::Int, tj6::Int,
                      tj7::Int, tj8::Int, tj9::Int)
    # Row triangles
    _log_tri_2j(tj1, tj2, tj3) == -Inf && return 0.0
    _log_tri_2j(tj4, tj5, tj6) == -Inf && return 0.0
    _log_tri_2j(tj7, tj8, tj9) == -Inf && return 0.0
    # Column triangles
    _log_tri_2j(tj1, tj4, tj7) == -Inf && return 0.0
    _log_tri_2j(tj2, tj5, tj8) == -Inf && return 0.0
    _log_tri_2j(tj3, tj6, tj9) == -Inf && return 0.0

    # tk appears in triangles (tj1,tj9,tk), (tj4,tj8,tk), (tj2,tj6,tk)
    tk_min = max(abs(tj1 - tj9), abs(tj4 - tj8), abs(tj2 - tj6))
    tk_max = min(tj1 + tj9, tj4 + tj8, tj2 + tj6)
    tk_min > tk_max && return 0.0

    s = 0.0
    @inbounds for tk in tk_min:tk_max
        w1 = wigner_6j_2j(tj1, tj4, tj7, tj8, tj9, tk)
        w1 == 0.0 && continue
        w2 = wigner_6j_2j(tj2, tj5, tj8, tj4, tk, tj6)
        w2 == 0.0 && continue
        w3 = wigner_6j_2j(tj3, tj6, tj9, tk, tj1, tj2)
        w3 == 0.0 && continue
        sgn = iseven(tk) ? 1.0 : -1.0   # (-1)^{2k} = (-1)^{tk}
        s += sgn * (tk + 1) * w1 * w2 * w3
    end
    s
end
