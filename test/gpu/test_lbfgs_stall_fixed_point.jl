using SpinorBEC
using Test

# The L-BFGS floor stop, on the GPU.
#
# `stop_at_floor` ends the solve at the first steepest-descent line search that
# finds no acceptable step. The justification is that such a failure leaves ψ,
# `grad` and `E` untouched with an empty curvature history, so every later
# iteration rebuilds the same direction from the same gradient and repeats the
# same evaluations to the same answer — the iterate is a fixed point of the
# loop.
#
# That argument assumes the energy evaluation is DETERMINISTIC. On the CPU that
# is gated in `solvers/test_lbfgs_line_search_and_de.jl`. The GPU is a separate
# claim: `total_energy` there goes through the fused
# `_gpu_energy_and_optional_grad` pass with device reductions, not the CPU
# registry. If it were non-deterministic at the ulp level, the solver could stop
# one iteration before a step that would have been accepted — silently, and only
# on the GPU.
#
# So: run the same solve with the stop on and off and require the two to agree
# on the iterate EXACTLY. Not `≈` — the claim is that stopping gives up nothing,
# and an approximate agreement would not distinguish that from a small loss.

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

        # Reaching the floor must not be left to a step budget. The first
        # attempt asserted a stall within 200 steps and failed on the GPU for
        # the uninteresting reason that this problem had not got there yet —
        # the exact-agreement assertions passed, because both arms had simply
        # run 200 identical steps.
        #
        # So drive to the floor first and hand that ψ to the paired runs. The
        # seed either stalled (ψ IS the fixed point) or ran out of steps very
        # near it; either way the paired runs stall within a few iterations,
        # and the construction does not depend on how many steps this
        # particular problem needs on this particular backend.
        seed = find_ground_state_lbfgs(; base..., n_steps=400, tol=1.0e-16)
        psi0 = Array(seed.workspace.state.psi)

        r_stop = find_ground_state_lbfgs(;
            base..., psi_init=psi0, n_steps=200, tol=1.0e-16)
        r_grind = find_ground_state_lbfgs(;
            base..., psi_init=psi0, n_steps=200, tol=1.0e-16, stop_at_floor=false)

        @test r_stop.stop_reason === :line_search_stalled
        @test r_stop.last_step <= 10
        @test r_grind.stop_reason === :max_steps
        @test r_grind.last_step == 200

        # The whole claim: stopping early costs nothing.
        @test r_stop.energy == r_grind.energy
        @test r_stop.grad_norm == r_grind.grad_norm
        @test Array(r_stop.workspace.state.psi) == Array(r_grind.workspace.state.psi)

        # ...and it is a large saving, not a marginal one.
        @test r_grind.n_line_search_evals > 5 * r_stop.n_line_search_evals
    end
end
