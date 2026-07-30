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
#   * `:fast` differs from production ONLY where the registry records a measured
#     `fast` value. This is the rule that stops `:fast` from accumulating
#     unmeasured speed choices — which is exactly the failure this whole registry
#     was written after.
#   * the `:reference` precondition refuses the `full_bdg`-from-a-raw-seed
#     combination, with a positive control that it can pass at all.

using Test
using SpinorBEC
using SpinorBEC: ACCURACY_KNOBS, ACCURACY_PROFILE_NAMES, accuracy_profile,
    accuracy_profile_report, check_accuracy_preconditions, passed

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

    @testset ":fast only moves knobs with a MEASURED fast value" begin
        f = accuracy_profile(:fast)
        prod = accuracy_profile(:production)
        for k in per_run
            if k.fast === nothing
                # No measurement ⇒ no speed choice. This is the rule that keeps
                # `:fast` from becoming a pile of guesses.
                @test isequal(getfield(f, k.name), getfield(prod, k.name))
            else
                @test isequal(getfield(f, k.name), k.fast)
                @test !isequal(k.fast, k.default)   # else it is not a trade
            end
        end
        # And it must actually be a profile that trades something, or the name
        # promises what it does not deliver.
        @test any(k -> k.fast !== nothing, per_run)
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
