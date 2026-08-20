# Does the Fig. 3(c) y axis mean what I assumed it means?
#
# The whole "cigar branch is 1.88 hbar w_ref/atom too deeply bound" statement
# rests on one conversion: the panel's axis is E/(N hbar^2 M^-1 um^-2), so
#
#     1 paper unit = a_ho^2 / (1 um)^2  hbar w_ref .
#
# The PDF text extracts that label as "E / (Nh 2Mm )", which is ambiguous
# between hbar^2/(M um^2) and hbar^2/(2M um^2) -- a factor of 2 sitting
# directly on the number being reported. Rendering the label settles it
# visually (it is M^-1, no 2), but a rendered glyph is not a measurement.
#
# THE ANCHOR. The cigar branch of Fig. 3(c) is fully polarized, so its SLOPE
# in B is the linear Zeeman energy and nothing else:
#
#     d(E/N)/dB = -g_F mu_B <F_z> ,   <F_z> = F
#
# That is atomic physics with no droplet, no DDI, no LHY and no convergence in
# it. Computing it in paper-units-per-mG and comparing against the digitised
# slope tests the conversion to a precision the factor of 2 cannot survive:
# a wrong factor of 2 misses by 100 %, and the branches agree to a few %.
#
# It is simultaneously a check on OUR Zeeman implementation, since our own
# digitised slope goes through the same converter.
#
#   julia --project=. runs/saito_li_torus/h17_zeeman_slope_anchor.jl

using SpinorBEC
using SpinorBEC: ATOM_REGISTRY, Units
using Printf

const OMEGA_REF = 691.15
const UM = 1.0e-6
const MG_IN_TESLA = 1.0e-7

# digitised from Fig. 3(c) by h11 (paper) and measured on our own cells (ours)
const SLOPE_PAPER = -89.4
const SLOPE_OURS = -91.9

function main()
    atom = ATOM_REGISTRY[:Eu151_f1_effective]
    a_ho = sqrt(Units.HBAR / (atom.mass * OMEGA_REF))
    hw = Units.HBAR * OMEGA_REF                       # hbar w_ref, in J
    paper_unit = Units.HBAR^2 / (atom.mass * UM^2)    # J, the axis unit

    println("="^74)
    println("Fig. 3(c) y-axis unit, anchored on the linear Zeeman slope")
    println("="^74)
    @printf("atom            : %s   F = %d, g_F = %.4f\n", :Eu151_f1_effective,
        atom.F, atom.g_F)
    @printf("a_ho            : %.4f um   (omega_ref = %.2f /s)\n", a_ho / UM,
        OMEGA_REF)
    @printf("hbar w_ref      : %.4e J\n", hw)
    @printf("hbar^2/(M um^2) : %.4e J  = %.5f hbar w_ref\n", paper_unit,
        paper_unit / hw)
    @printf("  cross-check   : a_ho^2/um^2 = %.5f   (must equal the line above)\n",
        (a_ho / UM)^2)

    # H = -p F_z, and the fully-polarized ground state of a g_F > 0 atom sits
    # at m = -F, so E/N = -p (-F) = p F. Going through `bfield_to_p` rather
    # than re-deriving -g_F mu_B B makes this a check on the production
    # converter as well -- that function is the repo's single declaration of
    # the B -> p sign.
    p_1mG = Units.bfield_to_p_gauss(1.0e-3, atom.g_F, OMEGA_REF)   # 1 mG in Gauss
    slope_theory = p_1mG * atom.F * hw / paper_unit
    println()
    println("linear Zeeman slope of the fully-polarized branch, per mG:")
    @printf("  from atomic constants : %8.2f paper units/mG\n", slope_theory)
    @printf("  paper, digitised      : %8.2f            (%+.1f %%)\n",
        SLOPE_PAPER, 100 * (SLOPE_PAPER - slope_theory) / abs(slope_theory))
    @printf("  ours,  measured       : %8.2f            (%+.1f %%)\n",
        SLOPE_OURS, 100 * (SLOPE_OURS - slope_theory) / abs(slope_theory))

    println()
    println("NEGATIVE CONTROL -- the reading the PDF text also permits:")
    @printf("  if the axis were hbar^2/(2M um^2), the slope would be %.2f\n",
        2 * slope_theory)
    @printf("  which misses the digitised %.1f by %.0f %%\n", SLOPE_PAPER,
        100 * abs(2 * slope_theory - SLOPE_PAPER) / abs(SLOPE_PAPER))

    ok = abs(slope_theory - SLOPE_PAPER) / abs(slope_theory) < 0.10
    bad = abs(2 * slope_theory - SLOPE_PAPER) / abs(SLOPE_PAPER) > 0.5
    println()
    if ok && bad
        println("VERDICT: the axis is hbar^2/(M um^2). The factor-of-2 reading is")
        println("excluded by the data, not only by the rendered glyph, so")
        @printf("1 paper unit = %.5f hbar w_ref and the cigar offset of\n",
            paper_unit / hw)
        @printf("-3.08 paper units is %.3f hbar w_ref per atom.\n",
            3.08 * paper_unit / hw)
    else
        println("VERDICT: INCONCLUSIVE -- ok=$ok, factor-2-excluded=$bad")
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
