# A budget is not a stopping rule, and a scan must say which one it hit.
#
# WHY THIS EXISTS
#
# `active_learn_phase_scan` delegates to `bayesian_optimize`, whose only stopping
# condition was `n_iter`. The returned object was identical whether the map had
# been resolved or the loop counter had simply run out, so a truncated scan read
# as a finished one — the same shape as an absent convergence flag written as
# `true` (`gotcha_absent_converged_flag_was_written_as_true_2026_08_20`).
#
# `docs/design/eu_phase_diagram_adaptive_mapping.md` (#57) specifies HOW to build
# the map adaptively and names the boundary detectors. It contains no rule for
# when to stop. This is that rule, and the half that matters most is not the
# criterion: it is that `:budget_exhausted` is REPORTABLE and distinct.
#
# The acquisition value is the right quantity because it is the one active
# learning maximises: it is what the model still expects to learn at the most
# informative point left in the domain. When that is below tolerance, there is
# nothing more to learn AT THIS RESOLUTION — which is a claim about the sampling,
# not about the physics, and the scope should say so wherever it is quoted.

using SpinorBEC
using Test

# A deterministic, cheap objective with one broad optimum. Not physics: the point
# is the CONTROL STRUCTURE, and a real pipeline would make the two arms below cost
# minutes each for no extra information about the stopping logic.
_bowl(p) = -sum(abs2, p .- 0.3)

@testset "a scan reports why it stopped" begin
    r = bayesian_optimize(_bowl, [(0.0, 1.0), (0.0, 1.0)];
        n_init=4, n_iter=6, minimise=false, n_grid=8, seed=1, verbose=false)

    # The field must exist at all — this is the part that makes a truncated scan
    # legible, independent of whether any criterion was configured.
    @test hasproperty(r, :stop_reason)
    @test r.stop_reason === :budget_exhausted
    @test hasproperty(r, :n_evaluations)
    @test r.n_evaluations == 4 + 6
    @test length(r.acq_history) == 6
end

@testset "the criterion actually fires, and does not fire when it should not" begin
    # POSITIVE CONTROL. A tolerance above every acquisition value must stop the
    # scan early, and `n_evaluations` must show it did.
    hot = bayesian_optimize(_bowl, [(0.0, 1.0), (0.0, 1.0)];
        n_init=4, n_iter=20, minimise=false, n_grid=8, seed=1, verbose=false,
        acq_tol=1e9, acq_patience=2)
    @test hot.stop_reason === :acquisition_below_tol
    @test hot.n_evaluations < 4 + 20

    # NEGATIVE CONTROL. A tolerance below every acquisition value must NOT stop
    # it. Without this arm, a criterion that always fires passes the test above,
    # and "the scan converged" becomes a statement about the tolerance.
    cold = bayesian_optimize(_bowl, [(0.0, 1.0), (0.0, 1.0)];
        n_init=4, n_iter=6, minimise=false, n_grid=8, seed=1, verbose=false,
        acq_tol=-1.0, acq_patience=2)
    @test cold.stop_reason === :budget_exhausted
    @test cold.n_evaluations == 4 + 6

    # PATIENCE IS LOAD-BEARING. One quiet iteration is not convergence — an
    # acquisition surface can dip and recover. With patience 2 the run above
    # needed two consecutive quiet iterations, so the stop is not a single sample.
    @test hot.n_evaluations >= 4 + 2
end

@testset "the active-learning wrapper forwards the criterion" begin
    # The wrapper is where a phase scan is actually configured, so a criterion
    # that exists only on the inner function is a criterion nobody sets.
    src = read(
        joinpath(@__DIR__, "..", "..", "src", "workflow", "experiments",
            "optimization", "active_learning.jl"), String)
    @test occursin("acq_tol", src)
    @test occursin("acq_patience", src)
end
