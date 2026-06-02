#!/usr/bin/env julia
# scripts/sprint5_B_partial_lhy_rank.jl
#
# Track B partial — LHY correction on the GP-degenerate manifold for Eu nominal.
#
# Sprint 5 A1 proper (GP mean-field) result:
#   I_h    g_eff = 93.92  (winner)
#   biaxial g_eff = 94.22  (+0.32%)
#   cyclic  g_eff = 94.24  (+0.34%)
#   polar   g_eff = 94.46  (+0.57%)
#   FM      g_eff = 99.55  (+5.99%)
#
# Top 3 within 0.34% — order-by-disorder candidate. The right tool is
# Paper #3 polyhedral LHY: each inert state has its own closed-form ε_LHY,
# and the LHY correction can in principle reverse the GP rank.
#
# CODEBASE STATUS (2026-06-02): of the 5 candidates,
#   ✓ I_h     — `epsilon_LHY_F6_Ih` (closed form, Paper #3 §V.D)
#   ✓ polar   — `lhy_energy_polar` (Paper #1, F-generic)
#   ✓ FM      — `lhy_energy_fm` (Paper #2, single-mode collapse)
#   ✗ biaxial — NOT IMPLEMENTED (Paper #3 §V extension target)
#   ✗ cyclic  — NOT IMPLEMENTED (Paper #3 §V extension target)
#
# This script:
#   (1) Computes ε_total(n) = (g_eff/2) n² + ε_LHY(n) for the 3 available
#       candidates at Eu nominal g_S, swept over density.
#   (2) Reports the LHY shift relative to GP for each, and the rank within
#       the 3-candidate subset.
#   (3) States explicitly that biaxial/cyclic LHY closed forms are the
#       remaining Paper #3 deliverable before the manifold question is closed.
#
# Run:  julia --project=. scripts/sprint5_B_partial_lhy_rank.jl

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C2 = 0.05 * C0
const C4 = 0.02 * C0
const C6 = 0.005 * C0

function main()
    println("=== Track B partial — GP + LHY rank on Eu nominal manifold ===\n")
    @printf "Atom: %s, N=%d, ω_ref=%.1f rad/s\n" ATOM.name N_ATOMS OMEGA_REF
    @printf "c = (%.2e, %.2e, %.2e, %.2e, %.2e) for n=(0,1,2,4,6)\n\n" C0 C1 C2 C4 C6

    # Build g_S
    ip = InteractionParams(Dict{Int, Float64}(
        0 => C0, 1 => C1, 2 => C2, 4 => C4, 6 => C6))
    g_S = SpinorBEC.c_to_g(F, ip)
    println("g_S channel decomposition:")
    for S in 0:2:(2F)
        @printf "  g_%-2d = %+.4e\n" S g_S[S]
    end

    # GP g_eff for the 3 LHY-implemented candidates
    candidates = polyhedral_candidate_spinors(F)
    available = (:I_h, :polar, :FM)
    g_eff = Dict{Symbol, Float64}()
    for label in available
        g_eff[label] = direct_eff_coupling(candidates[label], F, g_S)
    end
    println("\nGP g_eff (recap from A1 proper):")
    for label in available
        @printf "  %-10s  g_eff = %+.6e\n" string(label) g_eff[label]
    end

    # ε_LHY(n) — closed form per candidate
    ih_ih(n) = SpinorBEC.IcosahedralMod.epsilon_LHY_F6_Ih(n, g_S)
    polar_lhy(n) = SpinorBEC.PolarContactMod.lhy_energy_polar(n, F, g_S)
    fm_lhy(n) = SpinorBEC.FMContactMod.lhy_energy_fm(n, F, g_S)

    # I_h stiffness diagnostic — check c_0 > 0 (else closed form invalid)
    c0_ih, lambda_ih = SpinorBEC.IcosahedralMod.compute_c0_lambda_F6_Ih(g_S)
    @printf "\nI_h stiffness: c_0=%.4e, λ_spin=%.4e\n" c0_ih lambda_ih
    if c0_ih < 0
        @warn "I_h c_0 < 0 — closed form does not apply; need BdG fallback"
    end

    # Energy density per candidate, swept over density
    println("\n--- ε_total(n) = (g_eff/2) n² + ε_LHY(n), per candidate ---\n")
    densities = [0.1, 0.5, 1.0, 2.0, 5.0, 10.0]
    @printf "%-6s  " "n"
    for label in available
        @printf "%-12s %-12s %-10s   " "ε_GP_$label" "ε_LHY_$label" "shift_%"
    end
    println()
    for n in densities
        @printf "%-6.2f  " n
        for label in available
            eGP = g_eff[label] * n^2 / 2
            eLHY = if label === :I_h
                ih_ih(n)
            elseif label === :polar
                polar_lhy(n)
            else
                fm_lhy(n)
            end
            shift = eGP > 1e-30 ? 100 * eLHY / eGP : 0.0
            @printf "%+.4e   %+.4e  %+6.2f%%   " eGP eLHY shift
        end
        println()
    end

    # Pick a representative density and rank
    n_rep = 1.0
    println("\n--- Rank at representative density n=$n_rep ---\n")
    e_total = Dict{Symbol, Float64}()
    for label in available
        eGP = g_eff[label] * n_rep^2 / 2
        eLHY = if label === :I_h
            ih_ih(n_rep)
        elseif label === :polar
            polar_lhy(n_rep)
        else
            fm_lhy(n_rep)
        end
        e_total[label] = eGP + eLHY
    end
    sorted_total = sort(collect(e_total); by=x -> x[2])
    @printf "  %-3s %-10s   %-14s  %-14s\n" "#" "state" "ε_total" "Δε vs GP-winner"
    # GP winner reference
    gp_winner_e = g_eff[:I_h] * n_rep^2 / 2  # I_h was the GP winner
    for (i, (label, e)) in enumerate(sorted_total)
        @printf "  %-3d %-10s   %+.6e  %+.4e (%+.2f%%)\n" i string(label) e (e - gp_winner_e) (
            100 * (e - gp_winner_e) / abs(gp_winner_e)
        )
    end

    # Rank reversal vs GP?
    gp_order = sort(collect(g_eff); by=x -> x[2])
    lhy_order = sorted_total
    gp_top = gp_order[1][1]
    lhy_top = lhy_order[1][1]
    println()
    if gp_top === lhy_top
        @printf "GP winner (%s) survives LHY correction at n=%.1f.\n" string(gp_top) n_rep
    else
        @printf "RANK REVERSAL: GP winner %s → LHY winner %s at n=%.1f.\n" string(gp_top) string(
            lhy_top
        ) n_rep
    end

    # Honest scoping of remaining work
    println("""

--- HONEST SCOPING ---

The 3-candidate (I_h, polar, FM) LHY rank above is NOT the final answer.

GP mean-field placed biaxial_nematic and cyclic_tetrahedral within 0.34% of
I_h — both could in principle reverse rank under LHY correction. Their
closed-form ε_LHY does NOT exist in this codebase, and is the explicit
Paper #3 §V extension target:

  - biaxial_nematic: D_2h symmetry, 5 broken SO(3) generators → 5 spin
    stiffnesses + 1 phonon. Mode count differs from I_h (which has 3 spin
    Goldstones) and from polar (which has 2F = 12 transverse Type-A).

  - cyclic_tetrahedral: T_d symmetry. Distinct stiffness pattern from
    biaxial. Both require offline sympy derivation per Paper #3 §V.

Until those land, this partial answer rules out only the failures within
the 3 candidates checked. A definitive Track B conclusion needs:

  (1) Paper #3 §V derivation of biaxial_nematic LHY closed form
  (2) Paper #3 §V derivation of cyclic_tetrahedral LHY closed form
  (3) Re-run this rank with all 5 candidates

Next session high-value work: pick up the §V.E/V.F derivation in
docs/manuscript/papers/paper3_universal_theorem/main.md following the same
recipe as I_h (§V.D).
""")

    println("=== Done ===")
end

main()
