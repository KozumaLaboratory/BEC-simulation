# Lemma 1 General-S closed-form verification (Sign Pattern Anomalous Identity)
#
# Establishes:
#   β_S^(λ_spin) = (S(S+1) - 2F(F+1)) / (2F(F+1)) · β_S^(c0)
#
# at all polyhedral inert states (F=3 octa A_2, F=4 cube, F=6 icosa, F=8 cube-octa A_1).
# All 29 channel coefficients matched at exact rational arithmetic.
#
# Reference: docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md
#
# TWO STATEMENTS, ONE TABLE. This file used to make only the first:
#
#   1. the PAPER's algebra — the prefactor recomputed inline in exact rationals
#      and compared against the published β_λ table. Independent of the
#      simulator by construction, which is the point: it is a check OF the
#      manuscript, so it must not call the code it is meant to certify.
#
#   2. the PRODUCTION path — `sign_pattern_beta_lambda_spin`, which reads
#      `spin_pair_eigenvalue`, must reproduce the same published table.
#
# Statement (1) alone leaves the loop open. Hand-checked algebra sat here, the
# code it should certify sat in `analysis/phases/sign_pattern.jl`, and nothing
# compared the two: the mutation harness shifted λ_S by a constant and this file
# never noticed, because it never calls the function (2026-07-31). Deliberate
# duplication is the oracle — but only once it is gated.
#
# The tables are declared ONCE and both statements run over them, so they cannot
# drift into two versions of "the paper's numbers".

using SpinorBEC
using SpinorBEC: sign_pattern_beta_lambda_spin, predict_lambda_spin_sign
using Test

println("=== Lemma 1 General-S closed form verification ===\n")

# Paper #3 §V. `beta_c0` = Σ_M |⟨S,M|ζ⊗ζ⟩|², `beta_lambda` = the published
# β_S^(λ_spin) it maps to.
const _PAPER3_TABLES = [
    (F=2, label="cyclic T_d A_1",                      # §V, MEMORY 2026-05-18 T94
        beta_c0=Dict(0 => 1//5, 2 => 2//7, 4 => 18//35),
        beta_lambda=Dict(0 => -1//5, 2 => -1//7, 4 => 12//35)),
    (F=3, label="octa A_2",                            # §V.B, Ch.6 §6.8
        beta_c0=Dict(0 => 1//7, 4 => 6//11, 6 => 24//77),
        beta_lambda=Dict(0 => -1//7, 4 => -1//11, 6 => 18//77)),
    (F=4, label="cube",                                # §V.C
        beta_c0=Dict(0 => 1//9, 4 => 98//429, 6 => 40//99, 8 => 10//39),
        beta_lambda=Dict(0 => -1//9, 4 => -49//429, 6 => 2//99, 8 => 8//39)),
    (F=6, label="icosa",                               # §V.D, Ch.6 §6.5
        beta_c0=Dict(0 => 1//13, 6 => 121//323, 10 => 147//391, 12 => 980//5681),
        beta_lambda=Dict(0 => -1//13, 6 => -121//646, 10 => 91//782,
            12 => 840//5681)),
    (F=8, label="cube-octa A_1",                       # §V.E, Ch.6 §6.9
        beta_c0=Dict(
            0 => 1//17, 4 => 1372//12597, 6 => 64//22287, 8 => 330//5681,
            10 => 40768//200583, 12 => 1651420//5816907,
            14 => 37856//365769, 16 => 1714570//9490743),
        beta_lambda=Dict(
            0 => -1//17, 4 => -10633//113373, 6 => -8//3933, 8 => -165//5681,
            10 => -5096//106191, 12 => 412855//17450721,
            14 => 52052//1097307, 16 => 13716560//85416687)),
    (F=10, label="dodec I_h",                          # §V.F
        beta_c0=Dict(
            0 => 1//21, 6 => 2299//24633, 10 => 586625//3163581,
            12 => 3135//20677, 16 => 349448//1554777,
            18 => 131648//736281, 20 => 15895//134199),
        beta_lambda=Dict(
            0 => -1//21, 6 => -18601//246330, 10 => -586625//6327162,
            12 => -912//20677, 16 => 412984//7773885,
            18 => 365024//3681405, 20 => 14450//134199)),
]

@testset "Lemma 1 General-S: β_S^(λ) = (S(S+1) - 2F(F+1))/(2F(F+1)) · β_S^(c0)" begin
    @testset "the paper's algebra — F=$(t.F) $(t.label)" for t in _PAPER3_TABLES
        # Exact rationals, and deliberately NOT via the simulator: this is the
        # check of the manuscript, so it restates the closed form on purpose.
        denom = 2 * t.F * (t.F + 1)
        for S in sort(collect(keys(t.beta_c0)))
            prefactor = (S * (S + 1) - denom) // denom
            @test prefactor * t.beta_c0[S] == t.beta_lambda[S]
        end
    end

    @testset "the production path — F=$(t.F) $(t.label)" for t in _PAPER3_TABLES
        # `sign_pattern_beta_lambda_spin` reads `spin_pair_eigenvalue`, the one
        # declaration the c₀/c₁ → g_S channel map also reads. This is the row
        # that ties the published numbers to the code; the row above cannot,
        # because it never calls it.
        for S in sort(collect(keys(t.beta_c0)))
            got = sign_pattern_beta_lambda_spin(S, t.F, t.beta_c0[S])
            @test got ≈ Float64(t.beta_lambda[S]) rtol = 1e-12
        end
    end

    @testset "the predicted sign matches the published one — F=$(t.F)" for t in
                                                                           _PAPER3_TABLES
        # `predict_lambda_spin_sign` is the other consumer of the same
        # declaration, and the one a Feshbach-engineering channel choice is made
        # from. Cheap, and it separates the two sides of S_bd = √(2F(F+1)) —
        # every table here has channels on both.
        for S in sort(collect(keys(t.beta_lambda)))
            want = t.beta_lambda[S] > 0 ? :positive :
                   (t.beta_lambda[S] < 0 ? :negative : :zero)
            @test predict_lambda_spin_sign(t.F, S) == want
        end
    end
end

println("\n=== Sign-change boundary table: S_bd = sqrt(2F(F+1)) ≈ sqrt(2) F ===")
println("F |  S_bd  | S_bd/F | Empirical S_bd")
println("--|--------|--------|----------------")
empirical_Sbd = Dict(3 => "[4, 6]", 4 => 6, 6 => 10, 8 => 12, 10 => 16, 12 => "predict 18")
for F in [3, 4, 6, 8, 10, 12]
    Sbd = sqrt(2.0 * F * (F + 1))
    println(
        " $F | $(round(Sbd, digits=2)) | $(round(Sbd/F, digits=3)) | $(get(empirical_Sbd, F, "?"))"
    )
end

println("\n=== Lemma 1 General-S: 29 channel coefficients verified across 6 cases ===")
