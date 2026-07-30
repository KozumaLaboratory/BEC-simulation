# Gate for the named accuracy profiles.
#
# The profiles are DERIVED from `ACCURACY_KNOBS`, so "every knob appears in every
# profile" is structural and needs no test. What does need pinning is the part a
# future edit could quietly break — the properties that make the names honest:
#
#   * `:reference` really is every knob's most accurate setting. A profile called
#     reference that silently left one knob at its default would be worse than no
#     profile, because the name is what a caller trusts instead of the list.
#   * `:production` really is the shipped defaults, so "what am I running now"
#     has an answer.
#   * `:fast` is SOLVED from a budget. A knob with no measured ladder cannot move
#     at any budget; a laddered knob picks the cheapest rung within budget; and a
#     tighter budget never picks a looser setting. The specific case this exists
#     for is pinned: `ddi_pad_factor = 1.5` is the only real speedup among the
#     knobs and must be REJECTED, because its residual is 4.4× what production
#     already carries — a hand-picked `fast` field had it in, and that was the
#     defect this design replaces.
#   * the `:reference` precondition refuses the `full_bdg`-from-a-raw-seed
#     combination, with a positive control that it can pass at all.

using Test
using SpinorBEC
using SpinorBEC: ACCURACY_KNOBS, ACCURACY_PROFILE_NAMES, accuracy_profile,
    accuracy_profile_for_budget, accuracy_profile_report,
    check_accuracy_preconditions, passed

@testset "accuracy profiles" begin
    per_run = filter(k -> k.scope === :per_run, ACCURACY_KNOBS)
    @test !isempty(per_run)

    @testset "every profile covers every per-run knob" begin
        for name in ACCURACY_PROFILE_NAMES
            p = accuracy_profile(name)
            for k in per_run
                @test hasproperty(p, k.name)
            end
            @test length(propertynames(p)) == length(per_run)
        end
    end

    @testset ":reference is the most accurate setting, everywhere" begin
        p = accuracy_profile(:reference)
        for k in per_run
            @test isequal(getfield(p, k.name), k.reference)
        end
    end

    @testset ":production is the shipped defaults" begin
        p = accuracy_profile(:production)
        for k in per_run
            @test isequal(getfield(p, k.name), k.default)
        end
    end

    @testset ":fast is SOLVED from a budget, not chosen" begin
        prod = accuracy_profile(:production)
        for k in per_run
            isempty(k.ladder) || continue
            # No measured ladder ⇒ the knob cannot move, at any budget. An
            # unmeasured trade is not a trade.
            for frac in (1.0e-6, 1.0, 1.0e6)
                @test isequal(getfield(accuracy_profile_for_budget(frac), k.name),
                    getfield(prod, k.name))
            end
        end

        laddered = filter(k -> !isempty(k.ladder), per_run)
        @test !isempty(laddered)          # else the mechanism is untested
        for k in laddered
            # The default must itself be a rung, and its rel_error must be the
            # accepted_error — otherwise the budget is measured against a number
            # that does not describe what is being run.
            hit = findfirst(r -> isequal(r.value, k.default), k.ladder)
            @test hit !== nothing
            @test k.ladder[hit].rel_error ≈ k.accepted_error rtol = 1e-9

            # Every admissible rung really is within budget, and the chosen one is
            # the cheapest of them.
            for frac in (0.5, 1.0, 5.0)
                chosen = getfield(accuracy_profile_for_budget(frac), k.name)
                adm = filter(r -> r.rel_error <= frac * k.accepted_error, k.ladder)
                if isempty(adm)
                    @test isequal(chosen, k.default)
                else
                    @test isequal(chosen, argmin(r -> r.rel_cost, adm).value)
                end
            end
        end

        # The finding this design exists for: ddi_pad_factor = 1.5 is the only
        # real speedup among the knobs (0.906× at 32³) and it must NOT be selected
        # at any sane budget, because its 1.9e-2 residual is 4.4× the 4.3e-3 the
        # production setting already carries. A hand-picked `fast` field had it in;
        # the budget rule throws it out.
        for frac in (1.0e-3, 0.1, 1.0)
            @test accuracy_profile_for_budget(frac).ddi_pad_factor == 2.0
        end
        # …and it IS reachable, so the rejection is about the budget and not about
        # the rung being unreachable.
        @test accuracy_profile_for_budget(10.0).ddi_pad_factor == 1.5
    end

    @testset "a tighter budget never picks a looser setting" begin
        # Monotonicity: shrinking the budget cannot make a knob less accurate.
        for k in filter(k -> !isempty(k.ladder), per_run)
            errs = map((1.0e-4, 1.0e-2, 1.0, 100.0)) do frac
                v = getfield(accuracy_profile_for_budget(frac), k.name)
                r = k.ladder[findfirst(x -> isequal(x.value, v), k.ladder)]
                r.rel_error
            end
            @test issorted(errs)
        end
    end

    @testset "unknown profile names are refused" begin
        @test_throws ArgumentError accuracy_profile(:turbo)
    end

    @testset ":reference refuses full_bdg tabulated from a raw seed" begin
        bad = check_accuracy_preconditions(:reference; relaxed_initial_state=false)
        @test !passed(bad)
        @test occursin("scheme-dependent", bad.summary)
        # Positive control: the check CAN pass, so the failure above is about the
        # input and not about the check being unsatisfiable.
        ok = check_accuracy_preconditions(:reference; relaxed_initial_state=true)
        @test passed(ok)
        # Production does not use full_bdg, so it has no such precondition.
        @test passed(check_accuracy_preconditions(:production;
            relaxed_initial_state=false))
    end

    @testset "the report names what it does NOT set" begin
        buf = IOBuffer()
        accuracy_profile_report(:fast; io=buf)
        s = String(take!(buf))
        @test occursin("NOT set by this profile", s)
        @test occursin("with_reference_accuracy", s)
        buf2 = IOBuffer()
        accuracy_profile_report(:reference; io=buf2)
        @test occursin("scheme-dependent", String(take!(buf2)))
    end
end
