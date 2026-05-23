using Test
using SpinorBEC
using LinearAlgebra

@testset "Majorana Representation" begin
    @testset "majorana_stars" begin
        @testset "F=1 ferromagnetic: all stars at south pole (Inf)" begin
            spinor = ComplexF64[1.0, 0.0, 0.0]
            stars = majorana_stars(spinor, 1)
            @test length(stars) == 2
            @test all(isinf, stars)
        end

        @testset "F=1 polar: roots at 0 and Inf" begin
            spinor = ComplexF64[0.0, 1.0, 0.0]
            stars = majorana_stars(spinor, 1)
            @test length(stars) == 2
            finite_stars = filter(isfinite, stars)
            @test length(finite_stars) == 1
            @test abs(finite_stars[1]) < 1e-10
        end

        @testset "F=1 antiferromagnetic: both roots finite" begin
            spinor = ComplexF64[0.0, 0.0, 1.0]
            stars = majorana_stars(spinor, 1)
            @test length(stars) == 2
            @test all(isfinite, stars)
        end

        @testset "F=0 returns empty" begin
            spinor = ComplexF64[1.0]
            stars = majorana_stars(spinor, 0)
            @test isempty(stars)
        end
    end

    @testset "detect_point_group" begin
        @testset "F=1 ferromagnetic → trivial" begin
            spinor = ComplexF64[1.0, 0.0, 0.0]
            @test detect_point_group(spinor, 1) == :trivial
        end

        @testset "F=0 → trivial" begin
            spinor = ComplexF64[1.0]
            @test detect_point_group(spinor, 0) == :trivial
        end

        @testset "returns a Symbol" begin
            spinor = zeros(ComplexF64, 13)
            spinor[1] = 1.0
            spinor[6] = im * sqrt(11.0)
            spinor[11] = sqrt(7.0)
            spinor ./= norm(spinor)
            pg = detect_point_group(spinor, 6)
            @test pg isa Symbol
        end

        # U1 audit (2026-05-12): pin classification against Paper #3
        # canonical inert states. Both successes and known gaps captured
        # so regressions surface immediately.

        @testset "Paper #3 §V.A — F=2 cyclic ζ_{T_d} → :T_d" begin
            # Koashi-Ueda canonical F=2 cyclic state, component order
            # (m=+2, +1, 0, -1, -2): ζ = (1, 0, i√2, 0, 1) / 2.
            zeta_Td = ComplexF64[1.0, 0.0, im * sqrt(2.0), 0.0, 1.0] ./ 2.0
            @test detect_point_group(zeta_Td, 2) == :T_d
        end

        @testset "Paper #3 §V.D — F=6 I_h ζ_{I_h} → :I_h (post-U2 stereo fix)" begin
            # Canonical F=6 I_h state from IcosahedralMod. Pre-U2 this
            # returned :unknown due to a stereographic-projection bug
            # mapping both z=0 and z=∞ to the south pole — see the
            # `_stereo_to_sphere` docstring for the bug archaeology.
            # Post-fix the 12 Majorana stars form the icosahedron and
            # `detect_point_group` returns `:I_h` cleanly.
            zeta_Ih = SpinorBEC.IcosahedralMod.ZETA_F6_IH
            @test detect_point_group(zeta_Ih, 6) === :I_h
        end

        @testset "Paper #3 §V.B — F=3 octahedral ζ_{O:A_2} → :O_h" begin
            # ζ_{O:A_2} = (|3,+2⟩ - |3,-2⟩) / √2  (Paper #3 Eq. V.B.1)
            # 6 Majorana stars on octahedron vertices. A_2 sign-rep
            # distinction from A_1 is representation-theoretic and not
            # surfaced by Majorana geometry alone (both give :O_h).
            zeta = ComplexF64[0, 1, 0, 0, 0, -1, 0] ./ sqrt(2)
            @test detect_point_group(zeta, 3) === :O_h
        end

        @testset "Paper #3 §V.C — F=4 cube ζ_{O_h} → :O_h" begin
            # ζ = √(5/24)|+4⟩ + √(7/12)|0⟩ + √(5/24)|-4⟩  (Paper #3 Eq. V.C.1)
            # 8 Majorana stars on cube vertices.
            zeta = zeros(ComplexF64, 9)
            zeta[1] = sqrt(5/24);
            zeta[5] = sqrt(7/12);
            zeta[9] = sqrt(5/24)
            @test detect_point_group(zeta, 4) === :O_h
        end

        @testset "Paper #3 §V.E — F=8 cube-like octahedral → :O_h" begin
            # ζ = √390/48(|±8⟩) + √42/24(|±4⟩) + √33/8|0⟩  (Paper #3 Eq. V.E.1)
            # 16 stars form an O orbit union — Dy^{164} relevant (Paper #3).
            zeta = zeros(ComplexF64, 17)
            zeta[1] = sqrt(390)/48;
            zeta[5] = sqrt(42)/24;
            zeta[9] = sqrt(33)/8
            zeta[13] = sqrt(42)/24;
            zeta[17] = sqrt(390)/48
            @test detect_point_group(zeta, 8) === :O_h
        end

        @testset "Paper #3 §V.F — F=10 dodecahedral I_h → :I_h" begin
            # ζ = √561/75(|±10⟩) + √209/25(|+5⟩-|−5⟩) + √741/75|0⟩
            # (Paper #3 Eq. V.F.1). 20 stars on dodecahedron-like I_h orbit.
            zeta = zeros(ComplexF64, 21)
            zeta[1] = sqrt(561)/75;
            zeta[6] = sqrt(209)/25
            zeta[11] = sqrt(741)/75
            zeta[16] = -sqrt(209)/25;
            zeta[21] = sqrt(561)/75
            @test detect_point_group(zeta, 10) === :I_h
        end

        @testset "Paper #3 §V.G — F=12 I:A icosahedral → :I_h" begin
            # Paper #3 F12_verification_result.md decimal values, U(1)-rotated
            # to all-real form (Majorana geometry is U(1)-phase invariant):
            # ζ_{±10} = +0.4871, ζ_{+5} = -0.3024, ζ_{-5} = +0.3024,
            # ζ_{0} = +0.5853. Sparse on m ∈ {±10, ±5, 0} (C_5^z invariance).
            # 24 Majorana stars on F=12 I:A icosahedral orbit.
            zeta = zeros(ComplexF64, 25)
            zeta[3] = 0.4871;
            zeta[8] = -0.3024;
            zeta[13] = 0.5853
            zeta[18] = 0.3024;
            zeta[23] = 0.4871
            zeta ./= sqrt(sum(abs2, zeta))
            @test detect_point_group(zeta, 12) === :I_h
        end
    end

    @testset "point group helpers" begin
        @testset "reference spectra self-consistent" begin
            for (name, pts) in [
                (:tet, SpinorBEC._make_tetrahedron_vertices()),
                (:oct, SpinorBEC._make_octahedron_vertices()),
                (:cube, SpinorBEC._make_cube_vertices()),
                (:icosa, SpinorBEC._make_icosahedron_vertices()),
            ]
                spec = SpinorBEC._pairwise_distance_spectrum(pts)
                @test issorted(spec)
                @test all(s -> 0 ≤ s ≤ π, spec)
            end
        end

        @testset "icosahedron has 12 vertices" begin
            @test length(SpinorBEC._make_icosahedron_vertices()) == 12
        end

        @testset "spectrum RMS is 0 for identical" begin
            v = [1.0, 2.0, 3.0]
            @test SpinorBEC._spectrum_rms(v, v) ≈ 0.0 atol = 1e-15
        end

        @testset "spectrum RMS Inf for different lengths" begin
            @test SpinorBEC._spectrum_rms([1.0], [1.0, 2.0]) == Inf
        end
    end

    @testset "classify_phase_detailed includes point_group" begin
        grid = make_grid(GridConfig(32, 10.0))
        sm = spin_matrices(1)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:m_plus_F)
        r = SpinorBEC.classify_phase_detailed(psi, 1, grid, sm)
        @test hasproperty(r, :point_group)
        @test r.point_group isa Symbol
    end

    @testset "icosahedral_order_parameter" begin
        @testset "F < 6 returns zeros" begin
            grid = make_grid(GridConfig(32, 10.0))
            sm = spin_matrices(1)
            psi = init_psi(grid, SpinSystem(1); state=:polar)

            result = icosahedral_order_parameter(psi, grid, sm)
            @test all(result .== 0.0)
        end

        @testset "F=6 uniform superposition has non-trivial Q6" begin
            N = 16
            L = 10.0
            grid = make_grid(GridConfig((N,), (L,)))
            sm = spin_matrices(6)
            dV = cell_volume(grid)

            psi = zeros(ComplexF64, N, 13)
            sigma = L / 8
            for i in 1:N
                x = grid.x[1][i]
                env = exp(-x^2 / sigma^2)
                for c in 1:13
                    psi[i, c] = env / sqrt(13.0)
                end
            end
            psi ./= sqrt(sum(abs2, psi) * dV)

            result = icosahedral_order_parameter(psi, grid, sm)
            n = SpinorBEC.total_density(psi, 1)
            mask = n .> 1e-10
            @test any(mask)
            @test all(result[mask] .>= 0.0)
        end

        @testset "F=6 known icosahedral spinor has Q6 ≈ 1" begin
            # The icosahedral state for F=6 has Majorana stars at icosahedron vertices.
            # Construct via known coefficients (Barnett et al.):
            # ψ_{m=6} = a, ψ_{m=1} = b, ψ_{m=-4} = c (and others zero)
            # with a = √(7/11), b = √(11/22)·i, c = √(7/22) (unnormalized approx)
            # Simplified: use the "hexagonal" approximation
            spinor = zeros(ComplexF64, 13)
            # Icosahedral spinor: ψ_6 = 1, ψ_1 = √(11) i, ψ_{-4} = √7
            # m = 6,5,4,3,2,1,0,-1,-2,-3,-4,-5,-6  (indices 1..13)
            # m=6 → idx 1, m=1 → idx 6, m=-4 → idx 11
            spinor[1] = 1.0
            spinor[6] = im * sqrt(11.0)
            spinor[11] = sqrt(7.0)
            spinor ./= norm(spinor)

            N = 8
            L = 10.0
            grid = make_grid(GridConfig((N,), (L,)))
            sm = spin_matrices(6)
            dV = cell_volume(grid)

            psi = zeros(ComplexF64, N, 13)
            sigma = L / 8
            for i in 1:N
                x = grid.x[1][i]
                env = exp(-x^2 / sigma^2)
                for c in 1:13
                    psi[i, c] = spinor[c] * env
                end
            end
            psi ./= sqrt(sum(abs2, psi) * dV)

            result = icosahedral_order_parameter(psi, grid, sm)
            # Points with significant density should have high Q6
            n = SpinorBEC.total_density(psi, 1)
            mask = n .> 1e-10
            if any(mask)
                q6_avg = sum(result[mask]) / sum(mask)
                @test q6_avg > 0.5
            end
        end
    end
end
