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

    @testset "stops at the floor instead of burning n_steps" begin
        # With `tol` below the problem's attainable gradient floor the solver
        # reaches the floor and then cannot decrease the energy at all. Before
        # the stall check it ran to `n_steps` regardless, at ~30 futile energy
        # evaluations each — measured 97.8 % of 2000 steps on Eu-151 F=6 24³ at
        # the DEFAULT tol=1e-8, whose floor is 5e-7.
        #
        # Once two consecutive line searches fail the state is a fixed point: ψ
        # is unchanged, the history has been emptied, so the next iteration
        # forms the same steepest-descent direction from the same gradient and
        # fails identically. Stopping there cannot cost anything, and the two
        # runs below must therefore agree on the iterate exactly.
        r_stop = find_ground_state_lbfgs(; base..., n_steps=400, tol=1.0e-16)
        r_grind = find_ground_state_lbfgs(; base..., n_steps=400, tol=1.0e-16,
            stop_at_floor=false)

        @test r_stop.stop_reason === :line_search_stalled
        @test r_stop.last_step < 400
        # Conclusive at the FIRST steepest-descent failure — no tunable count.
        @test r_stop.n_line_search_failures <= 2
        @test r_grind.stop_reason === :max_steps
        @test r_grind.last_step == 400
        # Same fixed point, so the early stop gives up nothing.
        @test r_stop.energy == r_grind.energy
        @test r_stop.grad_norm == r_grind.grad_norm
        # ...and it is a large saving, not a marginal one.
        @test r_grind.n_line_search_evals > 5 * r_stop.n_line_search_evals
    end

    @testset "the floor is a fixed point under a magnetization constraint too" begin
        # The stop rule rests on a failed steepest-descent line search leaving
        # the iterate untouched, which needs the whole evaluation — including
        # the constrained retraction `_normalize_psi_constrained!`, which
        # ITERATES — to be deterministic. Checked separately from the
        # unconstrained case because it is a different code path.
        cons = (; base..., target_magnetization=0.0)
        r_stop = find_ground_state_lbfgs(; cons..., n_steps=300, tol=1.0e-16)
        r_grind = find_ground_state_lbfgs(; cons..., n_steps=300, tol=1.0e-16,
            stop_at_floor=false)
        @test r_stop.stop_reason === :line_search_stalled
        @test r_grind.stop_reason === :max_steps
        @test r_stop.energy == r_grind.energy
        @test r_stop.grad_norm == r_grind.grad_norm
    end

    @testset "line-search evaluation count is reported" begin
        # This count, not any single kernel, is what sets the cost of an
        # iteration: a 5-minute measurement of Eu-151 F=6 at 24³ put the
        # iteration at ~245 ms against a component sum of ~57 ms. It has to be
        # a real count — at least one trial per step that took a step.
        r = find_ground_state_lbfgs(; base..., n_steps=6, tol=0.0)
        @test r.n_line_search_evals >= r.last_step
        @test r.n_line_search_evals == round(Int, r.n_line_search_evals)
    end
end
