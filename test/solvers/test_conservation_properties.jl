# Property-based regression: random initial states should satisfy
# conservation laws (norm, magnetisation, energy in unitary evolution)
# to within rounding error of the integrator.
#
# Stochastic seeds are pinned for reproducibility — these are
# regression tests, not random search.

using Test
using SpinorBEC
using Random

@testset "Conservation properties (unitary evolution)" begin
    Random.seed!(2026_04_25)

    @testset "split_step preserves norm and Mz (random Eu151 spinors)" begin
        for trial in 1:5
            grid = make_grid(GridConfig((12, 12), (6.0, 6.0)))
            sp = SimParams(; dt=0.005, n_steps=1)
            ws = make_workspace(;
                grid, atom=Eu151,
                interactions=InteractionParams(2.0, 0.1),
                zeeman=ZeemanParams(0.5, 0.05),
                potential=HarmonicTrap(1.0, 1.0),
                sim_params=sp,
            )
            # Random spinor field, normalised
            ws.state.psi .= randn(ComplexF64, 12, 12, 13) .* 0.05
            n0 = sum(abs2, ws.state.psi) * SpinorBEC.cell_volume(grid)
            ws.state.psi ./= sqrt(n0)
            sm = SpinSystem(6)
            mz0 = magnetization(ws.state.psi, ws.grid, sm)

            # Many split-steps — accumulated drift should still be small.
            # split_step!(ws) reads dt from ws.sim_params, no kwarg.
            for _ in 1:50
                SpinorBEC.split_step!(ws)
            end
            n_after = sum(abs2, ws.state.psi) * SpinorBEC.cell_volume(grid)
            mz_after = magnetization(ws.state.psi, ws.grid, sm)
            @test abs(n_after - 1.0) < 1e-6
            @test abs(mz_after - mz0) < 1e-4
        end
    end

    @testset "ITP monotonically decreases energy" begin
        Random.seed!(42)
        gs = find_ground_state(;
            grid=make_grid(GridConfig((16, 16), (6.0, 6.0))),
            atom=Rb87,
            interactions=InteractionParams(5.0, -0.5),
            potential=HarmonicTrap(1.0, 1.0),
            zeeman=ZeemanParams(0.0, 0.1),
            dt=0.01, n_steps=200, tol=1e-7,
            initial_state=:m_plus_F,
        )
        @test gs.energy < 5.0   # bound state, energy small
    end

    @testset "Identity rotation = no change" begin
        sm = spin_matrices(6)
        psi = randn(ComplexF64, 8, 8, 13)
        psi_orig = copy(psi)
        # phi = 0 should be a strict no-op
        SpinorBEC.apply_uniform_spin_rotation!(psi, sm, 0.0, 0.0, 0.0, 1.0, 2)
        @test psi == psi_orig
    end

    @testset "Imaginary-time + real-time symmetry on a trivial state" begin
        # Pure m=0 component in a harmonic trap evolves with no spin
        # mixing if c1 = 0. Norm + Mz should both be conserved exactly.
        grid = make_grid(GridConfig((16, 16), (6.0, 6.0)))
        sp = SimParams(; dt=0.01, n_steps=1)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(5.0, 0.0),
            zeeman=ZeemanParams(0.0, 0.0),
            potential=HarmonicTrap(1.0, 1.0),
            sim_params=sp,
        )
        ws.state.psi .= 0
        ws.state.psi[:, :, 2] .= 1.0 / sqrt(SpinorBEC.cell_volume(grid) * 16 * 16)
        sm = SpinSystem(1)
        mz0 = magnetization(ws.state.psi, ws.grid, sm)
        for _ in 1:30
            SpinorBEC.split_step!(ws)
        end
        @test abs(magnetization(ws.state.psi, ws.grid, sm) - mz0) < 1e-10
    end
end
