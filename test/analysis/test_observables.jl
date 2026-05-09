using Test
using SpinorBEC
using Random
using FFTW

@testset "Observables" begin
    @testset "Total density (1D)" begin
        psi = zeros(ComplexF64, 10, 3)
        psi[:, 1] .= 1.0
        psi[:, 2] .= 2.0
        psi[:, 3] .= 3.0

        n = total_density(psi, 1)
        @test n ≈ fill(14.0, 10)
    end

    @testset "Component density" begin
        psi = zeros(ComplexF64, 10, 3)
        psi[:, 2] .= 0.5 + 0.5im

        nc = component_density(psi, 1, 2)
        @test nc ≈ fill(0.5, 10)
    end

    @testset "Magnetization for polarized state" begin
        config = GridConfig(64, 10.0)
        grid = make_grid(config)
        sys = SpinSystem(1)

        psi = init_psi(grid, sys; state=:ferromagnetic)
        Mz = magnetization(psi, grid, sys)
        @test Mz ≈ 1.0 atol = 1e-10
    end

    @testset "Magnetization for polar state" begin
        config = GridConfig(64, 10.0)
        grid = make_grid(config)
        sys = SpinSystem(1)

        psi = init_psi(grid, sys; state=:polar)
        Mz = magnetization(psi, grid, sys)
        @test abs(Mz) < 1e-14
    end

    @testset "Norm of initialized state" begin
        config = GridConfig(128, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(1)

        for state in [:polar, :ferromagnetic, :uniform]
            psi = init_psi(grid, sys; state)
            N = total_norm(psi, grid)
            @test N ≈ 1.0 atol = 1e-12
        end
    end

    @testset "Pair amplitude" begin
        grid = make_grid(GridConfig(32, 10.0))
        cg_table = precompute_cg_table(1)

        @testset "singlet channel matches singlet_pair_amplitude for F=1" begin
            sys = SpinSystem(1)
            psi = init_psi(grid, sys; state=:polar)
            A_new = pair_amplitude(psi, 1, 0, 0, 1, cg_table)
            A_old = singlet_pair_amplitude(psi, 1, 1)
            @test A_new ≈ A_old atol = 1e-14
        end

        @testset "singlet channel matches for uniform state" begin
            sys = SpinSystem(1)
            psi = init_psi(grid, sys; state=:uniform)
            A_new = pair_amplitude(psi, 1, 0, 0, 1, cg_table)
            A_old = singlet_pair_amplitude(psi, 1, 1)
            @test A_new ≈ A_old atol = 1e-14
        end

        @testset "sum rule: Σ g_S|A_{SM}|² = c₀n² + c₁|F|²" begin
            grid32 = make_grid(GridConfig(32, 10.0))
            sm = spin_matrices(1)

            psi = zeros(ComplexF64, 32, 3)
            rng = Random.MersenneTwister(42)
            psi .= randn(rng, ComplexF64, 32, 3)
            dV = cell_volume(grid32)
            norm_sq = sum(abs2, psi) * dV
            psi ./= sqrt(norm_sq)

            c0 = 10.0
            c1 = -0.5

            spec = pair_amplitude_spectrum(psi, 1, grid32)

            n = total_density(psi, 1)
            fx, fy, fz = spin_density_vector(psi, sm, 1)

            lhs = c0 * sum(n .^ 2) * dV + c1 * sum(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) * dV

            g0 = c0 + c1 * (0 * (0 + 1) - 2 * 1 * 2) / 2  # S=0: c0 - 2c1
            g2 = c0 + c1 * (2 * 3 - 2 * 1 * 2) / 2         # S=2: c0 + c1
            rhs = g0 * spec.channel_weights[0] + g2 * spec.channel_weights[2]

            @test lhs ≈ rhs rtol = 1e-10
        end
    end

    @testset "Energy decomposition" begin
        grid = make_grid(GridConfig(64, 10.0))
        interactions = InteractionParams(10.0, -0.5)
        trap = HarmonicTrap(1.0)
        sp = SimParams(; dt=0.01, n_steps=10, imaginary_time=false, save_every=10)
        ws = make_workspace(; grid, atom=Rb87, interactions, potential=trap,
            sim_params=sp, fft_flags=FFTW.ESTIMATE)

        @testset "total matches sum of components" begin
            ed = energy_decomposition(ws)
            component_sum =
                ed.kinetic + ed.trap + ed.zeeman + ed.density +
                ed.spin + ed.ddi + ed.lhy + ed.tensor + ed.raman
            @test ed.total ≈ component_sum atol = 1e-14
        end

        @testset "backward compatible with total_energy" begin
            ed = energy_decomposition(ws)
            @test ed.total ≈ total_energy(ws) atol = 1e-14
        end

        @testset "kinetic energy non-negative" begin
            ed = energy_decomposition(ws)
            @test ed.kinetic >= 0
        end

        @testset "trap energy non-negative" begin
            ed = energy_decomposition(ws)
            @test ed.trap >= 0
        end
    end

    @testset "Structure factor" begin
        grid = make_grid(GridConfig(64, 10.0))
        sys = SpinSystem(1)

        @testset "uniform density → S(k≠0) ≈ 0" begin
            psi = zeros(ComplexF64, 64, 3)
            psi[:, 2] .= 1.0 / sqrt(64.0 * cell_volume(grid))
            S_k = structure_factor(psi, grid)
            @test maximum(abs, S_k[2:end]) < 1e-20
        end

        @testset "modulated density → peak at expected k" begin
            psi = zeros(ComplexF64, 64, 3)
            dx = grid.dx[1]
            for i in 1:64
                x = grid.x[1][i]
                psi[i, 2] = sqrt(1.0 + 0.5 * cos(2π * x / 5.0))
            end
            norm_sq = sum(abs2, psi) * cell_volume(grid)
            psi ./= sqrt(norm_sq)
            S_k = structure_factor(psi, grid)
            @test S_k[1] > 0
        end
    end

    @testset "Modulation contrast" begin
        @testset "uniform → 0" begin
            psi = zeros(ComplexF64, 64, 3)
            psi[:, 2] .= 1.0
            mc = modulation_contrast(psi, 1)
            @test mc ≈ 0.0 atol = 1e-10
        end

        @testset "modulated → positive" begin
            psi = zeros(ComplexF64, 64, 3)
            psi[:, 1] .= 1.0
            psi[1, 1] = 2.0
            mc = modulation_contrast(psi, 1)
            @test mc > 0.0
            @test mc < 1.0
        end
    end

    @testset "Pair amplitude spectrum" begin
        grid = make_grid(GridConfig(32, 10.0))
        sys = SpinSystem(1)

        @testset "polar state |m=0⟩: S=0 weight = 1/3, S=2 weight = 2/3" begin
            psi = init_psi(grid, sys; state=:polar)
            spec = pair_amplitude_spectrum(psi, 1, grid)
            total = spec.channel_weights[0] + spec.channel_weights[2]
            @test spec.channel_weights[0] / total ≈ 1 / 3 rtol = 1e-10
            @test spec.channel_weights[2] / total ≈ 2 / 3 rtol = 1e-10
        end

        @testset "ferromagnetic state: dominant S=2" begin
            psi = init_psi(grid, sys; state=:ferromagnetic)
            spec = pair_amplitude_spectrum(psi, 1, grid)
            total = spec.channel_weights[0] + spec.channel_weights[2]
            @test spec.channel_weights[2] / total > 0.99
        end
    end

    @testset "Multipole order parameters" begin
        @testset "F=1 polar: O_0 dominant" begin
            grid = make_grid(GridConfig(32, 10.0))
            sys = SpinSystem(1)
            psi = init_psi(grid, sys; state=:polar)
            spec = multipole_spectrum(psi, 1, grid)
            @test haskey(spec, 0)
            @test haskey(spec, 2)
            @test spec[0] > 0.0
            @test all(isfinite, values(spec))
        end

        @testset "F=2 returns ranks 0,2,4" begin
            grid = make_grid(GridConfig(32, 10.0))
            sys = SpinSystem(2)
            psi = init_psi(grid, sys; state=:ferromagnetic)
            ops = multipole_order_parameters(psi, 2, 1)
            @test Set(keys(ops)) == Set([0, 2, 4])
            for (k, O_k) in ops
                @test all(x -> x >= -1e-10, O_k)
            end
        end
    end

    @testset "CG array table matches Dict" begin
        F = 2
        cg_dict = precompute_cg_table(F)
        cg_arr = precompute_cg_array(F)

        for S in 0:2:2F, M in (-S):S, m1 in (-F):F
            m2 = M - m1
            abs(m2) > F && continue
            expected = get(cg_dict, (S, M, m1, m2), 0.0)
            @test SpinorBEC.cg_lookup(cg_arr, S, M, m1) ≈ expected atol = 1e-14
        end
    end
end
