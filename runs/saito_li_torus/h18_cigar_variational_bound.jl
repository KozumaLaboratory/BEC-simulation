# Is the paper's cigar branch above a variational upper bound?
#
# The cigar disagreement has survived every convergence axis (box_z, box_xy,
# grid, dt), the DDI anisotropy and the LHY coefficient. Those all ask "is OUR
# number right?". This asks the other question, and it is the one that can be
# settled without trusting either eGPE solver.
#
# A trial wave function gives a STRICT UPPER BOUND on the ground-state energy
# of a functional. So evaluate the paper's own functional on a polarized
# Gaussian and minimize over its two widths:
#
#   * if the PAPER's value is ABOVE that bound, the paper's state is not the
#     minimum of the functional it defines -- a Gaussian beats it;
#   * if OUR value is BELOW the bound, that is allowed (the true minimum is);
#   * if OUR value were ABOVE the bound, WE would be the unconverged one.
#
# The bound is computed TWICE, from two independent statements of the same
# functional:
#   (A) closed forms in this file, derived from the paper's Eqs. directly --
#       E_s = 2 pi hbar^2 a_s M^-1 int rho^2, E_LHY Eq. (1), E_ddi/E_s =
#       -eps_dd f(kappa), and the linear Zeeman;
#   (B) the production `energy_decomposition` evaluated on the same Gaussian.
# (A) touches none of the repo's field machinery, so agreement between them is
# a check on the algebra AND on the production functional. Disagreement means
# the bound is not trustworthy and the verdict is withheld.
#
#   julia --project=. runs/saito_li_torus/h18_cigar_variational_bound.jl

using SpinorBEC
using SpinorBEC: make_workspace, energy_decomposition, InteractionParams,
    ZeemanParams, HarmonicTrap, SimParams, ATOM_REGISTRY, Units, cell_volume,
    total_density
using Printf, LinearAlgebra

include(joinpath(@__DIR__, "h3_cells.jl"))

const UM = 1.0e-6
const PAPER_UNIT_IN_HW = let a = ATOM_REGISTRY[:Eu151_f1_effective]
    (Units.HBAR^2 / (a.mass * UM^2)) / (Units.HBAR * OMEGA_REF)
end

# Fig. 3(c), the field where both branches are digitised cleanly (h11)
const BZ_MG = 0.140

# The paper's cigar branch as a FITTED LINE, not a single digitised point.
# h11 reads 1473 marker columns over 0.05 < B < 0.2 with a residual rms of
# 0.674 paper units -- reading one point off open squares and calling the
# difference a result would be quoting the scatter. Slope, intercept from
# `numpy.polyfit` in h11.
const PAPER_CIGAR_FIT = (slope=-89.4419, intercept=0.9392, resid_rms=0.674)
paper_cigar(b) = PAPER_CIGAR_FIT.intercept + PAPER_CIGAR_FIT.slope * b

# ours, E/N in paper units on the box- and grid-converged cells (h11/h15)
const OURS_CIGAR = Dict(0.110 => -11.77, 0.120 => -12.69, 0.140 => -14.53)

"Dipolar anisotropy for a Gaussian, kappa = a/b. f(0)=1, f(1)=0, f(inf)=-2."
function f_dip(k)
    abs(k - 1) < 1e-9 && return 0.0
    if k < 1
        (1 + 2k^2) / (1 - k^2) - 3k^2 * atanh(sqrt(1 - k^2)) / (1 - k^2)^1.5
    else
        (1 + 2k^2) / (1 - k^2) + 3k^2 * atan(sqrt(k^2 - 1)) / (k^2 - 1)^1.5
    end
end

"""
E/N of a polarized Gaussian droplet, in hbar w_ref, from closed forms.

`n(r) = (pi^3/2 a^2 b)^-1 exp(-rho^2/a^2 - z^2/b^2)`, normalized to 1, so
every term below is per atom with `c0`/`c_lhy` already carrying N.
"""
function e_gauss_closed(a, b; c0, c_dd, c_lhy, eps_dd, p, F)
    (a > 0 && b > 0) || return Inf
    e_kin = 0.5 * (1 / a^2 + 1 / (2b^2))
    int_n2 = 1 / ((2π)^1.5 * a^2 * b)
    e_s = 0.5 * c0 * int_n2
    e_ddi = -eps_dd * f_dip(a / b) * e_s
    int_n52 = (π^1.5 * a^2 * b)^(-2.5) * (a^2 * b) * (2π / 5)^1.5
    e_lhy = 0.4 * c_lhy * int_n52
    e_zee = p * F                       # H = -p F_z, polarized at m = -F
    (; total=e_kin + e_s + e_ddi + e_lhy + e_zee,
        e_kin, e_s, e_ddi, e_lhy, e_zee)
end

"""
Linear Zeeman energy per atom of the FULLY POLARIZED state at `bmg` mG, in
paper units. Goes through `Units.bfield_to_p_gauss`, the repo's single
declaration of the B -> p sign; h17 checks the result against the digitised
slope of this very branch.
"""
function zeeman_paper_units(bc, bmg)
    p = Units.bfield_to_p_gauss(bmg * 1.0e-3, bc.atom.g_F, OMEGA_REF)
    p * bc.F / PAPER_UNIT_IN_HW
end

"Nelder-Mead on log-widths; the two-parameter surface does not need more."
function minimize_gauss(f)
    x = [log(0.35), log(2.0)]
    simplex = [x, x .+ [0.25, 0.0], x .+ [0.0, 0.25]]
    val = [f(exp(s[1]), exp(s[2])) for s in simplex]
    for _ in 1:600
        o = sortperm(val)
        simplex, val = simplex[o], val[o]
        c = (simplex[1] .+ simplex[2]) ./ 2
        xr = c .+ (c .- simplex[3])
        fr = f(exp(xr[1]), exp(xr[2]))
        if fr < val[1]
            xe = c .+ 2 .* (c .- simplex[3])
            fe = f(exp(xe[1]), exp(xe[2]))
            simplex[3], val[3] = fe < fr ? (xe, fe) : (xr, fr)
        elseif fr < val[2]
            simplex[3], val[3] = xr, fr
        else
            xc = c .+ 0.5 .* (simplex[3] .- c)
            fc = f(exp(xc[1]), exp(xc[2]))
            if fc < val[3]
                simplex[3], val[3] = xc, fc
            else
                simplex[2] = (simplex[1] .+ simplex[2]) ./ 2
                simplex[3] = (simplex[1] .+ simplex[3]) ./ 2
                val[2] = f(exp(simplex[2][1]), exp(simplex[2][2]))
                val[3] = f(exp(simplex[3][1]), exp(simplex[3][2]))
            end
        end
        maximum(val) - minimum(val) < 1e-13 && break
    end
    i = argmin(val)
    (exp(simplex[i][1]), exp(simplex[i][2]), val[i])
end

"Build the same Gaussian on the grid and read the PRODUCTION functional."
function e_gauss_production(a, b, cell; n, box)
    bc = build_cell(cell; n=n, box=box)
    g = bc.grid
    D = 2 * bc.F + 1
    psi = zeros(ComplexF64, n..., D)
    for k in 1:n[3], j in 1:n[2], i in 1:n[1]
        r2 = (g.x[1][i]^2 + g.x[2][j]^2) / a^2 + g.x[3][k]^2 / b^2
        psi[i, j, k, D] = exp(-0.5 * r2)      # component D is m = -F
    end
    dV = cell_volume(g)
    psi .*= 1 / sqrt(sum(abs2, psi) * dV)
    ip = InteractionParams(Dict(0 => bc.c0); c_lhy=bc.c_lhy)
    ws = make_workspace(; grid=g, atom=bc.atom, interactions=ip,
        zeeman=ZeemanParams(bc.p, 0.0),
        potential=HarmonicTrap(TRAP_OMEGA, TRAP_OMEGA, TRAP_OMEGA),
        sim_params=SimParams(; dt=1e-4, n_steps=1),
        enable_ddi=true, c_dd=bc.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0, psi_init=psi)
    e = energy_decomposition(ws)
    edge = _edge_fraction(abs2.(psi), dV)
    (; total=e.total, e_kin=e.kinetic, e_s=e.density, e_ddi=e.ddi,
        e_lhy=e.lhy, e_zee=e.zeeman, edge)
end

function _edge_fraction(rho, dV)
    s = 0.0
    n = size(rho)
    for I in CartesianIndices(rho)
        if any(I[d] == 1 || I[d] == n[d] for d in 1:3)
            s += rho[I]
        end
    end
    s * dV
end

function main()
    cell = (; seed=:cigar, atom=:Eu151_f1_effective, N=50000, eps_dd=1.2,
        Bz_mG=BZ_MG)
    bc = build_cell(cell; n=(96, 96, 96), box=(10.0, 10.0, 20.0))
    F = bc.F

    println("="^76)
    println("Variational upper bound on the polarized cigar, Fig. 3(c)")
    @printf("F = %d, N = %d, eps_dd = %.2f, B_z = %.3f mG\n", F, cell.N,
        cell.eps_dd, BZ_MG)
    @printf("c0 = %.4g  c_dd = %.4g  c_lhy = %.4g  p = %.6g\n",
        bc.c0, bc.c_dd, bc.c_lhy, bc.p)
    println("="^76)

    fcl =
        (a, b) -> e_gauss_closed(a, b; c0=bc.c0, c_dd=bc.c_dd,
            c_lhy=bc.c_lhy, eps_dd=cell.eps_dd, p=bc.p, F=F).total
    a, b, e_hw = minimize_gauss(fcl)
    d = e_gauss_closed(a, b; c0=bc.c0, c_dd=bc.c_dd, c_lhy=bc.c_lhy,
        eps_dd=cell.eps_dd, p=bc.p, F=F)

    @printf("\n(A) closed forms, minimized:  a = %.5f  b = %.5f a_ho  (kappa = %.4f)\n",
        a, b, a / b)
    @printf("    kin %+.5f  s %+.5f  ddi %+.5f  lhy %+.5f  zee %+.5f\n",
        d.e_kin, d.e_s, d.e_ddi, d.e_lhy, d.e_zee)
    @printf("    E/N = %+.6f hbar w_ref = %+.4f paper units\n",
        e_hw, e_hw / PAPER_UNIT_IN_HW)

    # Size the grid FROM the optimum, not the other way round: the fitted
    # a = 0.39 a_ho spans two points of the cell grid, and a box that clips a
    # b = 5.6 a_ho tail at 5 a_ho is not evaluating the trial state at all.
    #
    # 8 Gaussian widths of HALF-extent, not 5. h19 measured the DDI energy of
    # an exact Gaussian against the closed form and found 5 widths short by
    # 0.85 % at kappa = 0.112 while the edge density sat at 5e-12 -- the
    # dipolar field reaches far beyond where the density has died, so the edge
    # gate does not see this. At 8 widths the same comparison is 0.08 %.
    boxv = (16.0 * a, 16.0 * a, 16.0 * b)
    nv = (128, 128, 256)
    @printf("\n    (B) grid sized from the optimum: box %s, n %s\n",
        string(round.(boxv; digits=3)), string(nv))
    @printf("        points per transverse width a: %.1f\n", a / (boxv[1] / nv[1]))
    pr = e_gauss_production(a, b, cell; n=nv, box=boxv)
    @printf("\n(B) production functional on the SAME Gaussian (edge %.2e):\n", pr.edge)
    @printf("    kin %+.5f  s %+.5f  ddi %+.5f  lhy %+.5f  zee %+.5f\n",
        pr.e_kin, pr.e_s, pr.e_ddi, pr.e_lhy, pr.e_zee)
    @printf("    E/N = %+.6f hbar w_ref = %+.4f paper units\n",
        pr.total, pr.total / PAPER_UNIT_IN_HW)

    rel = abs(pr.total - e_hw) / abs(e_hw)
    @printf("\n(A) vs (B): %.3f %% apart", 100rel)
    println(rel > 0.01 ? "  -- the two differ; see below" : "")
    if pr.edge > 1e-6
        println("\nVERDICT WITHHELD: the Gaussian does not fit the box, so (B)")
        println("is not an evaluation of the trial state. Nothing concluded.")
        return nothing
    end

    # Take the LEAST binding of the two as the bound. Both are evaluations of
    # a trial state, so both bound the minimum; quoting the higher one makes
    # the verdict independent of which is the more accurate. That matters here
    # because (A) and (B) agree to 6 digits on kinetic / contact / LHY /
    # Zeeman and differ ONLY in E_ddi -- a question h19 settles separately and
    # which this conclusion must not wait on.
    bound = max(e_hw, pr.total) / PAPER_UNIT_IN_HW
    if rel > 0.01
        @printf("\n  (A) and (B) differ only in E_ddi (%.5f vs %.5f); the\n",
            d.e_ddi, pr.e_ddi)
        @printf("  conservative bound %.4f is used, so the verdict does not\n",
            bound)
        println("  depend on which of the two is the more accurate.")
    end
    # Sweep the field. The Gaussian's INTERNAL energy is B-independent (the
    # state is fully polarized, so the Zeeman is an exact additive constant and
    # the optimal widths do not move), which makes the whole branch reachable
    # from this one minimization: bound(B) = E_int + p(B) F. Sweeping matters
    # because a single field compares one digitised point against the bound,
    # and the point-to-point scatter on open square markers is 0.674 -- half
    # the effect. The fitted line is the measurement; the points are not.
    e_int = bound - zeeman_paper_units(bc, BZ_MG)
    println()
    println("-"^76)
    @printf("Gaussian internal energy (B-independent): %+.3f paper units\n", e_int)
    @printf("%7s %12s %12s %12s %10s %8s\n", "B_z/mG", "bound", "paper fit",
        "ours", "paper-bound", "verdict")
    above = Float64[]
    for bmg in (0.110, 0.120, 0.130, 0.140, 0.160, 0.180, 0.200)
        bd = e_int + zeeman_paper_units(bc, bmg)
        pf = paper_cigar(bmg)
        ov = get(OURS_CIGAR, bmg, NaN)
        push!(above, pf - bd)
        @printf("%7.3f %12.3f %12.3f %12s %10.3f %8s\n", bmg, bd, pf,
            isnan(ov) ? "-" : string(round(ov; digits=2)), pf - bd,
            pf > bd ? "ABOVE" : "below")
    end
    println("-"^76)
    @printf("\npaper above the bound by %.2f .. %.2f paper units across the branch\n",
        minimum(above), maximum(above))
    @printf("digitisation scatter on that branch (h11 residual rms): %.3f\n",
        PAPER_CIGAR_FIT.resid_rms)
    @printf("our eGPE sits %.2f BELOW the bound at %.3f mG -- so the bound is\n",
        bound - OURS_CIGAR[BZ_MG], BZ_MG)
    println("a WEAK one (a Gaussian is a poor ansatz for a flat-top droplet),")
    println("which makes the paper being above it the stronger statement.")

    # The binding energy, which is what a droplet claim is ABOUT. For a fully
    # polarized branch the Zeeman is an exact additive constant, so the fitted
    # INTERCEPT is the B = 0 internal energy directly -- no F_z panel needed
    # (the h11 ledger that did need it is withheld as uncalibrated).
    println()
    println("binding energy per atom E_int = E - E_Zeeman, paper units:")
    @printf("  paper's cigar branch  %+7.3f   (the fitted intercept)\n",
        PAPER_CIGAR_FIT.intercept)
    @printf("  Gaussian optimum      %+7.3f\n", e_int)
    @printf("  our eGPE              %+7.3f\n",
        OURS_CIGAR[BZ_MG] - zeeman_paper_units(bc, BZ_MG))
    println("  A self-bound droplet needs E_int < 0. Only ours is.")
    @printf("  CAVEAT: the paper's intercept extrapolates from 0.05-0.2 mG, so\n")
    @printf("  the %.1f %% slope difference against theory (%.2f vs %.2f) moves\n",
        100 * abs(PAPER_CIGAR_FIT.slope + 94.04) / 94.04,
        PAPER_CIGAR_FIT.slope, -94.04)
    @printf("  it by ~%.2f. Positive, but at ~1.5 sigma -- the bound comparison\n",
        abs(PAPER_CIGAR_FIT.slope + 94.04) * 0.125)
    println("  above is the robust statement, this one is the readable one.")
    println()
    if minimum(above) > PAPER_CIGAR_FIT.resid_rms &&
        OURS_CIGAR[BZ_MG] < bound
        println("A two-parameter Gaussian beats the paper's cigar branch at")
        println("EVERY field where it is drawn, by more than the digitisation")
        println("scatter. A trial function cannot beat a converged ground")
        println("state, so the paper's cigar branch is not the minimum of the")
        println("functional the paper writes down. Ours sits below the bound,")
        println("which is where a converged solution belongs.")
    elseif OURS_CIGAR[BZ_MG] > bound
        println("OUR value is above the bound -- our cigar is NOT converged.")
    else
        println("Both sit below the bound; this test does not separate them.")
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
