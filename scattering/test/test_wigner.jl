using Test
using Scattering

@testset "Wigner symbols (2j convention)" begin
    # --- 3j: known closed-form values ---
    # (j j 0; m -m 0) = (-1)^(j-m) / √(2j+1)
    # (1 1 0; 0 0 0) = -1/√3
    @test Scattering.wigner_3j_2j(2, 2, 0, 0, 0, 0) ≈ -1 / sqrt(3) atol = 1e-12

    # (1/2 1/2 0; 1/2 -1/2 0) = (-1)^0 / √2 = 1/√2
    @test Scattering.wigner_3j_2j(1, 1, 0, 1, -1, 0) ≈ 1 / sqrt(2) atol = 1e-12

    # (1/2 1/2 0; -1/2 1/2 0) = (-1)^1 / √2 = -1/√2
    @test Scattering.wigner_3j_2j(1, 1, 0, -1, 1, 0) ≈ -1 / sqrt(2) atol = 1e-12

    # (1 1 1; 1 0 -1) = -1/√6  (Racah/Wigner standard convention)
    @test Scattering.wigner_3j_2j(2, 2, 2, 2, 0, -2) ≈ -1 / sqrt(6) atol = 1e-12

    # --- selection rules ---
    # m1+m2+m3 ≠ 0
    @test Scattering.wigner_3j_2j(2, 2, 2, 2, 0, 0) == 0.0
    # triangle violation
    @test Scattering.wigner_3j_2j(2, 2, 8, 0, 0, 0) == 0.0
    # parity mismatch (j-m non-integer): for 2j=2, 2m=1 → forbidden
    @test Scattering.wigner_3j_2j(2, 2, 0, 1, -1, 0) == 0.0

    # --- 3j column permutation: even cycle even, odd cycle phase (-1)^(j1+j2+j3) ---
    v1 = Scattering.wigner_3j_2j(2, 4, 4, 0, 2, -2)
    v2 = Scattering.wigner_3j_2j(4, 4, 2, 2, -2, 0)   # cyclic permutation → same
    v3 = Scattering.wigner_3j_2j(4, 2, 4, 2, 0, -2)   # single swap → phase (-1)^(1+2+2) = -1
    @test v1 ≈ v2 atol = 1e-12
    @test v3 ≈ -v1 atol = 1e-12

    # --- sign flip of all m: phase (-1)^(j1+j2+j3) ---
    a = Scattering.wigner_3j_2j(4, 4, 4, 2, -4, 2)
    b = Scattering.wigner_3j_2j(4, 4, 4, -2, 4, -2)
    @test b ≈ a atol = 1e-12  # j1+j2+j3 = 6, even

    # --- 3j orthogonality: Σ_{m1,m2}(2j3+1)|(j1 j2 j3; m1 m2 -M)|² = 1 when triangle holds ---
    function threej_norm(tj1::Int, tj2::Int, tj3::Int, tM::Int)
        s = 0.0
        for tm1 in -tj1:2:tj1
            tm2 = -tM - tm1
            abs(tm2) > tj2 && continue
            s += Scattering.wigner_3j_2j(tj1, tj2, tj3, tm1, tm2, tM)^2
        end
        (tj3 + 1) * s
    end
    @test threej_norm(4, 4, 4, 0) ≈ 1.0 atol = 1e-12  # j1=j2=j3=2
    @test threej_norm(2, 2, 2, 2) ≈ 1.0 atol = 1e-12  # j=1, M=1

    # --- Clebsch-Gordan: must match 3j × phase × √(2J+1) ---
    # ⟨1/2 1/2; 1/2 -1/2 | 0 0⟩ = 1/√2
    @test Scattering.clebsch_gordan_2j(1, 1, 1, -1, 0, 0) ≈ 1 / sqrt(2) atol = 1e-12
    # ⟨1 1; 1 -1 | 0 0⟩ = 1/√3
    @test Scattering.clebsch_gordan_2j(2, 2, 2, -2, 0, 0) ≈ 1 / sqrt(3) atol = 1e-12
    # ⟨1 1; 1 0 | 2 1⟩ = 1/√2
    @test Scattering.clebsch_gordan_2j(2, 2, 2, 0, 4, 2) ≈ 1 / sqrt(2) atol = 1e-12

    # --- CG completeness: Σ_J |⟨j1m1;j2m2|JM⟩|² = 1 (fixed j1,j2,m1,m2, M=m1+m2) ---
    function cg_complete(tj1::Int, tj2::Int, tm1::Int, tm2::Int)
        tM = tm1 + tm2
        s = 0.0
        for tJ in abs(tj1 - tj2):2:(tj1 + tj2)
            abs(tM) > tJ && continue
            s += Scattering.clebsch_gordan_2j(tj1, tm1, tj2, tm2, tJ, tM)^2
        end
        s
    end
    @test cg_complete(4, 6, 2, -4) ≈ 1.0 atol = 1e-12   # j1=2, j2=3, m1=1, m2=-2
    @test cg_complete(7, 5, 3, 1) ≈ 1.0 atol = 1e-12    # j1=7/2, j2=5/2

    # --- 6j: known closed-form ---
    # {1 1 1; 1 1 1} = 1/6
    @test Scattering.wigner_6j_2j(2, 2, 2, 2, 2, 2) ≈ 1 / 6 atol = 1e-12
    # {a b c; a b 0} = (-1)^(a+b+c) / √((2a+1)(2b+1)) when a=d, b=e, f=0.
    # For {1/2 1/2 1; 1/2 1/2 0}: phase (-1)^(1/2+1/2+1) = +1, value +1/2.
    @test Scattering.wigner_6j_2j(1, 1, 2, 1, 1, 0) ≈ +0.5 atol = 1e-12
    # By column 2↔3 + top/bottom swap: {1/2 1/2 0; 1/2 1/2 1} = same = +1/2.
    @test Scattering.wigner_6j_2j(1, 1, 0, 1, 1, 2) ≈ +0.5 atol = 1e-12

    # --- 6j symmetry: column permutation ---
    x = Scattering.wigner_6j_2j(4, 6, 4, 2, 4, 6)
    y = Scattering.wigner_6j_2j(6, 4, 4, 4, 2, 6)   # swap col 1↔2
    z = Scattering.wigner_6j_2j(4, 6, 4, 2, 4, 6)   # same (identity)
    @test x ≈ y atol = 1e-12
    @test x ≈ z atol = 1e-12

    # --- 6j: swap top/bottom of two columns ---
    p = Scattering.wigner_6j_2j(2, 4, 4, 4, 2, 4)
    q = Scattering.wigner_6j_2j(4, 2, 4, 2, 4, 4)   # swap cols 1 and 2 top↔bottom
    @test p ≈ q atol = 1e-12

    # --- 6j triangle violation ---
    @test Scattering.wigner_6j_2j(2, 2, 20, 2, 2, 2) == 0.0

    # --- 9j: reduction with j9 = 0 ---
    # {j1 j2 j3; j4 j5 j6; j7 j8 0} = δ_{j3,j6} δ_{j7,j8} ·
    #     (-1)^{j2+j3+j4+j7} / √((2j3+1)(2j7+1)) · {j1 j2 j3; j5 j4 j7}
    # For j1=j2=j4=j5=1/2, j3=j6=1, j7=j8=0:
    #   δ(1,1)·δ(0,0)·(-1)^{1/2+1+1/2+0}/√(3·1) · {1/2 1/2 1; 1/2 1/2 0}
    #   = 1·1·(+1)/√3 · (+1/2) = 1/(2√3)
    @test Scattering.wigner_9j_2j(1, 1, 2, 1, 1, 2, 0, 0, 0) ≈
          1 / (2 * sqrt(3)) atol = 1e-12

    # --- 9j: j9=0 reduction with all integer j ---
    # {1 1 1; 1 1 1; 1 1 0} requires j7=j8 to be nonzero only if matches.
    # j7 must equal j8 (column 3 triangle (1,1,0)); j3 must equal j6 (row).
    # Here j3=1=j6 ✓, j7=1=j8 ✓. Formula:
    #   (-1)^{1+1+1+1} / √((2·1+1)(2·1+1)) · {1 1 1; 1 1 1}
    #   = (+1)/3 · (1/6) = 1/18
    @test Scattering.wigner_9j_2j(2, 2, 2, 2, 2, 2, 2, 2, 0) ≈ 1 / 18 atol = 1e-12

    # --- 9j: selection rules ---
    # Row triangle violation: (j1,j2,j3) = (1/2, 1/2, 10) impossible
    @test Scattering.wigner_9j_2j(1, 1, 20, 1, 1, 2, 0, 0, 0) == 0.0
    # Column triangle violation: (j1,j4,j7) = (1, 1, 10)
    @test Scattering.wigner_9j_2j(2, 2, 2, 2, 2, 2, 20, 2, 0) == 0.0

    # --- 9j: transposition symmetry (swap rows/cols with phase) ---
    # The 9j is invariant under transpose (⇄ rows/cols).
    a9 = Scattering.wigner_9j_2j(2, 4, 4, 4, 2, 4, 4, 4, 2)
    b9 = Scattering.wigner_9j_2j(2, 4, 4, 4, 2, 4, 4, 4, 2)  # same
    @test a9 ≈ b9 atol = 1e-12
    # Reflect: (tj1..tj9) transposed indices → same value
    a9t = Scattering.wigner_9j_2j(2, 4, 4, 4, 2, 4, 4, 4, 2)
    @test a9 ≈ a9t atol = 1e-12

    # --- 9j: row permutation — cyclic (even) keeps sign ---
    # {j1 j2 j3}
    # {j4 j5 j6}  =  {j7 j8 j9}
    # {j7 j8 j9}     {j1 j2 j3}
    #                {j4 j5 j6}
    x9  = Scattering.wigner_9j_2j(2, 4, 4, 4, 2, 4, 4, 4, 2)
    x9c = Scattering.wigner_9j_2j(4, 4, 2, 2, 4, 4, 4, 2, 4)
    @test x9 ≈ x9c atol = 1e-12

    # --- 9j: single row swap picks up (-1)^R, R = Σ j (half of Σ 2j) ---
    # Swap rows 1 and 2: x9s = (-1)^R · x9, with
    #   Σ 2j = 30 → R = 15 (odd) → phase −1.
    x9s = Scattering.wigner_9j_2j(4, 2, 4, 2, 4, 4, 4, 4, 2)
    @test x9s ≈ -x9 atol = 1e-12

    # --- 9j: sum formula numerical cross-check against all-half-integer example ---
    # {1/2 1/2 1; 1/2 1/2 1; 1 1 0} at j9=0 reduction: use same identity as above.
    #   (-1)^{1/2+1+1/2+1}/√((3)(3)) · {1/2 1/2 1; 1/2 1/2 1}
    # {1/2 1/2 1; 1/2 1/2 1}: all args equal — classic 6j value.
    # Known: {1/2 1/2 1; 1/2 1/2 1} = +1/6.
    # Phase (-1)^3 = -1. Result: -1/3 · 1/6 = -1/18.
    @test Scattering.wigner_9j_2j(1, 1, 2, 1, 1, 2, 2, 2, 0) ≈ -1 / 18 atol = 1e-12
end
