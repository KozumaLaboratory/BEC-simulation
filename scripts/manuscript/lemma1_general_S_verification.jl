# Lemma 1 General-S closed-form verification (Sign Pattern Anomalous Identity)
#
# Establishes:
#   β_S^(λ_spin) = (S(S+1) - 2F(F+1)) / (2F(F+1)) · β_S^(c0)
#
# at all polyhedral inert states (F=3 octa A_2, F=4 cube, F=6 icosa, F=8 cube-octa A_1).
# All 19 channel coefficients matched at exact rational arithmetic.
#
# Reference: docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md

using Test

println("=== Lemma 1 General-S closed form verification ===\n")

@testset "Lemma 1 General-S: β_S^(λ) = (S(S+1) - 2F(F+1))/(2F(F+1)) · β_S^(c0)" begin
    # --- F=2 cyclic T_d A_1 (paper3 §V, MEMORY 2026-05-18 T94) ---
    @testset "F=2 cyclic T_d A_1" begin
        F = 2
        denom = 2 * F * (F + 1)  # = 12
        β_c0 = Dict(0 => 1//5, 2 => 2//7, 4 => 18//35)
        β_λ_paper3 = Dict(0 => -1//5, 2 => -1//7, 4 => 12//35)
        for S in [0, 2, 4]
            prefactor = (S*(S+1) - denom) // denom
            predicted = prefactor * β_c0[S]
            @test predicted == β_λ_paper3[S]
        end
    end

    # --- F=4 cube (paper3 §V.C) ---
    @testset "F=4 cube" begin
        F = 4
        denom = 2 * F * (F + 1)  # = 40
        β_c0 = Dict(0 => 1//9, 4 => 98//429, 6 => 40//99, 8 => 10//39)
        β_λ_paper3 = Dict(0 => -1//9, 4 => -49//429, 6 => 2//99, 8 => 8//39)
        for S in [0, 4, 6, 8]
            prefactor = (S*(S+1) - denom) // denom
            predicted = prefactor * β_c0[S]
            @test predicted == β_λ_paper3[S]
        end
    end

    # --- F=6 icosa (paper3 §V.D, Ch.6 §6.5) ---
    @testset "F=6 icosa" begin
        F = 6
        denom = 2 * F * (F + 1)  # = 84
        β_c0 = Dict(0 => 1//13, 6 => 121//323, 10 => 147//391, 12 => 980//5681)
        β_λ_paper3 = Dict(0 => -1//13, 6 => -121//646, 10 => 91//782, 12 => 840//5681)
        for S in [0, 6, 10, 12]
            prefactor = (S*(S+1) - denom) // denom
            predicted = prefactor * β_c0[S]
            @test predicted == β_λ_paper3[S]
        end
    end

    # --- F=3 octa A_2 (paper3 §V.B, Ch.6 §6.8) ---
    @testset "F=3 octa A_2" begin
        F = 3
        denom = 2 * F * (F + 1)  # = 24
        β_c0 = Dict(0 => 1//7, 4 => 6//11, 6 => 24//77)
        β_λ_paper3 = Dict(0 => -1//7, 4 => -1//11, 6 => 18//77)
        for S in [0, 4, 6]
            prefactor = (S*(S+1) - denom) // denom
            predicted = prefactor * β_c0[S]
            @test predicted == β_λ_paper3[S]
        end
    end

    # --- F=8 cube-octa A_1 (paper3 §V.E, Ch.6 §6.9) ---
    @testset "F=8 cube-octa A_1" begin
        F = 8
        denom = 2 * F * (F + 1)  # = 144
        β_c0 = Dict(
            0 => 1//17, 4 => 1372//12597, 6 => 64//22287, 8 => 330//5681,
            10 => 40768//200583, 12 => 1651420//5816907,
            14 => 37856//365769, 16 => 1714570//9490743,
        )
        β_λ_paper3 = Dict(
            0 => -1//17, 4 => -10633//113373, 6 => -8//3933, 8 => -165//5681,
            10 => -5096//106191, 12 => 412855//17450721,
            14 => 52052//1097307, 16 => 13716560//85416687,
        )
        for S in [0, 4, 6, 8, 10, 12, 14, 16]
            prefactor = (S*(S+1) - denom) // denom
            predicted = prefactor * β_c0[S]
            @test predicted == β_λ_paper3[S]
        end
    end

    # --- F=10 dodec I_h (paper3 §V.F) ---
    @testset "F=10 dodec I_h" begin
        F = 10
        denom = 2 * F * (F + 1)  # = 220
        β_c0 = Dict(
            0 => 1//21,
            6 => 2299//24633,
            10 => 586625//3163581,
            12 => 3135//20677,
            16 => 349448//1554777,
            18 => 131648//736281,
            20 => 15895//134199,
        )
        β_λ_paper3 = Dict(
            0 => -1//21,
            6 => -18601//246330,
            10 => -586625//6327162,
            12 => -912//20677,
            16 => 412984//7773885,
            18 => 365024//3681405,
            20 => 14450//134199,
        )
        for S in [0, 6, 10, 12, 16, 18, 20]
            prefactor = (S*(S+1) - denom) // denom
            predicted = prefactor * β_c0[S]
            @test predicted == β_λ_paper3[S]
        end
    end
end

println("\n=== Sign-change boundary table: S_bd = sqrt(2F(F+1)) ≈ sqrt(2) F ===")
println("F |  S_bd  | S_bd/F | Empirical S_bd")
println("--|--------|--------|----------------")
empirical_Sbd = Dict(3 => "[4, 6]", 4 => 6, 6 => 10, 8 => 12, 10 => 16, 12 => "predict 18")
for F in [3, 4, 6, 8, 10, 12]
    Sbd = sqrt(2.0 * F * (F + 1))
    println(" $F | $(round(Sbd, digits=2)) | $(round(Sbd/F, digits=3)) | $(get(empirical_Sbd, F, "?"))")
end

println("\n=== Lemma 1 General-S: 29 channel coefficients verified across 6 cases ===")
