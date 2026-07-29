# Two L-BFGS bookkeeping gates (2026-07-29).
#
# 1. The line search must leave `ws.state.psi` at the step whose energy it
#    returns. Its own comment says "leave ws.state.psi at best", but the guard
#    was `best_α == α_init`, which is TRUE in the common case that the first
#    trial doubling is rejected — and then the workspace was left holding the
#    rejected step while the returned energy described `α_init`. Latent today
#    (the driver recomputes the retraction and `energy_gradient!` overwrites
#    `ws.state.psi`), so only a direct call can see it; any caller that starts
#    trusting the returned state would inherit a silent mismatch.
#
# 2. `result.dE` must be the energy change across the last step. `E_prev` was
#    assigned the energy AT the accepted point — the same iterate `E_new` is
#    measured at, and bit-identical to it — so `dE` was exactly 0.0 from step 2
#    onward in every run.

using SpinorBEC
using LinearAlgebra
using Test

@testset "L-BFGS line-search state and dE bookkeeping" begin
    grid = make_grid(GridConfig((12, 12, 8), (8.0, 8.0, 6.0)))
    atom = AtomSpecies("test", 2.5e-25, 1, 50e-10, 60e-10, 6.977e-23)
    base = (;
        grid, atom,
        interactions=InteractionParams(Dict(0 => 20.0, 1 => -0.5)),
        potential=HarmonicTrap((1.0, 1.0, 1.5)),
        initial_state=:polar,
        verbose=false,
    )

    @testset "line search leaves the iterate its energy belongs to" begin
        seed = find_ground_state_lbfgs(; base..., n_steps=5, tol=0.0)
        ws = seed.workspace
        psi = copy(ws.state.psi)
        dV = cell_volume(grid)
        F = atom.F

        g = similar(psi)
        E0 = SpinorBEC.energy_gradient!(g, psi, ws)
        SpinorBEC._project_constraints!(g, psi, grid, nothing, F)

        # Sweep the direction scale so the accept-then-expand branch, the
        # backtracking branch, and the "first doubling rejected" corner are all
        # exercised. Every accepted return must describe the state it leaves.
        checked = 0
        for s in (1.0e-6, 1.0e-4, 1.0e-2, 1.0e-1, 1.0, 10.0), expand in (false, true)
            dirn = (-s) .* g
            slope = real(dot(g, dirn)) * dV
            α, E = SpinorBEC._line_search_energy_decrease(
                psi, dirn, E0, ws, grid, dV, nothing, F;
                slope=slope, expand=expand,
            )
            α == 0.0 && continue
            checked += 1
            @test total_energy(ws) == E
        end
        @test checked > 0
    end

    @testset "dE is the last step's energy change, not zero" begin
        # The trajectory is deterministic, so a 6-step run's last step is
        # exactly the 5-step run's endpoint: the 6-step run's reported dE must
        # be the gap between the two runs' energies. `dE > 0` alone would be a
        # weak (and, on a step whose line search fails, flaky) statement; this
        # one is an identity. Before the fix it was exactly 0.0.
        r5 = find_ground_state_lbfgs(; base..., n_steps=5, tol=0.0)
        r6 = find_ground_state_lbfgs(; base..., n_steps=6, tol=0.0)
        gap = abs(r6.energy - r5.energy)
        @test gap > 0            # still descending, so the gate has teeth
        @test r6.dE ≈ gap rtol = 1.0e-8
    end
end
