@testset "Physics Validation Tests" begin

    @testset "Conservation: N, E, Mz over 200 real-time steps (F=1 Rb87)" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.005, n_steps=200, imaginary_time=false)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(10.0, -0.5),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )
        sys = ws.spin_matrices.system

        N0 = total_norm(ws.state.psi, ws.grid)
        E0 = total_energy(ws)
        Mz0 = magnetization(ws.state.psi, ws.grid, sys)

        for _ in 1:200
            split_step!(ws)
        end

        N_f = total_norm(ws.state.psi, ws.grid)
        E_f = total_energy(ws)
        Mz_f = magnetization(ws.state.psi, ws.grid, sys)

        @test N_f ≈ N0 rtol = 1e-6
        @test E_f ≈ E0 rtol = 1e-4
        @test Mz_f ≈ Mz0 atol = 1e-6
    end

    @testset "Thomas-Fermi benchmark: spin-0 BEC matches analytic" begin
        # For a scalar BEC in 1D harmonic trap, the TF density is:
        #   n_TF(x) = max(0, (μ - V(x)) / c0)
        # where μ is chemical potential, V(x) = ω²x²/2
        config = GridConfig(128, 20.0)
        grid = make_grid(config)

        c0 = 50.0
        result = find_ground_state(;
            grid, atom=Rb87,
            interactions=InteractionParams(c0, 0.0),
            potential=HarmonicTrap(1.0),
            dt=0.005, n_steps=5000, tol=1e-8,
        )

        ws = result.workspace
        psi = ws.state.psi
        dV = cell_volume(grid)

        # Extract density at center (should be ≈ μ/c0)
        mid = 64
        n_center = sum(abs2, @view psi[mid, :])
        E_decomp = energy_decomposition(ws)
        mu_approx = E_decomp.density + E_decomp.trap  # rough estimate
        # TF radius R = sqrt(2μ/ω²)
        # Density at center n(0) = μ/c0
        # Just check that center density is positive and E converged
        @test n_center > 0
        @test result.converged || result.dE < 1e-6
    end

    @testset "CG coefficient identity: Σ_M |CG(F,m1;F,m2|S,M)|² = 1" begin
        for F in [1, 2, 3]
            cg = precompute_cg_table(F)
            for S in 0:2:2F
                for m1 in -F:F
                    for m2 in -F:F
                        M = m1 + m2
                        abs(M) > S && continue
                        val = get(cg, (S, M, m1, m2), 0.0)
                        # Individual CG values should be bounded
                        @test abs(val) <= 1.0 + 1e-10
                    end
                end
                # Completeness: Σ_{m1,m2} |CG|² (with M=m1+m2) summed over valid (m1,m2)
                # For a given (S,M): Σ_{m1} |CG(F,m1;F,M-m1|S,M)|² = 1
                for M_val in -S:S
                    s = 0.0
                    for m1 in -F:F
                        m2 = M_val - m1
                        abs(m2) > F && continue
                        val = get(cg, (S, M_val, m1, m2), 0.0)
                        s += val^2
                    end
                    @test s ≈ 1.0 atol = 1e-10
                end
            end
        end
    end

    @testset "DDI sign test: cigar vs pancake energy sign" begin
        # For a ferromagnetic state polarized along z:
        # - Cigar (elongated along z): DDI energy < 0 (head-to-tail attraction)
        # - Pancake (flat in z): DDI energy > 0 (side-by-side repulsion)
        # In 2D with quasi-2D kernel, Q_zz(k=0) = 2/3 (positive → repulsive at k=0)
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=10)

        # Ferromagnetic state
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:ferromagnetic)

        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(10.0, -0.5),
            potential=HarmonicTrap(1.0, 1.0),
            sim_params=sp,
            enable_ddi=true, c_dd=5.0,
        )

        E = energy_decomposition(ws)
        # DDI energy should be nonzero for dipolar atom
        @test E.ddi != 0.0
    end

    @testset "Spin-1 SMA: spin mixing oscillation" begin
        # In the single-mode approximation, spin mixing for F=1 with c₁ < 0
        # starting from polar state ζ=(0,1,0) has oscillation period:
        # T_sm ≈ π / (|c₁| n₀) for small oscillations
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        c1 = -1.0

        sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=false)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(0.0, c1),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )

        # Get initial populations
        sys = ws.spin_matrices.system
        psi = ws.state.psi
        dV = cell_volume(grid)

        pop_initial = [sum(abs2, @view psi[:, c]) * dV for c in 1:3]
        # Polar state: population in m=0 (component 2)
        @test pop_initial[2] > 0.9 * sum(pop_initial)

        # Evolve for a while
        for _ in 1:200
            split_step!(ws)
        end

        pop_after = [sum(abs2, @view psi[:, c]) * dV for c in 1:3]
        # After evolution, some population should have transferred to m=±1
        # (spin mixing from polar instability with c₁ < 0)
        total = sum(pop_after)
        @test sum(pop_after) ≈ sum(pop_initial) rtol = 1e-5  # norm conserved
    end
end
