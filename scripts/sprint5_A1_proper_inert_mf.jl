#!/usr/bin/env julia
# scripts/sprint5_A1_proper_inert_mf.jl
#
# Track A1 proper at GP mean-field — INERT STATE rank for Eu nominal a_S.
#
# Major simplification (anko elevation 2026-06-02): for polyhedral inert
# states ψ(r) = √n(r) · ζ_const, the GP energy ordering reduces to ranking
# g_eff(ζ) = Σ_S g_S σ_S(ζ) among candidate spinors. NO ITP required.
# This is the first cut of A1 proper — if all 7 A1 v2 minima are inert,
# this single algebraic evaluation decides the GS without expensive 2D/3D
# convergence work.
#
# Catastrophic-cancellation-free ΔE: differences between candidate g_eff
# are O(0.001-0.1), well above floating-point noise — no subtraction of
# large E numbers.
#
# Run:   julia --project=. scripts/sprint5_A1_proper_inert_mf.jl
# Expected wall-clock: < 1 second.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15

# Eu nominal c_n → g_S via the existing c_to_g utility
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C2 = 0.05 * C0
const C4 = 0.02 * C0
const C6 = 0.005 * C0

function main()
    println("=== A1 proper (mean-field inert rank) — Eu nominal ===")
    @printf "Atom: %s, N=%d, ω_ref=%.1f rad/s\n" ATOM.name N_ATOMS OMEGA_REF
    @printf "c = (%.2e, %.2e, %.2e, %.2e, %.2e) for n=(0,1,2,4,6)\n" C0 C1 C2 C4 C6

    # Map c → channel g_S via codebase's c_to_g
    ip = InteractionParams(Dict{Int, Float64}(
        0 => C0, 1 => C1, 2 => C2, 4 => C4, 6 => C6))
    g_S = SpinorBEC.c_to_g(F, ip)
    println("\nNominal g_S channel decomposition:")
    for S in 0:2:(2F)
        @printf "  g_%-2d = %+.4e\n" S g_S[S]
    end

    # Rank inert candidates by g_eff = Σ g_S σ_S(ζ)
    candidates = polyhedral_candidate_spinors(F)
    g_eff_dict = Dict{Symbol, Float64}()
    for (label, ζ) in candidates
        g_eff_dict[label] = direct_eff_coupling(ζ, F, g_S)
    end
    sorted_pairs = sort(collect(g_eff_dict); by=x -> x[2])
    println("\nCandidate inert states ranked by g_eff (lowest = mean-field GS):")
    for (i, (label, g_eff)) in enumerate(sorted_pairs)
        @printf "  %d. %-22s  g_eff = %+.6e\n" i string(label) g_eff
    end

    # Direct ΔE — catastrophic-cancellation-free
    winner_label, winner_g = sorted_pairs[1]
    runner_label, runner_g = sorted_pairs[2]
    Δg_via_subtract = runner_g - winner_g
    Δg_direct = direct_eff_coupling_delta(
        candidates[runner_label], candidates[winner_label], F, g_S)
    @printf "\nWinner: %s (g_eff = %.6e)\n" winner_label winner_g
    @printf "Runner-up: %s (g_eff = %.6e)\n" runner_label runner_g
    @printf "Δg_eff (subtract) = %+.6e\n" Δg_via_subtract
    @printf "Δg_eff (direct)   = %+.6e   (should match)\n" Δg_direct

    # σ_S fingerprints for the top 3 — make distinct manifold structure visible
    println("\nσ_S fingerprints of top-3:")
    @printf "%-22s  " "channel"
    for (label, _) in sorted_pairs[1:min(3, end)]
        @printf "%-14s " string(label)
    end
    println()
    for S in 0:2:(2F)
        @printf "%-22s  " "σ_$S"
        for (label, _) in sorted_pairs[1:min(3, end)]
            fp = polyhedral_fingerprint(candidates[label], F)
            @printf "%-14.6f " fp[S]
        end
        println()
    end

    # Project all candidate distances to the winner — shows the manifold
    # structure (which other inert states cluster near the winner)
    println("\nL2 distance from winner ($winner_label) in σ_S space:")
    fp_winner = polyhedral_fingerprint(candidates[winner_label], F)
    for (label, ζ) in candidates
        fp = polyhedral_fingerprint(ζ, F)
        d = sqrt(sum((fp[S] - fp_winner[S])^2 for S in 0:2:(2F)))
        @printf "  %-22s  d = %.4f\n" string(label) d
    end

    # Verdict
    rel_gap = abs(Δg_direct) / abs(winner_g)
    println()
    @printf "Relative g_eff gap (winner ↔ runner-up): %.3e\n" rel_gap
    if rel_gap < 0.01
        println("→ Near-degenerate manifold: GP rank may be reversed by quantum fluctuations.")
        println("  Track B (Paper #3 polyhedral LHY) is load-bearing.")
    elseif rel_gap < 0.1
        println("→ Modest gap: GP gives clear winner but LHY corrections may matter.")
    else
        println("→ Robust winner at GP mean-field; LHY corrections unlikely to flip.")
    end

    println("\n=== Done ===")
end

main()
