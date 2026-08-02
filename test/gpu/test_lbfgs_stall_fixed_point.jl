using SpinorBEC
using LinearAlgebra
using Test

# The L-BFGS floor stop, on the GPU.
#
# `stop_at_floor` ends the solve at the first steepest-descent line search that
# finds no acceptable step, on the argument that such a failure leaves ψ, `grad`
# and `E` untouched with an empty curvature history — so the next iteration
# rebuilds the same direction from the same gradient with the same `E0` and
# repeats the same evaluations to the same answer. The iterate is a fixed point
# of the loop.
#
# That argument assumes the energy evaluation is DETERMINISTIC. On the GPU
# `total_energy` goes through the fused `_gpu_energy_and_optional_grad` pass
# with device reductions, not the CPU registry, so it is a separate claim from
# the CPU gate in `solvers/test_lbfgs_line_search_and_de.jl`.
#
# What this file does NOT assert: that a stall occurs within some step budget.
# Two earlier versions did, and both failed for the uninteresting reason that
# this problem had not reached its floor yet on this backend — while every
# assertion that mattered passed. Whether a given problem reaches its floor in
# N steps is not a property of the stop rule, and a gate that legislates it is a
# gate that gets its step count tuned until it goes green.
#
# What it asserts instead is the mechanism the rule rests on, all of which hold
# whether or not a stall happens to occur:
#
#   1. turning the flag on never changes the answer;
#   2. the line search is deterministic — identical inputs, identical outputs;
#   3. it never mutates the ψ it is given;
#   4. a failure is reachable and returns α = 0 cleanly.

const HAS_CUDA = try
    @eval import CUDA
    CUDA.functional()
catch
    false
end

@testset "LBFGS floor stop is a fixed point (GPU)" begin
    if !HAS_CUDA
        @info "CUDA not functional — GPU floor-stop gate skipped"
        @test true
    else
        grid = make_grid(GridConfig((12, 12, 8), (8.0, 8.0, 6.0)))
        atom = AtomSpecies("test", 2.5e-25, 1, 50e-10, 60e-10, 6.977e-23)
        base = (;
            grid, atom,
            interactions=InteractionParams(Dict(0 => 20.0, 1 => -0.5)),
            potential=HarmonicTrap((1.0, 1.0, 1.5)),
            initial_state=:polar,
            backend=CUDABackend(),
            verbose=false,
        )
        dV = cell_volume(grid)
        F = atom.F

        @testset "the flag never changes the answer" begin
            # The production-safety claim. True whether or not the stop fires:
            # if it fires, the iterate it stopped at is the one the grinding run
            # ends on; if it does not, the two runs are the same run.
            r_stop = find_ground_state_lbfgs(; base..., n_steps=150, tol=1.0e-16)
            r_grind = find_ground_state_lbfgs(;
                base..., n_steps=150, tol=1.0e-16, stop_at_floor=false)
            @test r_stop.energy == r_grind.energy
            @test r_stop.grad_norm == r_grind.grad_norm
            @test Array(r_stop.workspace.state.psi) ==
                Array(r_grind.workspace.state.psi)
            @info "GPU floor stop" stop_reason = r_stop.stop_reason last_step = r_stop.last_step failures =
                r_stop.n_line_search_failures
        end

        @testset "the line search is deterministic and does not mutate its input" begin
            seed = find_ground_state_lbfgs(; base..., n_steps=60, tol=0.0)
            ws = seed.workspace
            psi = copy(ws.state.psi)
            psi_before = copy(psi)

            g = similar(psi)
            E0 = SpinorBEC.energy_gradient!(g, psi, ws)
            SpinorBEC._project_constraints!(g, psi, grid, nothing, F)
            dirn = -g
            slope = SpinorBEC._realdot(g, dirn) * dV

            a1, e1, _, n1 = SpinorBEC._line_search_energy_decrease(
                psi, dirn, E0, ws, grid, dV, nothing, F; slope=slope, expand=true)
            a2, e2, _, n2 = SpinorBEC._line_search_energy_decrease(
                psi, dirn, E0, ws, grid, dV, nothing, F; slope=slope, expand=true)

            # Identical inputs, identical outputs — this is the whole basis for
            # calling a failed steepest-descent search conclusive.
            @test a1 === a2
            @test e1 === e2
            @test n1 == n2
            # And the search reads `psi`, never writes it: the argument that a
            # failure leaves the iterate untouched depends on it.
            @test Array(psi) == Array(psi_before)
        end

        @testset "a failing search returns alpha = 0 without moving psi" begin
            seed = find_ground_state_lbfgs(; base..., n_steps=60, tol=0.0)
            ws = seed.workspace
            psi = copy(ws.state.psi)
            psi_before = copy(psi)

            g = similar(psi)
            E0 = SpinorBEC.energy_gradient!(g, psi, ws)
            SpinorBEC._project_constraints!(g, psi, grid, nothing, F)
            # Uphill, and starting small: E(α) = E0 + α·slope + O(α²) with
            # slope > 0, so every trial from α_init downwards raises the energy
            # and is rejected. This reaches the failure branch without depending
            # on the solve having converged, and without depending on where a
            # full-length step along +grad happens to land.
            up = copy(g)
            slope = SpinorBEC._realdot(g, up) * dV
            @test slope > 0        # positive control: this really is ascent

            α, E, psi_acc, n_eval = SpinorBEC._line_search_energy_decrease(
                psi, up, E0, ws, grid, dV, nothing, F;
                slope=slope, expand=false, α_init=1.0e-3)
            @test α == 0.0
            @test E == E0
            @test n_eval >= 1
            @test Array(psi) == Array(psi_before)
            @test psi_acc === psi   # failure hands back the untouched iterate
        end
    end
end
