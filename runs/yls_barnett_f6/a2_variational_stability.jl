# Question 1 of issue #338, answered before spending any GPU time:
#   "does the proposal's premise (a self-bound droplet) hold at the physical Eu
#    value eps_dd = 0.54?"  and, as a by-product, question 2's premise:
#   "is the F=6 droplet self-bound at the paper's own (N, eps_dd)?"
#
# This is the paper's own variational analysis (Yan-Li-Saito 2026, Appendix I.2,
# Eqs. S4-S8), reduced to closed form. Inputs: (eps_dd, N, F, l) only.
#
# Energies per particle in units hbar^2/(M L0^2), lengths in L0 = a_s N:
#   E_kin = 1/2 [ (2 + (F + 2 l^2)/lam)/(2 sr^2) + 1/(2 sz^2) ]        (S6)
#   E_s   = Gam(lam+1/2)/(sqrt(2) pi Gam(lam+1) sr^2 sz)               (S7)
#   E_ddi = -eps_dd E_s                                                (S7)
#   E_LHY = (1/N) 2^((5lam+17)/2) lam Gam(5lam/2) chi(eps_dd)
#           / (3 pi^(7/4) 5^((5lam+3)/2) Gam(lam+1)^(5/2) sr^3 sz^(3/2))  (S8)
#
# REDUCTION. Put sr = s e^v, sz = s e^-2v, so sr^2 sz = s^3 and both E_s and
# E_LHY depend on s alone. Only E_kin sees v, and min over v is analytic:
#   v* = (1/6) ln(K/2),  K = 2 + (F + 2 l^2)/lam
#   E_kin = P(lam)/s^2,  P = 1/2 [ (K/2)^(4/3) + 1/2 (K/2)^(2/3) ]
# leaving the exact two-parameter form
#   E(s,lam) = P/s^2 - Q/s^3 + R/s^4.5,   Q = (eps_dd - 1) Gam(lam+1/2)/(sqrt2 pi Gam(lam+1))
# with P, R > 0 always and Q > 0 iff eps_dd > 1. Stationarity in s is
#   h(s) = 2P s^2.5 - 3Q s^1.5 + 4.5R = 0,  min at s* = 0.9 Q/P, so a
# stationary point exists iff
#   S(lam) = Q^2.5 / (P^1.5 R) >= 4.5 / (1.2 * 0.9^1.5) = 4.392094...
# Since R is proportional to 1/N, S is proportional to N and the critical atom
# number is exact: N_c = 4.392094 / max_lam [ Q^2.5 / (P^1.5 R N) ].
#
# THE THEOREM (why eps_dd = 0.54 needs no scan at all):
#   Q > 0 requires eps_dd > 1. For eps_dd < 1, Q < 0 and h(s) is a sum of three
#   positive terms: no stationary point exists for ANY N, F, or l. Every term of
#   E is positive and strictly decreasing under dilation (alpha^-2, alpha^-3,
#   alpha^-4.5), so E falls monotonically to 0+ as the cloud expands.
#   And E_ddi = -eps_dd E_s is NOT an artifact of the ansatz: for any fully
#   polarized divergence-free (flux-closure) magnetization M = mu_tot rho nhat,
#   k . M_k = 0 kills the transverse part of the dipolar kernel and only the
#   -1/3 trace piece survives, giving E_ddi = -(c_dd/6) int|f|^2 = -eps_dd E_s
#   exactly, with a_dd built from the TOTAL moment. eps_dd > 1 is a hard
#   threshold for this class of states, not a preference.
#
# The paper's criterion is the existence of a stationary point ("we minimize the
# total variational energy ... using the Newton-Raphson method"), which is what
# is implemented here. Note this is WEAKER than E < 0: near the boundary the
# stationary point exists while its energy is still positive.

using SpinorBEC: lima_pelster_Q5
using SpecialFunctions: loggamma
using Printf

chi(eps_dd) = lima_pelster_Q5(Float64(eps_dd))
const S_CRIT = 4.5 / (1.2 * 0.9^1.5)

K_of(lam, F, l) = 2 + (F + 2 * l^2) / lam
# E_kin = (1/(4s^2))[K e^{-2v} + e^{4v}]; minimizing over v gives e^{6v} = K/2 and
# the bracket = 3(K/2)^{2/3}, hence P = (3/4)(K/2)^{2/3}. (An earlier form here
# read (K/2)^{4/3} + (1/2)(K/2)^{2/3}: that substituted e^{-2v} = (K/2)^{+1/3}
# instead of (K/2)^{-1/3}, inflating P by ~14 % and with it N_c, sigma_r and E.
# Caught by `a4_variational_vs_code_terms.jl`, which evaluates S6-S8 directly and
# agrees with the code's own energy functional to 1e-5 term by term.)
P_of(lam, F, l) = 0.75 * (K_of(lam, F, l) / 2)^(2 / 3)
Q_of(lam, eps) = (eps - 1) * exp(loggamma(lam + 0.5) - loggamma(lam + 1)) / (sqrt(2) * π)
# R = Rt/N
function Rt_of(lam, eps)
    lg = ((5 * lam + 17) / 2) * log(2) + log(lam) + loggamma(5 * lam / 2) -
         log(3) - (7 / 4) * log(π) - ((5 * lam + 3) / 2) * log(5) - 2.5 * loggamma(lam + 1)
    exp(lg) * chi(eps)
end

"S(lam)/N --- droplet exists iff N * max_lam S_over_N >= S_CRIT."
function S_over_N(lam; eps, F, l)
    Q = Q_of(lam, eps)
    Q <= 0 && return 0.0
    Q^2.5 / (P_of(lam, F, l)^1.5 * Rt_of(lam, eps))
end

"max over lambda of S/N, and the maximizing lambda (golden-section on log lambda)."
function max_S_over_N(; eps, F, l)
    g = ll -> -S_over_N(exp(ll); eps=eps, F=F, l=l)
    a, b = log(1e-3), log(1e3)
    # coarse scan first: S(lam) can be extremely peaked
    lls = range(a, b; length=2000)
    i = argmin(g.(lls))
    lo = lls[max(i - 1, 1)]
    hi = lls[min(i + 1, length(lls))]
    invphi = (sqrt(5) - 1) / 2
    c, d = hi - invphi * (hi - lo), lo + invphi * (hi - lo)
    for _ in 1:200
        if g(c) < g(d)
            hi, d, c = d, c, hi - invphi * (hi - lo)
        else
            lo, c, d = c, d, lo + invphi * (hi - lo)
        end
        c, d = hi - invphi * (hi - lo), lo + invphi * (hi - lo)
    end
    ll = (lo + hi) / 2
    (; S_over_N=-g(ll), lambda=exp(ll))
end

"Critical atom number (exact, no search over s)."
function critical_N(; eps_dd, F, l)
    m = max_S_over_N(; eps=eps_dd, F=F, l=l)
    m.S_over_N <= 0 && return Inf     # no stationary point at any N
    S_CRIT / m.S_over_N
end

"""Full solution at a given N: the bound (larger-s) stationary point if it exists."""
function droplet(; eps_dd, N, F, l)
    m = max_S_over_N(; eps=eps_dd, F=F, l=l)
    Nc = critical_N(; eps_dd=eps_dd, F=F, l=l)
    N < Nc && return (; bound=false, N_c=Nc, lambda=NaN, sigma_r=NaN, sigma_z=NaN,
        E=NaN, rho_max=NaN, r_torus=NaN)
    # Optimize lambda for the true minimum energy at this N (not the lambda that
    # maximizes S, which is the boundary-touching one).
    best = nothing
    for lam in exp.(range(log(1e-2), log(1e2); length=4000))
        P, Q, R = P_of(lam, F, l), Q_of(lam, eps_dd), Rt_of(lam, eps_dd) / N
        Q <= 0 && continue
        # E(s) falls from +inf, rises, then decays to 0+, so of the two roots of
        # h(s) = 2P s^2.5 - 3Q s^1.5 + 4.5R the SMALLER one is the droplet
        # (local minimum) and the larger is the barrier top. Bisect below the
        # h-minimum at w = sqrt(0.9 Q/P).
        h = w -> 2P * w^5 - 3Q * w^3 + 4.5R
        w_hi = sqrt(0.9 * Q / P)                   # h minimum location
        h(w_hi) > 0 && continue                    # no root at this lambda
        w_lo = w_hi
        while h(w_lo) < 0
            w_lo /= 1.5
            w_lo < 1e-12 && break
        end
        for _ in 1:200
            wm = (w_lo + w_hi) / 2
            h(wm) < 0 ? (w_hi = wm) : (w_lo = wm)
        end
        s = ((w_lo + w_hi) / 2)^2
        E = P / s^2 - Q / s^3 + R / s^4.5
        if best === nothing || E < best.E
            v = log(K_of(lam, F, l) / 2) / 6
            sr, sz = s * exp(v), s * exp(-2v)
            A = exp(-(1.5 * log(π) + (2lam + 2) * log(sr) + log(sz) + loggamma(lam + 1)))
            r_pk = sqrt(lam) * sr
            best = (; bound=true, N_c=Nc, lambda=lam, sigma_r=sr, sigma_z=sz, E=E,
                rho_max=A * r_pk^(2lam) * exp(-lam), r_torus=r_pk)
        end
    end
    best === nothing ? (; bound=false, N_c=Nc, lambda=NaN, sigma_r=NaN, sigma_z=NaN,
        E=NaN, rho_max=NaN, r_torus=NaN) : best
end

function _report()
    println("="^78)
    println("chi(eps_dd) = Lima-Pelster Q5, from the repo's own function")
    println("="^78)
    for e in (0.0, 0.5402, 1.0, 1.2, 1.3, 1.5)
        @printf("  chi(%.4f) = %.6f\n", e, chi(e))
    end
    @printf("\n  existence threshold S_CRIT = %.6f\n", S_CRIT)

    println()
    println("="^78)
    println("POSITIVE CONTROL --- the paper's non-rotating droplet, Fig. 1(b,c)")
    println("="^78)
    println("  paper anchors: rho_max = 13000 D0 (Fig. 1c colorbar), panel width 0.12 L0")
    d = droplet(; eps_dd=1.2, N=15000, F=1, l=0)
    @printf("  eps_dd=1.2 N=15000 F=1 l=0 : bound=%s  E = %+.2f\n", d.bound, d.E)
    @printf("      lambda = %.3f  sigma_r = %.5f L0  sigma_z = %.5f L0\n",
        d.lambda, d.sigma_r, d.sigma_z)
    @printf("      rho_max = %.0f D0   (paper 13000, rel dev %.1f %%)\n",
        d.rho_max, 100abs(d.rho_max - 13000) / 13000)
    @printf("      torus radius = %.4f L0 = %.3f um  (L0 = 16.35 um)\n",
        d.r_torus, d.r_torus * 16.35)

    println()
    println("="^78)
    println("PART 1 --- the eps_dd < 1 theorem, checked numerically")
    println("="^78)
    bad = 0
    for eps in (0.30, 0.5402, 0.80, 0.95, 0.999), F in (1, 6), l in (0, 1, 2)
        Nc = critical_N(; eps_dd=eps, F=F, l=l)
        isfinite(Nc) && (global bad += 1;
        @printf("  N_c FINITE at eps_dd=%.4f F=%d l=%d : %.3e  <-- theorem broken\n", eps, F, l, Nc))
    end
    println(bad == 0 ?
            "  RESULT: N_c = Inf for every eps_dd < 1 tested (F = 1,6; l = 0,1,2).\n" *
            "          No self-bound droplet exists at any atom number." :
            "  RESULT: theorem BROKEN, see above.")
    @printf("  and just above 1:  N_c(eps_dd=1.001, F=1, l=0) = %.4e\n",
        critical_N(; eps_dd=1.001, F=1, l=0))

    println()
    println("="^78)
    println("PART 2 --- reproduce Fig. 4(a): critical N vs eps_dd, F=1, l=0..3")
    println("="^78)
    println("  Fig. 4(a) plots N/1e5 on x (0..1) and eps_dd on y (1.05..1.55).")
    print("  eps_dd |")
    for l in 0:3
        @printf("  N_c/1e5 (l=%d) |", l)
    end
    println()
    for eps in (1.05, 1.07, 1.10, 1.15, 1.20, 1.30, 1.40, 1.55)
        @printf("  %5.2f  |", eps)
        for l in 0:3
            @printf(" %14.3f |", critical_N(; eps_dd=eps, F=1, l=l) / 1e5)
        end
        println()
    end
    println("  read off the published figure at N/1e5 = 1.0: eps_dd ~ 1.07 (l=0) rising")
    println("  to ~1.13 (l=3); at N/1e5 = 0.5: ~1.10 to ~1.16. Compare the rows above.")

    println()
    println("="^78)
    println("PART 3 --- the F=6 boundary the paper never computed")
    println("="^78)
    println("  F enters the variational energy in exactly ONE place: the azimuthal")
    println("  spin-winding cost <S_z^2> = F/2, i.e. the (F + 2 l^2)/lam term of E_kin.")
    println("  At l=1 that goes 3 -> 8 from F=1 to F=6.")
    print("  eps_dd |")
    for (F, l) in ((1, 0), (6, 0), (1, 1), (6, 1))
        @printf("  N_c(F=%d,l=%d) |", F, l)
    end
    println("  ratio F6/F1 (l=1)")
    for eps in (1.05, 1.10, 1.20, 1.30, 1.50)
        @printf("  %5.2f  |", eps)
        v = Float64[]
        for (F, l) in ((1, 0), (6, 0), (1, 1), (6, 1))
            Nc = critical_N(; eps_dd=eps, F=F, l=l)
            push!(v, Nc)
            @printf(" %13.4g |", Nc)
        end
        @printf("  %.3f\n", v[4] / v[3])
    end

    println()
    println("="^78)
    println("PART 4 --- the campaign's cells")
    println("="^78)
    for (tag, eps, N, F, l) in (
        ("P  paper GS", 1.2, 15000, 1, 0),
        ("P  paper vortex (headline)", 1.2, 15000, 1, 1),
        ("B  F=6 at paper eps_dd, N", 1.2, 15000, 6, 0),
        ("B  F=6 at paper eps_dd, N", 1.2, 15000, 6, 1),
        ("B+ F=6 at raised N", 1.2, 40000, 6, 1),
        ("A  physical Eu a_s=110a0", 0.5402, 15000, 6, 1),
        ("A+ physical Eu, N=1e6", 0.5402, 1000000, 6, 1),
    )
        r = droplet(; eps_dd=eps, N=N, F=F, l=l)
        @printf("  %-26s eps_dd=%.4f N=%6d F=%d l=%d : %s",
            tag, eps, N, F, l, r.bound ? "BOUND  " : "UNBOUND")
        @printf("  N_c = %.4g", r.N_c)
        r.bound && @printf("   E = %+9.2f  rho_max = %6.0f D0  r_torus = %.4f L0",
            r.E, r.rho_max, r.r_torus)
        println()
    end
    println()
    println("  N/N_c is the margin that decides whether a grid artifact can flip a cell:")
    for (tag, eps, N, F, l) in (
        ("paper vortex F=1", 1.2, 15000, 1, 1),
        ("F=6 same params", 1.2, 15000, 6, 1),
        ("F=6 raised N", 1.2, 40000, 6, 1),
    )
        Nc = critical_N(; eps_dd=eps, F=F, l=l)
        @printf("    %-18s N/N_c = %.3f\n", tag, N / Nc)
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && _report()
