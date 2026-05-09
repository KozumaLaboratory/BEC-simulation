using LinearAlgebra: normalize

@testset "Bogoliubov-de Gennes" begin
    @testset "Scalar BEC phonon dispersion (F=1, polar)" begin
        F = 1
        c0 = 10.0
        n0 = 1.0
        spinor = ComplexF64[0.0, 1.0, 0.0]

        result = bogoliubov_spectrum(;
            spinor, n0, F,
            interactions=InteractionParams(c0, 0.0),
            k_max=5.0, n_k=50,
        )

        @test length(result.k_values) == 50
        @test size(result.omega) == (6, 50)

        # Density (phonon) branch: ω² = ε_k(ε_k + 2μ) where μ = c0*n0
        # This is the LARGEST positive real branch
        mu_eff = c0 * n0
        for ik in 3:10
            k = result.k_values[ik]
            ek = k^2 / 2
            expected = sqrt(ek * (ek + 2 * mu_eff))
            evals_k = result.omega[:, ik]
            pos_real = filter(e -> real(e) > 0.01 && abs(imag(e)) < 0.5, evals_k)
            if !isempty(pos_real)
                best = maximum(real, pos_real)
                @test abs(best - expected) / expected < 0.15
            end
        end
    end

    @testset "Particle-hole symmetry: eigenvalues in ±ω pairs" begin
        F = 1
        spinor = ComplexF64[1.0, 0.0, 0.0]  # ferromagnetic
        result = bogoliubov_spectrum(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(10.0, -5.0),
            k_max=3.0, n_k=20,
        )

        for ik in 1:20
            evals = sort(result.omega[:, ik], by=real)
            for i in 1:3
                # Each eigenvalue should have a partner with opposite sign
                @test abs(evals[i] + evals[end - i + 1]) < 0.1 ||
                    abs(real(evals[i])) < 0.1
            end
        end
    end

    @testset "Goldstone mode: ω(k=0) ≈ 0" begin
        F = 1
        spinor = ComplexF64[0.0, 1.0, 0.0]
        result = bogoliubov_spectrum(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(10.0, 0.0),
            k_max=5.0, n_k=50,
        )

        evals_k0 = result.omega[:, 1]
        min_eval = minimum(abs, evals_k0)
        @test min_eval < 1.0
    end

    @testset "Stable system has no imaginary part" begin
        F = 1
        spinor = ComplexF64[0.0, 1.0, 0.0]
        result = bogoliubov_spectrum(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(10.0, 2.0),
            zeeman=ZeemanParams(0.0, 1.0),
            k_max=5.0, n_k=30,
        )

        @test result.max_growth_rate < 0.5
    end

    @testset "F=2 spectrum computes without error" begin
        F = 2
        D = 5
        spinor = zeros(ComplexF64, D)
        spinor[3] = 1.0  # m=0

        result = bogoliubov_spectrum(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(10.0, 1.0),
            k_max=5.0, n_k=20,
        )

        @test size(result.omega) == (2D, 20)
        @test length(result.k_values) == 20
    end

    @testset "DDI makes some directions unstable" begin
        F = 1
        spinor = ComplexF64[1.0, 0.0, 0.0]

        # Along z (dipole axis) should be different from perpendicular
        r_z = bogoliubov_spectrum(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=10.0,
            k_direction=(0.0, 0.0, 1.0),
            k_max=5.0, n_k=20,
        )

        r_x = bogoliubov_spectrum(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=10.0,
            k_direction=(1.0, 0.0, 0.0),
            k_max=5.0, n_k=20,
        )

        # Spectra should differ
        @test r_z.omega != r_x.omega
    end

    @testset "DDI anomalous matrix differs from normal matrix" begin
        F = 1
        D = 3
        sm = spin_matrices(F)
        # Generic spinor (not an eigenstate of F_z)
        spinor = normalize(ComplexF64[1.0, 0.5 + 0.3im, 0.2 - 0.1im])
        c_dd = 5.0
        Q_ab = SpinorBEC._q_tensor_direction([0.0, 0.0, 1.0])
        h, M_mat = SpinorBEC._bdg_ddi_matrices(spinor, F, D, sm, c_dd, Q_ab)
        # Normal and anomalous must be different for generic spinor
        @test !isapprox(h, M_mat, atol=1e-10)
        # Anomalous matrix should be symmetric: M_{ij} = M_{ji}
        @test M_mat ≈ transpose(M_mat)
    end

    @testset "BdGResult fields" begin
        result = bogoliubov_spectrum(;
            spinor=ComplexF64[0.0, 1.0, 0.0],
            n0=1.0, F=1,
            interactions=InteractionParams(10.0, 0.0),
            k_max=3.0, n_k=10,
        )

        @test result isa BdGResult
        @test length(result.k_values) == 10
        @test result.max_growth_rate >= 0
        @test result.unstable isa Bool
    end

    @testset "Instability scan: stable system" begin
        F = 1
        spinor = ComplexF64[0.0, 1.0, 0.0]
        imap = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(10.0, 2.0),
            zeeman=ZeemanParams(0.0, 1.0),
            k_max=5.0, n_k=30,
        )

        @test imap isa InstabilityMap
        @test !imap.unstable
        @test imap.predicted_wavelength == Inf
        @test suggest_grid_params(imap) === nothing
    end

    @testset "Instability scan: DDI direction anisotropy" begin
        F = 1
        spinor = ComplexF64[1.0, 0.0, 0.0]
        imap = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=10.0,
            k_max=5.0, n_k=30,
        )

        @test imap isa InstabilityMap
        @test length(imap.directions) == 13
        @test size(imap.growth_rates) == (30, 13)
        max_per_dir = [maximum(imap.growth_rates[:, id]) for id in 1:13]
        @test !all(x -> x ≈ max_per_dir[1], max_per_dir)
    end

    @testset "Instability scan: no DDI → all directions equal" begin
        F = 1
        spinor = ComplexF64[1.0, 0.0, 0.0]
        imap = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=0.0,
            k_max=5.0, n_k=30,
        )

        max_per_dir = [maximum(imap.growth_rates[:, id]) for id in 1:length(imap.directions)]
        @test all(x -> isapprox(x, max_per_dir[1]; atol=1e-12), max_per_dir)
    end

    @testset "Instability scan: single direction matches bogoliubov_spectrum" begin
        F = 1
        spinor = ComplexF64[1.0, 0.0, 0.0]
        dir = (0.0, 0.0, 1.0)

        ref = bogoliubov_spectrum(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=5.0,
            k_direction=dir,
            k_max=5.0, n_k=30,
        )

        imap = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=5.0,
            k_max=5.0, n_k=30,
            directions=[dir],
        )

        @test isapprox(ref.max_growth_rate, maximum(imap.growth_rates); atol=1e-12)
        @test imap.k_values ≈ ref.k_values
    end

    @testset "angular_growth_map matches directions" begin
        F = 1
        spinor = ComplexF64[1.0, 0.0, 0.0]
        imap = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=10.0,
            k_max=5.0, n_k=30,
        )
        @test length(imap.angular_growth_map) == length(imap.directions)
        @test length(imap.angular_growth_map) == 13
        for id in 1:length(imap.directions)
            @test imap.angular_growth_map[id] ≈ maximum(imap.growth_rates[:, id])
        end
    end

    @testset "fibonacci_sphere_directions" begin
        dirs = fibonacci_sphere_directions(50)
        @test length(dirs) >= 50
        for d in dirs
            @test d[3] >= 0  # upper hemisphere
            @test abs(d[1]^2 + d[2]^2 + d[3]^2 - 1.0) < 1e-12  # unit norm
        end
    end

    @testset ":dense mode returns enough directions" begin
        F = 1
        spinor = ComplexF64[0.0, 1.0, 0.0]
        imap = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(10.0, 2.0),
            zeeman=ZeemanParams(0.0, 1.0),
            k_max=5.0, n_k=20,
            directions=:dense,
            n_directions=50,
        )
        @test length(imap.directions) >= 50
        @test length(imap.angular_growth_map) == length(imap.directions)
    end

    @testset ":dense no DDI gives same max as :auto" begin
        F = 1
        spinor = ComplexF64[1.0, 0.0, 0.0]
        imap_auto = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=0.0, k_max=5.0, n_k=30,
        )
        imap_dense = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=0.0, k_max=5.0, n_k=30,
            directions=:dense, n_directions=50,
        )
        @test isapprox(imap_auto.max_growth_rate, imap_dense.max_growth_rate; atol=1e-12)
    end

    @testset ":dense with DDI covers similar range as :auto" begin
        F = 1
        spinor = ComplexF64[1.0, 0.0, 0.0]
        imap_auto = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=10.0, k_max=5.0, n_k=30,
        )
        imap_dense = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=10.0, k_max=5.0, n_k=30,
            directions=:dense, n_directions=200,
        )
        # Dense should find a peak within 1% of :auto (may miss exact axis directions)
        @test imap_dense.max_growth_rate > 0.99 * imap_auto.max_growth_rate
    end

    @testset "suggest_grid_params: even n_points, Nyquist satisfied" begin
        F = 1
        spinor = ComplexF64[1.0, 0.0, 0.0]
        imap = bogoliubov_instability_scan(;
            spinor, n0=1.0, F,
            interactions=InteractionParams(5.0, -2.0),
            c_dd=10.0,
            k_max=5.0, n_k=30,
        )

        if imap.unstable
            gp = suggest_grid_params(imap; ndim=2, margin=2.0)
            @test gp !== nothing
            @test length(gp.n_points) == 2
            @test length(gp.box_size) == 2
            @test all(n -> n % 2 == 0, gp.n_points)
            k_nyq = π * gp.n_points[1] / gp.box_size[1]
            @test k_nyq >= 2.0 * imap.k_unstable_range[2]
        end
    end
end
