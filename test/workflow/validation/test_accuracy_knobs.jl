# Gate for the accuracy-knob registry.
#
# The registry cannot be checked for COMPLETENESS — nothing detects an
# approximation someone adds without registering it, and the file says so. What
# can be checked is that each entry is a real knob and that the switch behaves:
#
#   * a knob whose `reference` equals its `default` is either mis-recorded or not
#     a knob, so the registry would be quietly overstating what it covers;
#   * `with_reference_accuracy` must actually move every global knob, and must
#     restore all of them — including when the body throws, which is the case
#     that matters, since a leaked global changes every later run in the session;
#   * every note must say something, because a knob with no recorded cost is a
#     number nobody can check.

using Test
using SpinorBEC
using SpinorBEC: ACCURACY_KNOBS, with_reference_accuracy, accuracy_report,
    SPIN_TAYLOR_ENABLED, DEALIAS_2_3_ENABLED

@testset "accuracy knob registry" begin
    @test !isempty(ACCURACY_KNOBS)

    @testset "every entry is a real knob" begin
        for k in ACCURACY_KNOBS
            @test k.scope in (:global, :per_run)
            # A reference equal to the default means the entry claims a choice
            # that does not exist.
            @test k.reference != k.default || k.name in (:ddi_padding, :secular_ddi,
                :dtype, :temperature_ratio)
            @test length(k.note) > 40          # a cost, not a label
            if k.scope === :global
                @test k.getter !== nothing && k.setter !== nothing
            end
        end
    end

    @testset "the switch moves every global knob" begin
        globals = filter(k -> k.scope === :global, ACCURACY_KNOBS)
        @test !isempty(globals)
        # Put each global at its DEFAULT first, so "it moved" is a statement
        # about the switch and not about whatever the session happened to hold.
        saved = [k.getter() for k in globals]
        try
            for k in globals
                k.setter(k.default)
            end
            with_reference_accuracy() do
                for k in globals
                    @test k.getter() == k.reference
                end
            end
            for k in globals
                @test k.getter() == k.default    # restored
            end
        finally
            for (k, v) in zip(globals, saved)
                k.setter(v)
            end
        end
    end

    @testset "restores on exception" begin
        before = (SPIN_TAYLOR_ENABLED[], DEALIAS_2_3_ENABLED[])
        @test_throws ErrorException with_reference_accuracy() do
            error("boom")
        end
        @test (SPIN_TAYLOR_ENABLED[], DEALIAS_2_3_ENABLED[]) == before
    end

    @testset "report names the per-run knobs it does not set" begin
        buf = IOBuffer()
        accuracy_report(; io=buf)
        s = String(take!(buf))
        for k in filter(k -> k.scope === :per_run, ACCURACY_KNOBS)
            @test occursin(string(k.name), s)
        end
        # The report must say what it does NOT cover, or it invites being read as
        # a complete switch.
        @test occursin("does NOT set these", s)
    end
end
