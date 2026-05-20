# Round-trip test for the KU (c_0, c_1, c_extra) ↔ channel g_S forward map.
#
# Pins:
#  - `ku_c01_to_g_S` works for F = 1, 2, 3, 6 (was F=1-only pre-2026-05-13)
#  - F=1 analytic inverse: c_0 = (g_0 + 2 g_2) / 3, c_1 = (g_2 − g_0) / 3
#  - For arbitrary F, going g_S → tensor c_k (`_gS_to_cn`) → g_S
#    (`_cn_to_gS`) is the identity (Wigner 6j orthogonality)
#  - `ku_to_g_S(F, c_0, c_1, c_extra)` combines `_c0c1_to_gS` and
#    `_c_extra_to_delta_gS` consistently with the rest of `make_workspace`
#
# Regression coverage for the B-3 generalization (was F=1-only pre-2026-05-13).

using Test
using SpinorBEC
using SpinorBEC:
    ku_c01_to_g_S, ku_to_g_S, even_c_extra,
    _c0c1_to_gS, _c_extra_to_delta_gS, _gS_to_cn, _cn_to_gS

@testset "ku_c01_to_g_S generalized to F = 1, 2, 3, 6" begin
    @testset "F=1 analytic round-trip" begin
        c0, c1 = 100.0, 5.0
        g = ku_c01_to_g_S(1, c0, c1)
        @test g[0] ≈ c0 - 2 * c1     # 90
        @test g[2] ≈ c0 + c1         # 105
        # Inverse via known closed form
        c0_back = (g[0] + 2 * g[2]) / 3
        c1_back = (g[2] - g[0]) / 3
        @test c0_back ≈ c0
        @test c1_back ≈ c1
    end

    @testset "F = $F: g_S has 2F+1 even channels, matches _c0c1_to_gS" for F in (1, 2, 3, 6)
        c0, c1 = 100.0, 5.0
        g = ku_c01_to_g_S(F, c0, c1)
        @test sort(collect(keys(g))) == collect(0:2:2F)
        # Public alias must agree with the internal `_c0c1_to_gS` it delegates to.
        ref = _c0c1_to_gS(F, c0, c1)
        for S in 0:2:2F
            @test g[S] ≈ ref[S]
        end
        # Each channel satisfies KU's scalar-product spin Hamiltonian closed form.
        for S in 0:2:2F
            expected = c0 + c1 * (S * (S + 1) - 2 * F * (F + 1)) / 2
            @test g[S] ≈ expected
        end
    end

    @testset "Wigner 6j round-trip: g_S → c_k → g_S (F = $F)" for F in (1, 2, 3, 6)
        # Build a random-ish g_S dict from a non-trivial (c_0, c_1, c_extra)
        c0, c1 = 100.0, 5.0
        c_extra = even_c_extra(F; c2=10.0,
            c4=(F >= 2 ? 3.0 : 0.0),
            c6=(F >= 3 ? 1.5 : 0.0),
            c8=(F >= 4 ? 0.7 : 0.0),
            c10=(F >= 5 ? 0.3 : 0.0),
            c12=(F >= 6 ? 0.1 : 0.0))
        g = ku_to_g_S(F, c0, c1, c_extra)

        # Round-trip via tensor representation
        c_k = _gS_to_cn(F, g)
        g_recovered = _cn_to_gS(F, c_k)

        for S in 0:2:2F
            @test g[S] ≈ g_recovered[S] atol=1e-10
        end
    end

    @testset "ku_to_g_S F=6 Eu151 with all 7 tensor channels" begin
        # Realistic Eu151 input: 7 independent channel couplings.
        F = 6
        c0, c1 = 4689.0, 110.0
        c_extra = even_c_extra(F; c2=50.0, c4=30.0, c6=20.0, c8=10.0,
            c10=5.0, c12=2.0)
        g = ku_to_g_S(F, c0, c1, c_extra)
        @test sort(collect(keys(g))) == collect(0:2:12)

        # Reconstruct via the two-step decomposition used by make_workspace
        base = _c0c1_to_gS(F, c0, c1)
        delta = _c_extra_to_delta_gS(F, c_extra)
        for S in 0:2:12
            expected = get(base, S, 0.0) + get(delta, S, 0.0)
            @test g[S] ≈ expected
        end
    end

    @testset "ku_to_g_S with empty c_extra reduces to ku_c01_to_g_S" begin
        for F in (1, 2, 3, 6)
            c_extra = zeros(Float64, 2F - 1)
            g_full = ku_to_g_S(F, 50.0, 1.5, c_extra)
            g_c01 = ku_c01_to_g_S(F, 50.0, 1.5)
            for S in 0:2:2F
                @test g_full[S] ≈ g_c01[S]
            end
        end
    end
end
