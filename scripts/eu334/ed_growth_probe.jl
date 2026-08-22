# Does the FULL SPGPE grow a condensate, or only the growth-only sub-theory?
#
# `test_spgpe.jl` has the one gate that asserts the solver does the thing it
# exists for — "SPGPE grows a condensate to the Thomas-Fermi number" — and it
# runs at `M = 0.0`, energy damping OFF. So nothing in the suite asserts that the
# full theory condenses at all.
#
# That gap became a question when #334's full-SPGPE verification runs held N_C
# flat at f = 0.065 for three seconds of simulated time with µ_res sitting above
# the field, while the growth-only ensemble on the same ramp reached f = 0.37.
# Pinning the C region did not restore the growth, so it is not the moving cutoff
# re-imposing the projector's one-off loss.
#
# This probe is the same setup as that gate, run at BOTH M values, so the two
# arms differ in exactly one knob. It is deliberately unit-scale: if the stall
# reproduces here it is debuggable in minutes instead of behind hour-long cluster
# trajectories at 64³.
#
# READING IT
#   both arms condense           -> the production stall is specific to that
#                                   configuration, not to energy damping itself
#   M != 0 stalls, M = 0 grows   -> reproduced; the full theory does not condense
#                                   and #334 item 3 is a solver question, not a
#                                   caveat about a sub-theory
#
# Neither outcome is assumed: the arms are printed with the projector's two
# channels beside them so the stall, if it appears, is attributed in the same
# output rather than argued about afterwards.

using SpinorBEC
using FFTW
using FFTW: fft, fftshift
using Printf

const OMEGA, A_S = 1.0, 0.02
const C0 = 4π * A_S
const GAMMA, DT = 0.1, 0.002

# `ED_MU` / `ED_T` move the RESERVOIR to production's corner. #418's exclusion
# list is now complete except for one entry — "#334's own ramp and seed" — and
# the reading that survives is that the seed is a converged branch cell at
# µ_ψ = 8.48 while a T = 10 reservoir demands an equilibrium far above it, so the
# heating that closes the gap eats the condensate. If that is right it is PHYSICS
# ("no condensate above f = 0.066 fits in a T = 10 C region"), not a defect.
#
# The probe's own corner is T = 1, µ = 3; production is T = 10, µ_res ~ 8-12.
# Those are the two axes that can be moved without leaving the unit-scale setting
# that makes this debuggable in minutes, and they are the pair #418 named as the
# likely combination. The lattice and the ramp are deliberately NOT moved here:
# changing four things at once is how the last three suspects took four rounds.
#
# THE SEED IS THE ARM. `ED_SEED=converged` relaxes a ground state at the
# reservoir's own µ and hands THAT to the SPGPE, instead of starting from
# `fill!(psi, 0)` and letting the noise build one. Everything else is held. If
# the stall reproduces only under `converged`, the seed carries it and #418
# closes as physics; if it stalls from vacuum too, the (T, µ) corner does, and
# the seed is exonerated the way F = 6 and the DDI were.
const MU = parse(Float64, get(ENV, "ED_MU", "3.0"))
const T_RES = parse(Float64, get(ENV, "ED_T", "1.0"))
const K_CUT = sqrt(2 * (MU + T_RES))
const NSTEP = parse(Int, get(ENV, "ED_NSTEP", "25000"))
const SEED_MODE = get(ENV, "ED_SEED", "vacuum")

# `ED_SEED0` offsets the noise stream. Two runs of the SAME configuration came
# back N0 = 272.2 and 726.1 (2.7x) on 2026-08-22, on different nodes. The probe's
# stream is deterministic (`ED_SEED0 + s`), so that is not seed scatter — the
# likeliest reading is that the F=6 + DDI arm is dynamically chaotic and
# amplifies bitwise-different-but-equal arithmetic. Either way the arm cannot be
# quoted at n = 1, and this knob is what makes an ensemble possible.
const SEED0 = parse(Int, get(ENV, "ED_SEED0", "90000"))

# `ED_MU_RAMP` is #418's LAST untested difference, and after the 2x2 factorial it
# is the last one full stop.
#
# The factorial (2026-08-22) cleared the reservoir corner, the seed, and their
# interaction: full/growth came back 0.93-1.06 in all four cells against
# production's 9.0x and 37x. Everything about the CONFIGURATION is now exonerated
# — projector, moving cutoff, energy damping, F=6, DDI, the scattering pair, both
# reservoirs, (T, mu), the seed. What is left is that production RAMPS mu while
# this probe holds it fixed.
#
# `ED_MU_RAMP=<mu_end>` sweeps mu linearly from MU to mu_end across the run, the
# shape #334 drives (8.48 -> 11.72 over 1300 ms). The reservoir is rebuilt each
# step, which is the honest way to do it: k_cut depends on mu, so a ramp that
# held k_cut fixed would be a different experiment and would silently re-answer
# the cutoff-motion question that was already excluded.
const MU_RAMP_END = parse(Float64, get(ENV, "ED_MU_RAMP", "0.0"))
const MU_RAMPS = MU_RAMP_END > 0.0

# `ED_ATOM=eu151` runs the SAME probe at F = 6, 13 components, DDI off.
#
# #418: the full theory stalls on #334's ramp (N_C flat at f = 0.065 where
# growth-only reaches 0.37) and three explanations are already excluded by
# measurement — the projector's number loss (common-mode across the arms), the
# moving cutoff (pinning changes N_C by 5 parts in 3271), and energy damping in
# general (this probe, scalar, condenses at BOTH values of M: 0.586 vs 0.543 of
# N_TF). What is left is specific to that configuration: F = 6, the DDI, or the
# ramp itself.
#
# This separates the first from the other two. Everything is held at the scalar
# probe's values except the spin: same grid, same trap, same reservoir, DDI OFF,
# only c0 in the interactions. If the stall reproduces here it is the spinor; if
# it does not, F = 6 is exonerated and the DDI or the ramp carries it.
const ATOM = get(ENV, "ED_ATOM", "rb87") == "eu151" ? Eu151 : Rb87

# `ED_CDD` turns the DDI on. #418's remaining suspects after the scalar setting
# cleared every part of the SPGPE machinery — projector, moving cutoff, energy
# damping alone, the scattering drift/noise pair, and both reservoirs together
# (which COOL by 60 %) — are the DDI and #334's own ramp and seed. This separates
# the first.
#
# One knob against the same control. `c_dd = 0` is the arm already measured, so
# the comparison is against a number this probe produced rather than against a
# remembered one.
# DERIVED, not picked. The production preset carries c_dd/c0 = 0.0900 (c_dd =
# 211.02 against c0 = 2343.6, unit-norm with N folded in), and that RATIO is what
# transfers between normalisations — the absolute numbers do not. Against this
# probe's C0 = 4pi*a_s it gives 0.0226.
#
# The first attempt passed 0.1 by hand, which is 4.4x that. It was killed rather
# than run: an arm whose knob nobody derived answers about the knob.
const C_DD_OVER_C0_PRODUCTION = 0.0900
const C_DD = parse(Float64,
    get(ENV, "ED_CDD", "0.0")) == -1.0 ? C_DD_OVER_C0_PRODUCTION * C0 :
             parse(Float64, get(ENV, "ED_CDD", "0.0"))

function ground_mode(grid, dV, n_tf)
    gs = find_ground_state(; grid, atom=ATOM,
        interactions=InteractionParams(Dict{Int, Float64}(0 => C0 * n_tf)),
        potential=HarmonicTrap{3}((OMEGA, OMEGA, OMEGA)), dt=0.002, n_steps=3000,
        tol=1e-10, initial_state=:m_minus_F, verbose=false)
    d = gs.workspace.spin_matrices.system.n_components
    phi = Array(view(gs.workspace.state.psi, :, :, :, d))
    phi ./= sqrt(sum(abs2, phi) * dV)
    (phi, d)
end

function arm(grid, dV, phi, d, n_tf, energy_damping::Bool)
    ws = make_workspace(; grid, atom=ATOM,
        interactions=InteractionParams(Dict{Int, Float64}(0 => C0)),
        potential=HarmonicTrap{3}((OMEGA, OMEGA, OMEGA)),
        sim_params=SimParams(; dt=DT, n_steps=1, imaginary_time=false,
            save_every=1, normalize_every=0), fft_flags=FFTW.ESTIMATE,
        enable_ddi=C_DD != 0.0, c_dd=C_DD, secular_ddi=false,
        ddi_padding=false, ddi_trunc_radius=-1.0)
    # M = 0.0 is the growth-only sub-theory; omitting M lets the reservoir use its
    # own physical scattering rate. One knob between the arms.
    # Built per-mu so the ramp arm can rebuild it; identical to the old inline
    # form when mu does not move.
    mkres(mu) = energy_damping ?
                SPGPEReservoir(; T=T_RES, mu=mu, a_s=A_S, k_cut=sqrt(2 * (mu + T_RES)),
        gamma=GAMMA, allow_unphysical_rates=true) :
                SPGPEReservoir(; T=T_RES, mu=mu, a_s=A_S, k_cut=sqrt(2 * (mu + T_RES)),
        gamma=GAMMA, M=0.0, allow_unphysical_rates=true)
    res = mkres(MU)
    # The one knob #418 has left. `vacuum` is the arm every previous round ran:
    # the condensate is built by the reservoir out of nothing. `converged` hands
    # the SPGPE a state that is ALREADY the ground state at this µ — production's
    # situation, where the seed is a converged branch cell — so the reservoir's
    # job is to keep it rather than to make it.
    fill!(ws.state.psi, 0)
    if SEED_MODE == "converged"
        # phi is the normalised ground mode; put N_TF-worth of atoms in it, which
        # is what the growth-only arm reaches unaided. Starting AT the answer is
        # the point: if the full theory cannot hold what growth-only builds, the
        # stall is not a failure to grow.
        @views ws.state.psi[:, :, :, d] .= phi .* sqrt(n_tf)
    end

    out = 0.0
    trunc = 0.0
    for s in 1:NSTEP
        if MU_RAMPS
            # Linear in step index, the same shape #334's FortRamp drives mu on.
            res = mkres(MU + (MU_RAMP_END - MU) * (s - 1) / (NSTEP - 1))
        end
        split_step!(ws)
        r = apply_spgpe_step!(ws, res, DT; t=0.0, seed=SEED0 + s)
        out += get(r, :cutoff_outflow, 0.0)
        trunc += get(r, :noise_truncated, 0.0)
        @views for c in 1:(d - 1)
            ws.state.psi[:, :, :, c] .= 0
        end
    end
    psi = Array(view(ws.state.psi, :, :, :, d))

    # WHERE IN k THE POPULATION SITS. #418 found that F=6 and the DDI are each
    # harmless alone and together drive the cutoff outflow up 786x. A total
    # outflow says it happens; it does not say whether the C region is bleeding
    # from its EDGE (population pushed to high k, then cut) or uniformly.
    #
    # Radial bins of |psi(k)|^2 as a fraction of the norm, in units of k_cut, so
    # arms with different k_cut are comparable. The outermost bin is the one the
    # projector acts on.
    kb = zeros(4)
    let ph = fftshift(fft(ws.state.psi)), kmax = K_CUT
        n = size(ws.state.psi)
        for I in CartesianIndices(ph)
            # k from the shifted index, per axis, in the grid's own units
            k2 = 0.0
            for ax in 1:3
                L_ax = grid.config.box_size[ax]
                idx = I[ax] - (n[ax] ÷ 2) - 1
                k2 += (2π * idx / L_ax)^2
            end
            f = sqrt(k2) / kmax
            b = f < 0.25 ? 1 : f < 0.5 ? 2 : f < 0.8 ? 3 : 4
            kb[b] += abs2(ph[I])
        end
        t = sum(kb)
        t > 0 && (kb ./= t)
    end

    (n0=abs2(sum(conj.(phi) .* psi) * dV), n_c=sum(abs2, psi) * dV, out=out,
        trunc=trunc, kbins=kb)
end

function main()
    # #418's remaining axis after every mechanism was exonerated: SCALE. The
    # probe is 24^3 box 10 and production is 64^3 box 24, and nothing has yet
    # varied that. Defaults reproduce every arm run so far.
    gn = parse(Int, get(ENV, "ED_N", "24"))
    gb = parse(Float64, get(ENV, "ED_BOX", "10.0"))
    grid = make_grid(GridConfig((gn, gn, gn), (gb, gb, gb)))
    dV = cell_volume(grid)
    n_tf = ((2 * MU / OMEGA)^2.5) / (15 * A_S)
    π / minimum(grid.dx) > K_CUT || error("grid does not resolve the C region")
    (phi, d) = ground_mode(grid, dV, n_tf)

    # Every knob in the output line, because the whole value of this probe is that
    # exactly one of them differs between the arm being read and the arm it is
    # being compared against — and a remembered configuration is not a control.
    @printf("grid = %d^3 box %.3g   seed0 = %d\n", gn, gb, SEED0)
    @printf("atom = %s (D = %d)  c_dd = %.4g  mu = %.3g%s  T = %.3g  seed = %s  N_TF = %.1f  steps = %d  M = physical vs 0\n",
        ATOM === Rb87 ? "Rb87" : "Eu151", Int(2 * ATOM.F + 1), C_DD, MU,
        MU_RAMPS ? @sprintf("->%.3g", MU_RAMP_END) : "", T_RES,
        SEED_MODE, n_tf, NSTEP)
    for (name, ed) in (("growth-only (M=0)", false), ("full (M != 0)", true))
        a = arm(grid, dV, phi, d, n_tf, ed)
        @printf("  %-18s N0 = %8.1f (%.3f N_TF)  N_C = %8.1f  out = %.4g  trunc = %.4g\n",
            name, a.n0, a.n0 / n_tf, a.n_c, a.out, a.trunc)
        @printf("  %-18s |psi(k)|^2 by |k|/k_cut:  <0.25 %.4f | 0.25-0.5 %.4f | 0.5-0.8 %.4f | >0.8 %.4f\n",
            "", a.kbins[1], a.kbins[2], a.kbins[3], a.kbins[4])
        flush(stdout)
    end
end

main()
