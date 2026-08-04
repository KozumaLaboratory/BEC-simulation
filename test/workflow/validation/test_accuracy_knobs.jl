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
    SPIN_TAYLOR_ENABLED, DEALIAS_2_3_ENABLED,
    yaml_to_model, model_toml_dict, content_id

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

    # [KNOWN-GAP], pinned so that fixing it is a visible diff rather than a
    # silent improvement. `with_reference_accuracy` is the instrument for "re-run
    # this with every approximation at its most accurate setting", and around
    # `run_yaml` it can produce exactly the degeneracy it exists to detect: the
    # reference run resolves to the SAME `artifact_id` as production and can be
    # served the production artifact.
    #
    # Two independent causes, both measured. `:spin_taylor` is in no `Stage`
    # (see test/model/test_ambient_refs_vs_artifact_id.jl). `:dealias_2_3` IS in
    # the id via `GridSpec`, but `_run_yaml_prepare` applies the config's own
    # top-level `dealias:` block AFTER the reference flip, overwriting it — and
    # 75 committed configs carry that block.
    #
    # The POSITIVE CONTROL is the whole assertion: the same config without the
    # block DOES move the id, so the null below is about the clobber and not
    # about a harness that never moves anything.
    @testset "[KNOWN-GAP] a config's dealias block clobbers the reference flip" begin
        base = """
        defaults: {kind: spinor, backend: cpu}
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [16], box: [8.0]}
              potential: {type: harmonic, omega: [1.0]}
              interactions: {N_atoms: 100, omega_ref: 100.0, c0: 1.0, c1: 0.0}
              ddi: {enabled: false}
              lhy: {kind: none}
              initial_state: polar
              method: itp
              n_steps: 5
              dt: 1.0e-3
              tol: 1.0e-6
        """
        mid(p) = content_id(model_toml_dict(yaml_to_model(p)); n=16)
        mktempdir() do d
            plain = joinpath(d, "plain.yaml")
            blocked = joinpath(d, "blocked.yaml")
            write(plain, base)
            write(blocked, "dealias: {enabled: false}\n" * base)

            # Control: with nothing clobbering it, the reference flip MOVES the id.
            @test mid(plain) != with_reference_accuracy(() -> mid(plain))
            # The gap: one extra line, and it stops moving.
            @test mid(blocked) == with_reference_accuracy(() -> mid(blocked))
            # ... and the two configs describe the same physics otherwise, so the
            # difference above is the clobber and nothing else.
            @test mid(plain) == mid(blocked)
        end
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
