using Test
using SpinorBEC
using SpinorBEC: _dt_from_epsilon, _ROTATING_ACTUAL_INTEGRATOR

# `epsilon:` must size dt for the integrator that RUNS.
#
# The rotating_basis loop calls `split_step_midpoint!` unconditionally — order 2,
# Strang with a midpoint mean-field predictor. `integrator:` selects nothing; the
# handler's own verbose line even calls it "requested=".
#
# It was nonetheless passed to `_dt_from_epsilon`, which picks an order from the
# NAME (`strang` → 2, `yoshida4`/`cfet4` → 4, `yoshida6` → 6) and returns
# `0.1 · (ε/T)^(1/p)`. So a config asking for accuracy got a dt sized for a
# method it would not run:
#
#     epsilon = 1e-6, duration = 100
#       order 2 needs   dt = 1.0e-5
#       yoshida4 gave   dt = 1.0e-3     100x too large
#       yoshida6 gave   dt = 4.6e-3     464x too large
#
# and because the error of the method that actually runs goes as dt², that is
# **10⁴ times the requested tolerance** for `yoshida4` and 2×10⁵ for `yoshida6`.
# The accuracy knob silently did not deliver, and the saved
# `integrator_meta/integrator` named the method that never ran, so a postmortem
# checking the Larmor-stiff regime read the wrong order too.

@testset "dt from epsilon uses the order that actually runs" begin
    ε, T = 1.0e-6, 100.0

    # CALIBRATION. If `_dt_from_epsilon` ignored its integrator argument the
    # assertions below would pass for the wrong reason. Show it discriminates
    # first, and by the expected factor.
    @testset "the helper is order-sensitive" begin
        d2 = _dt_from_epsilon(ε, T, "strang")
        d4 = _dt_from_epsilon(ε, T, "yoshida4")
        d6 = _dt_from_epsilon(ε, T, "yoshida6")
        @test d2 < d4 < d6
        @test d2 ≈ 0.1 * (ε / T)^(1 / 2) rtol = 1e-12
        @test d4 ≈ 0.1 * (ε / T)^(1 / 4) rtol = 1e-12
        # the factor that made the defect expensive
        @test d4 / d2 ≈ 100.0 rtol = 1e-6
    end

    @testset "the rotating path asks for order 2" begin
        # `strang` is the order-2 key the helper understands; `split_step_midpoint!`
        # is Strang plus a midpoint predictor, same order.
        @test _ROTATING_ACTUAL_INTEGRATOR == "strang"
        @test _dt_from_epsilon(ε, T, _ROTATING_ACTUAL_INTEGRATOR) ≈
            0.1 * (ε / T)^(1 / 2) rtol = 1e-12
    end

    # The handler must pass the CONSTANT, not the config's request. Checked in
    # source because the alternative is running a dynamics step, which this
    # session may not do.
    @testset "the handler does not pass `integrator_name` to the sizer" begin
        src = read(
            joinpath(@__DIR__, "..", "..", "src", "workflow", "experiments",
                "pipeline", "run_step_rotating", "dynamics.jl"), String)
        code = [l for l in split(src, '\n') if !startswith(strip(l), "#")]
        calls = [l for l in code if occursin("_dt_from_epsilon(", l)]
        @test !isempty(calls)
        for c in calls
            @test occursin("_ROTATING_ACTUAL_INTEGRATOR", c)
            @test !occursin("integrator_name", c)
        end
    end

    # And the artifact must record what ran, with the request kept beside it.
    @testset "the saved metadata names the method that ran" begin
        src = read(
            joinpath(@__DIR__, "..", "..", "src", "workflow", "experiments",
                "pipeline", "run_step_rotating", "dynamics.jl"), String)
        code = join([l for l in split(src, '\n') if !startswith(strip(l), "#")], "\n")
        @test occursin(":integrator => \"split_step_midpoint\"", code)
        @test occursin(":integrator_requested", code)
        # the old shape, which claimed the request as the fact
        @test !occursin(":integrator => integrator_name", code)
    end
end
