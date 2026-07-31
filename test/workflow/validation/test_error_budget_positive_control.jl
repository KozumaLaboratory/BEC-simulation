# test/workflow/validation/test_error_budget_positive_control.jl
#
# `NegligibleErrorSpec` encodes a discipline, not a physical law: a comparison
# that CANNOT fail is not evidence that the approximation is good, so `check`
# returns `:indeterminate` — not a pass — when the control does not breach the
# bound. That guard was untested. The mutation harness replaced it with `if
# false` and all 59 workflow test files stayed green (TSUBAME job 8310033),
# which would turn every vacuous budget into a green one with nothing downstream
# able to tell.
#
# A catalog of defects should model the disciplines the code enforces and not
# only its arithmetic; a gate for those disciplines is the other half of that.
#
# The three verdicts, one row each, and they differ only in the control — the
# approximation and baseline are held fixed so nothing else can explain the
# change.

using Test
using SpinorBEC
using SpinorBEC: ErrorBudget, NegligibleErrorSpec, check

@testset "error budget demands a live positive control" begin
    spec = NegligibleErrorSpec(1.0e-3)
    base = 1.0                       # bound = 1e-3
    approx = 1.0e-6                  # comfortably negligible

    _budget(control) = ErrorBudget(;
        label="probe", baseline=base, approximation=approx, control=control)

    @testset "control breaches ⇒ a real verdict" begin
        r = check(spec, _budget(1.0e-2))          # 10× the bound
        @test r.status == :pass
    end

    @testset "control does NOT breach ⇒ indeterminate, not a pass" begin
        # The approximation is just as negligible as in the row above. The only
        # thing that changed is that the comparison can no longer fail.
        r = check(spec, _budget(1.0e-9))
        @test r.status == :indeterminate
        @test r.status != :pass
        @test occursin("cannot fail", r.summary)
    end

    @testset "a failing approximation still fails" begin
        b = ErrorBudget(; label="probe", baseline=base,
            approximation=1.0e-2, control=1.0e-2)
        @test check(spec, b).status == :fail
    end

    @testset "a zero baseline is indeterminate too" begin
        # Nothing for the approximation to be negligible AGAINST. Same failure
        # mode as the missing control: a verdict with no content.
        b = ErrorBudget(; label="probe", baseline=0.0,
            approximation=0.0, control=0.0)
        @test check(spec, b).status == :indeterminate
    end
end
