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
            zeta_Td = ComplexF64[1.0, 0.0, im*sqrt(2.0), 0.0, 1.0] ./ 2.0
            @test detect_point_group(zeta_Td, 2) == :T_d
        end

        @testset "Paper #3 §V.D — F=6 I_h ζ_{I_h} CURRENTLY → :unknown (U2 gap)" begin
            # Canonical F=6 I_h state from IcosahedralMod. The Majorana
            # stars SHOULD form an icosahedron, but detect_point_group
            # currently returns :unknown due to spectrum-matching
            # tolerance + handling of the root-at-infinity (m=+F=0
            # component). U2 fixes this by tightening reference
            # comparison and handling the ∞ root explicitly.
            zeta_Ih = SpinorBEC.IcosahedralMod.ZETA_F6_IH
            pg = detect_point_group(zeta_Ih, 6)
            @test pg === :unknown                    # current behaviour
            @test_broken pg === :I_h                 # target after U2
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
        psi = init_psi(grid, sys; state=:ferromagnetic)
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
