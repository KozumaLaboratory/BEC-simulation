using Test
using SpinorBEC
using LinearAlgebra
using Random
using Statistics
using FFTW

# Physics invariants that require ITP/RTP — CI tier (heavier than the
# pure-algebra tests in test_property_based.jl).
#
# What each block guards:
#   - Conservation     : split-step preserves N, E, Mz with non-degenerate
#                        spin_coherent initial states (catches sign /
#                        normalization regressions in F>1 spin operators).
#   - Thomas-Fermi     : strong-c0 GS converges to TF profile and chemical
#                        potential — confirms ITP solves the right scalar GP.
#   - Virial           : 2 E_kin − 2 E_trap + N_dim · E_int = 0 in harmonic
#                        trap — independent global confirmation of GS.
#   - Stationarity     : ITP output is fixed under RT (modulo phase) — checks
#                        ITP and RT solve the same Hamiltonian.
#   - GS minimum       : a few extra ITP steps from the converged ψ produce
#                        only sub-tol energy change — proxy for ‖∇E‖ ≈ 0.
#   - Bogoliubov       : weak plane-wave perturbation oscillates at the
#                        BdG frequency ω = √(k²(k²+2c₀n₀)) for scalar GP —
#                        cross-checks dynamics & analysis layers.

@testset "Physics invariants (CI tier)" begin

    # ── Test 3: Conservation under RT with non-degenerate spin_coherent ──
    @testset "Conservation E, N, Mz under RT (F=$F, spin_coherent)" for (F, atom_sym) in
                                                                        [(1, :Rb87), (6, :Eu151)]
        grid = make_grid(GridConfig((10, 10, 10), (8.0, 8.0, 8.0)))
        atom = ATOM_REGISTRY[atom_sym]
        sys = SpinSystem(F)

        psi_init = init_psi(grid, sys; state=:spin_coherent,
            init_theta=π / 3, init_phi=0.4)

        # Modest interactions to keep stable; c1 ≠ 0 exercises spin sector.
        interactions = InteractionParams(10.0, 1.0)
        trap = HarmonicTrap((1.0, 1.0, 1.0))

        sp = SimParams(;
            dt=0.001, n_steps=400, save_every=40, imaginary_time=false
        )
        ws = make_workspace(;
            grid, atom, interactions, potential=trap,
            sim_params=sp, psi_init=psi_init,
        )

        E0 = total_energy(ws)
        N0 = total_norm(ws.state.psi, grid)
        Mz0 = magnetization(ws.state.psi, grid, sys)

        result = run_simulation!(ws)

        @test all(n -> abs(n - N0) < 1e-10, result.norms)

        E_drift = maximum(abs.(result.energies .- E0)) / max(abs(E0), 1.0)
        @test E_drift < 1e-3

        Mz_final = magnetization(ws.state.psi, grid, sys)
        @test abs(Mz_final - Mz0) < 1e-7
    end

    # ── Test 4: Thomas-Fermi limit (3D harmonic, scalar GP regime) ──────
    @testset "Thomas-Fermi limit (3D harmonic, F=1 ferromagnetic)" begin
        grid = make_grid(GridConfig((32, 32, 32), (12.0, 12.0, 12.0)))
        interactions = InteractionParams(200.0, 0.0)
        trap = HarmonicTrap((1.0, 1.0, 1.0))

        gs = find_ground_state(;
            grid, atom=Rb87, interactions, potential=trap,
            dt=0.005, n_steps=2000, tol=1e-8, initial_state=:ferromagnetic,
            verbose=false,
        )

        psi = gs.workspace.state.psi
        n_total = total_density(psi, 3)
        n_peak = maximum(n_total)

        # TF prediction (N=1, ω=1): μ = (1/2)(15 c₀ / (4π))^(2/5)
        μ_TF = 0.5 * (15 * interactions.c0 / (4π))^(2 / 5)
        n_peak_TF = μ_TF / interactions.c0

        @test abs(n_peak - n_peak_TF) / n_peak_TF < 0.10

        # Profile shape: parabola n(r)/n0 = max(0, 1 − r²/(2μ))
        cx = (size(n_total, 1) + 1) ÷ 2
        cy = (size(n_total, 2) + 1) ÷ 2
        z_grid = grid.x[3]
        n_axis = n_total[cx, cy, :] ./ n_peak
        n_TF_predict = [max(0.0, 1.0 - z^2 / (2 * μ_TF)) for z in z_grid]

        rmse = sqrt(sum((n_axis .- n_TF_predict) .^ 2) / length(z_grid))
        @test rmse < 0.10
    end

    # ── Test 11: Virial theorem in harmonic trap ────────────────────────
    @testset "Virial theorem (3D harmonic, F=1)" begin
        grid = make_grid(GridConfig((24, 24, 24), (10.0, 10.0, 10.0)))
        interactions = InteractionParams(40.0, 0.0)
        trap = HarmonicTrap((1.0, 1.0, 1.0))

        gs = find_ground_state(;
            grid, atom=Rb87, interactions, potential=trap,
            dt=0.005, n_steps=2000, tol=1e-9, initial_state=:ferromagnetic,
            verbose=false,
        )
        edec = energy_decomposition(gs.workspace)

        # 3D harmonic + contact: 2 E_kin − 2 E_trap + 3 (E_density+E_spin) = 0.
        virial = 2 * edec.kinetic - 2 * edec.trap +
                 3 * (edec.density + edec.spin)
        @test abs(virial) / max(abs(edec.total), 1.0) < 0.05
    end

    # ── Test 13: GS is stationary under real-time evolution ─────────────
    @testset "GS is stationary under RT (overlap ≈ 1)" begin
        grid = make_grid(GridConfig((16, 16, 16), (10.0, 10.0, 10.0)))
        interactions = InteractionParams(20.0, 0.0)
        trap = HarmonicTrap((1.0, 1.0, 1.0))

        gs = find_ground_state(;
            grid, atom=Rb87, interactions, potential=trap,
            dt=0.005, n_steps=2000, tol=1e-9, initial_state=:ferromagnetic,
            verbose=false,
        )
        psi0 = copy(gs.workspace.state.psi)

        sp_rt = SimParams(;
            dt=0.001, n_steps=500, save_every=500, imaginary_time=false
        )
        ws_rt = make_workspace(;
            grid, atom=Rb87, interactions, potential=trap,
            sim_params=sp_rt, psi_init=psi0,
        )
        run_simulation!(ws_rt)

        dV = cell_volume(grid)
        overlap = abs(sum(conj.(psi0) .* ws_rt.state.psi)) * dV
        @test overlap > 0.999
    end

    # ── Test 8: GS minimum (energy plateau on extra ITP) ────────────────
    @testset "GS energy plateaus under additional ITP polish" begin
        grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
        interactions = InteractionParams(15.0, 0.5)
        trap = HarmonicTrap((1.0, 1.0, 1.0))

        gs = find_ground_state(;
            grid, atom=Rb87, interactions, potential=trap,
            dt=0.005, n_steps=3000, tol=1e-9, initial_state=:ferromagnetic,
            verbose=false,
        )
        psi0 = copy(gs.workspace.state.psi)
        E0 = gs.energy

        sp_polish = SimParams(;
            dt=0.005, n_steps=300, save_every=300, imaginary_time=true
        )
        ws_polish = make_workspace(;
            grid, atom=Rb87, interactions, potential=trap,
            sim_params=sp_polish, psi_init=psi0,
        )
        run_simulation!(ws_polish)
        E_after = total_energy(ws_polish)

        @test E0 - E_after < 1e-5    # additional ITP shaves at most 1e-5
        @test E_after <= E0 + 1e-9   # never increases
    end

    # ── Test 9: Phonon dispersion matches Bogoliubov (F=1 scalar GP, 1D) ──
    @testset "Bogoliubov dispersion match (1D, F=1 polar background)" begin
        F = 1
        n = 64
        L = 20.0
        grid = make_grid(GridConfig(n, L))
        sys = SpinSystem(F)

        # Uniform polar (m=0) background + plane-wave amplitude perturbation.
        n0 = 1.0
        ε = 0.02
        n_modes = 4
        k_phys = 2π * n_modes / L
        x = collect(grid.x[1])
        psi_init = zeros(ComplexF64, n, 2F + 1)
        psi_init[:, F + 1] .= sqrt(complex(n0)) .+ ε .* cos.(k_phys .* x)

        c0 = 5.0
        interactions = InteractionParams(c0, 0.0)

        sp = SimParams(;
            dt=0.002, n_steps=8000, save_every=4, imaginary_time=false
        )
        ws = make_workspace(;
            grid, atom=ATOM_REGISTRY[:Rb87], interactions,
            potential=NoPotential(),
            sim_params=sp, psi_init=psi_init,
        )

        result = run_simulation!(ws)

        # Density at x=L/4 over time → FFT → peak frequency.
        # For amplitude perturbation δψ = ε cos(kx), δn ∝ cos(kx) cos(ωt),
        # so density at fixed x oscillates at ω (not 2ω).
        sample_idx = (n ÷ 4) + 1
        comp = F + 1
        n_t = [abs2(snap[sample_idx, comp]) for snap in result.psi_snapshots]
        n_t .-= mean(n_t)

        n_samples = length(n_t)
        dt_save = sp.dt * sp.save_every
        spec = abs.(fft(n_t))
        half = n_samples ÷ 2
        peak_idx = argmax(spec[2:half]) + 1
        ω_obs = 2π * (peak_idx - 1) / (n_samples * dt_save)

        # Dimensionless ℏ=m=1: ε_k = k²/2, ω = √(ε_k(ε_k + 2 c₀ n₀)).
        ε_k = k_phys^2 / 2
        ω_predict = sqrt(ε_k * (ε_k + 2 * c0 * n0))

        @test abs(ω_obs - ω_predict) / ω_predict < 0.15
    end
end
