using Test
# Not used directly. Declared because the suite requires it of every file: a
# parallel worker shares one process, so a file that leans on a neighbour's
# `using` runs only when the claim queue happens to cooperate.
using SpinorBEC

# The loop-width extractor for #335 refuses to report until it has passed a
# synthetic conversion it must see and three curves it must not. That refusal is
# the whole guarantee, so it is gated here rather than left to whoever remembers
# to pass `--selftest`: a calibration that only runs when someone asks for it is
# calibration in the same sense that an unrun test is a test.
#
# Every arm is CANARIED from the property side. Showing that the controls pass at
# the production settings proves nothing on its own — a check that cannot fail is
# the degenerate-knob trap — so each arm is paired with a setting under which the
# same controls MUST fail, and fail for the stated reason.

include(joinpath(@__DIR__, "..", "..", "scripts", "eu_hysteresis", "loop_width.jl"))

@testset "hysteresis conversion depth" begin
    @testset "the controls pass at the production settings" begin
        @test calibrate(; window=DEFAULT_WINDOW, depth_min=DEFAULT_DEPTH,
            verbose=false)
    end

    @testset "canary: a loose threshold must let a non-conversion through" begin
        # 0.2 in ⟨F⊥⟩ is below the small-bump trap's 0.26, so the negative control
        # has to fire. If this does NOT throw, the negative controls are inert and
        # the passing arm above is meaningless.
        e = try
            calibrate(; window=DEFAULT_WINDOW, depth_min=0.2, verbose=false)
        catch err
            err
        end
        @test e isa BlindMetric
        msg = sprint(showerror, e)
        @test occursin("NEGATIVE control", msg)
        @test occursin("small_bump_ratio_trap", msg)
    end

    @testset "canary: too narrow a window must MISS the real conversion" begin
        # The conversion is ~3 µG wide; a 0.05 µG window cannot contain it. The two
        # failure modes are reported separately on purpose — "the extractor cannot
        # see a conversion" and "the threshold admits non-conversions" are
        # different bugs with different fixes.
        e = try
            calibrate(; window=0.05, depth_min=DEFAULT_DEPTH, verbose=false)
        catch err
            err
        end
        @test e isa BlindMetric
        msg = sprint(showerror, e)
        @test occursin("POSITIVE control", msg)
        @test occursin("cannot see a conversion", msg)
    end

    @testset "the direction of the branch change is part of the detector" begin
        # A falling leg converts by RAISING ⟨F⊥⟩ (polarised → flower); a rising leg
        # by lowering it (flower dies). Taking |Δ| instead would let a transient in
        # the wrong direction count, so the same curve must score high with the
        # right expectation and ~zero with the wrong one.
        B = collect(range(200.0, 20.0; length=400))
        f = 0.8 .+ 2.4 .* (1 .+ tanh.((27.0 .- B) ./ 1.5)) ./ 2
        up = conversion(B, f; window=DEFAULT_WINDOW, expect=+1)
        dn = conversion(B, f; window=DEFAULT_WINDOW, expect=-1)
        @test up.depth > DEFAULT_DEPTH
        @test dn.depth < 0.05
        @test 24.0 < up.B_jump < 30.0
        # The plateaus bracket the jump, so an overshoot cannot inflate the depth.
        @test up.level_before < 1.0
        @test up.level_after > 3.0
    end

    @testset "a one-sided arm is a lower bound, never a width" begin
        # This is the predecessor campaign's exact failure: the rising leg never
        # converted, and [≈27, >100] µG was carried as if it were a loop width.
        base = (; kappa=1.8, grid=32, pin=0.002, rate=0.4, tau_ms=400.0,
            level_before=0.0, level_after=0.0, span=0.0, ratio=0.0,
            norm_drift=0.0, Jz_drift=0.0, dir="", label="")
        fall = merge(
            base, (; tag="fall", depth=2.4, converted=true, B_jump=27.0,
                B_from=200.0, B_to=20.0)
        )
        rise_open = merge(
            base, (; tag="rise", depth=0.3, converted=false,
                B_jump=NaN, B_from=20.0, B_to=200.0)
        )
        rise_conv = merge(
            base, (; tag="rise", depth=2.1, converted=true,
                B_jump=118.0, B_from=20.0, B_to=200.0)
        )

        open_ls = loops([fall, rise_open]; depth_min=DEFAULT_DEPTH)
        @test length(open_ls) == 1
        @test isnan(open_ls[1].loop_width)
        @test open_ls[1].is_lower_bound
        @test occursin("rise did not convert", open_ls[1].open_ends)

        closed = loops([fall, rise_conv]; depth_min=DEFAULT_DEPTH)
        @test !closed[1].is_lower_bound
        @test closed[1].loop_width ≈ 91.0

        # A missing leg is also a lower bound — "ran and gave no conversion" and
        # "was never run" must both be refused, though they are different states.
        only_fall = loops([fall]; depth_min=DEFAULT_DEPTH)
        @test only_fall[1].is_lower_bound
        @test occursin("rise leg absent", only_fall[1].open_ends)
    end

    @testset "the verdict comes from the rate scan, not from one ramp" begin
        row(rate, w; bound=false) = (; kappa=1.8, grid=32, pin=0.002, rate,
            tau_ms_rise=1.0, tau_ms_fall=1.0,
            B_jump_rise=NaN, B_jump_fall=NaN,
            depth_rise=bound ? 0.1 : 2.0, depth_fall=bound ? 0.1 : 2.0,
            loop_width=w, is_lower_bound=bound, open_ends="")

        # Saturated: ≤10 % change between the two slowest rates.
        v = verdict([row(4.0, 120.0), row(1.2, 92.0), row(0.4, 90.0)])
        @test v.verdict == "bistable"
        @test v.width ≈ 90.0
        @test occursin("spinodal separation", v.reason)

        # Still shrinking as the ramp slows ⇒ the ramp was too fast, not bistable.
        v = verdict([row(4.0, 120.0), row(1.2, 60.0), row(0.4, 20.0)])
        @test v.verdict == "dynamical_lag"
        @test occursin("still falling", v.reason)

        # Nothing converted at any rate ⇒ crossover. This is the κ ≤ 0.9 control's
        # expected verdict, and it must be distinguishable from "one leg open".
        v = verdict([row(4.0, NaN; bound=true), row(0.4, NaN; bound=true)])
        @test v.verdict == "crossover"
        @test occursin("no leg converted", v.reason)

        # One leg converting and the other not, at every rate, is NOT a crossover:
        # it is the open end, and it has to block the verdict rather than be read
        # as an absence of hysteresis.
        half = merge(row(0.4, NaN; bound=true), (; depth_fall=2.4))
        v = verdict([half, merge(row(4.0, NaN; bound=true), (; depth_fall=2.4))])
        @test v.verdict == "indeterminate"
        @test occursin("open end", v.reason)

        # A single closed rate cannot establish saturation.
        v = verdict([row(0.4, 90.0)])
        @test v.verdict == "indeterminate"
        @test occursin("at least two", v.reason)
    end

    @testset "a missing manifest is refused, not read as no loop" begin
        # "The ramp did not run" and "the ramp ran and found no loop" print the
        # same number if absence is allowed to mean zero.
        d = mktempdir()
        @test_throws BlindMetric analyse_dir(d; window=DEFAULT_WINDOW,
            depth_min=DEFAULT_DEPTH)
    end
end
