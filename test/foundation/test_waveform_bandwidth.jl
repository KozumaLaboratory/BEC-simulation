# Gate: a waveform that gets RESAMPLED onto a fixed grid must survive it.
#
# `_convert_B_waveform` and `_shift_waveform` both replace the waveform the
# user wrote with a `PiecewiseLinearWaveform` sampled at `n_samples`. The
# sample count used to come from pattern-matching the raw YAML dict and knew
# only `sinusoidal` / `chirped_sinusoidal`; every other time-dependent form —
# `noise:`, `sum:`, a pre-built `Waveform`, a fine `piecewise:` — silently got
# the 1024-point default and was aliased. `max_frequency` + `resample_count`
# replace that with a rule driven by the waveform's actual content.

using Test
using SpinorBEC
using SpinorBEC: max_frequency, resample_count, evaluate, noise_rms,
    ConstantWaveform, RampWaveform, SinusoidalWaveform, ChirpedSinusoidalWaveform,
    GaussianPulseWaveform, PiecewiseLinearWaveform, InterpolatedWaveform,
    CompositeWaveform, StepWaveform, FunctionWaveform, ShiftedWaveform, Waveform,
    FieldNoiseSpec, field_noise_waveform, _make_waveform, _convert_B_waveform,
    _suggest_sample_count, _ZEEMAN_SAMPLE_N

@testset "Waveform bandwidth + anti-aliased resampling" begin
    @testset "max_frequency per waveform type" begin
        @test max_frequency(ConstantWaveform(3.0)) == 0.0
        @test max_frequency(RampWaveform(0.0, 1.0, 2.0, :linear)) == 0.0
        @test max_frequency(SinusoidalWaveform(; frequency=7.5)) == 7.5
        @test max_frequency(SinusoidalWaveform(; frequency=-7.5)) == 7.5
        @test max_frequency(ChirpedSinusoidalWaveform(; freq_start=2.0, freq_end=9.0)) == 9.0
        @test max_frequency(GaussianPulseWaveform(; sigma=0.02)) == 50.0
        @test max_frequency(ShiftedWaveform(SinusoidalWaveform(; frequency=4.0), 1.0)) == 4.0
        # A sampled waveform carries nothing above its own grid Nyquist.
        pw = PiecewiseLinearWaveform(collect(0.0:0.01:1.0), zeros(101))
        @test max_frequency(pw) ≈ 50.0
        @test max_frequency(InterpolatedWaveform(collect(0.0:0.01:1.0), zeros(101))) ≈ 50.0
        # Unbounded / opaque → NaN, not 0: "cannot bound", not "no content".
        @test isnan(max_frequency(StepWaveform(0.0, 1.0, 0.5)))
        @test isnan(max_frequency(FunctionWaveform(sin)))
    end

    @testset "max_frequency composes over sums" begin
        c = CompositeWaveform(
            Waveform[SinusoidalWaveform(; frequency=3.0),
                RampWaveform(0.0, 1.0, 1.0, :linear),
                SinusoidalWaveform(; frequency=11.0)],
        )
        @test max_frequency(c) == 11.0
        # One unbounded member poisons the whole sum — the aggregate cannot be
        # bounded either, and silently reporting 11.0 would be worse.
        c2 = CompositeWaveform(
            Waveform[SinusoidalWaveform(; frequency=3.0),
                StepWaveform(0.0, 1.0, 0.5)],
        )
        @test isnan(max_frequency(c2))
        @test max_frequency(CompositeWaveform(Waveform[])) == 0.0
    end

    @testset "max_frequency of a noise realisation is its top tone" begin
        w = field_noise_waveform(
            FieldNoiseSpec(; seed=1, lines=[(50.0, 1e-5), (250.0, 1e-6)],
                shape=:white, rms=1e-6, f_lo=1.0, f_hi=180.0, n_components=32),
            1.0)
        @test max_frequency(w) == 250.0
        @test max_frequency(field_noise_waveform(FieldNoiseSpec(), 1.0)) == 0.0
    end

    @testset "resample_count: 20 per cycle, floored" begin
        @test resample_count(ConstantWaveform(1.0), 10.0) == 1024      # floor
        @test resample_count(SinusoidalWaveform(; frequency=500.0), 0.2) ==
            ceil(Int, 20 * 500 * 0.2)
        @test resample_count(SinusoidalWaveform(; frequency=0.1), 1.0) == 1024
        @test resample_count(StepWaveform(0.0, 1.0, 0.5), 1.0) == 1024  # NaN → floor
        @test resample_count(SinusoidalWaveform(; frequency=100.0), 1.0;
            floor_n=16) == 2000
        @test resample_count(SinusoidalWaveform(; frequency=100.0), 0.0) == 1024
    end

    @testset "B-block sample count follows the spec content" begin
        dur = 40.0
        noisy = Dict(
            "sum" => [
                Dict("from" => 6.0e-5, "to" => 3.0e-5),
                Dict(
                    "noise" => Dict("seed" => 5,
                        "lines" => [Dict("frequency" => 12.0, "rms" => 1.0e-5)]),
                ),
            ],
        )
        # 12 * 40 * 20 = 9600 ≫ the 1024 default the old rule would have used.
        @test _suggest_sample_count(noisy, dur) == 9600
        @test _suggest_sample_count(noisy, dur) > _ZEEMAN_SAMPLE_N
        # Plain specs are untouched.
        @test _suggest_sample_count(Dict("from" => 1.0, "to" => 2.0), dur) ==
            _ZEEMAN_SAMPLE_N
        @test _suggest_sample_count(3.0, dur) == _ZEEMAN_SAMPLE_N
        # A malformed spec must not make the heuristic throw — the real build
        # downstream is what reports it.
        @test _suggest_sample_count(Dict("nonsense" => 1), dur) == _ZEEMAN_SAMPLE_N
        # An already-built Waveform is accepted directly (the `_shift_waveform`
        # path), which the dict-matching version could not do at all.
        @test _suggest_sample_count(SinusoidalWaveform(; frequency=12.0), dur) == 9600
    end

    @testset "resampling preserves the noise amplitude it is given" begin
        # The end-to-end property: what the propagator sees through the B block
        # must still carry the rms that was specified. At the old fixed 1024
        # points this understates it.
        dur, g_F, omega_ref = 40.0, 1.163, 2π * 50
        rms_G = 1.0e-5
        spec = Dict(
            "noise" => Dict("seed" => 9,
                "lines" => [Dict("frequency" => 12.0, "rms" => rms_G)]),
        )
        factor = abs(evaluate(_convert_B_waveform(1.0, dur, g_F, omega_ref), 0.0))

        good = _convert_B_waveform(spec, dur, g_F, omega_ref;
            n_samples=_suggest_sample_count(spec, dur))
        poor = _convert_B_waveform(spec, dur, g_F, omega_ref; n_samples=_ZEEMAN_SAMPLE_N)

        ts = range(0.0, dur; length=200_001)
        rms_of(w) = sqrt(sum(t -> evaluate(w, t)^2, ts) / length(ts)) / factor

        @test rms_of(good) ≈ rms_G rtol = 0.02
        @test rms_of(poor) < 0.9 * rms_G          # the aliasing this gate exists for
    end
end
