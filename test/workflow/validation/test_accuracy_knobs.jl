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
    dominated_knobs,
    SPIN_TAYLOR_ENABLED, DEALIAS_2_3_ENABLED

@testset "accuracy knob registry" begin
    @test !isempty(ACCURACY_KNOBS)

    @testset "every entry is a real knob" begin
        for k in ACCURACY_KNOBS
            @test k.scope in (:global, :per_run)
            # A reference equal to the default means the entry claims a choice
            # that does not exist.
            # `reference == default` is allowed only where the knob is not a
            # trade: either it has no less-accurate setting worth shipping, or —
            # `spin_taylor_tol` — the accurate value was measured FREE and is now
            # the only one shipped, which is what removing a non-trade looks like.
            @test k.reference != k.default || k.name in (:ddi_padding, :secular_ddi,
                :dtype, :temperature_ratio, :spin_taylor_tol)
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

    @testset "a setting that is less accurate and not faster is NOT a trade" begin
        # The rule: if an approximate setting gives accuracy away without being
        # measurably faster, there is no budget under which anyone should pick it,
        # and it must never be presented as a performance option.
        dom = dominated_knobs()
        @test !isempty(dom)                       # else the mechanism is untested
        for k in dom
            @test isfinite(k.approx_rel_cost) && k.approx_rel_cost >= 0.98
        end
        # `secular_ddi` is the measured case: 0.986× at 32³, i.e. noise, because
        # Q_xx = Q_yy = −Q_zz/2 keeps the kernel a 3-component convolution with
        # all 6 FFTs.
        @test :secular_ddi in (k.name for k in dom)

        # UNMEASURED IS NOT DOMINATED. "Nobody has measured it" and "it buys
        # nothing" are different statements, and conflating them would let this
        # list grow by neglect rather than by measurement.
        for k in ACCURACY_KNOBS
            isfinite(k.approx_rel_cost) && continue
            @test !(k.name in (d.name for d in dom))
        end

        # And the report has to SAY so — a rule nobody is shown is not a rule.
        buf = IOBuffer()
        accuracy_report(; io=buf)
        s2 = String(take!(buf))
        @test occursin("NOT A TRADE", s2)
        @test occursin("secular_ddi", s2)
    end
end
