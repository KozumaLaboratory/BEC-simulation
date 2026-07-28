using Test
using SpinorBEC
using SpinorBEC: FieldNoiseSpec, field_noise_waveform, SpectralNoiseWaveform,
    evaluate, noise_rms, CompositeWaveform, ConstantWaveform, Waveform,
    _make_waveform

@testset "Field noise waveform" begin
    @testset "purity: evaluate(t) is a function of t alone" begin
        # The property the whole design exists for. A waveform is hit several
        # times per step (Strang sub-steps, rejected adaptive-dt trials), so
        # two looks at the same instant must agree exactly — bitwise.
        w = field_noise_waveform(
            FieldNoiseSpec(; seed=3, shape=:white, rms=1e-5, f_lo=1.0, f_hi=50.0,
                n_components=64), 10.0)
        for t in (0.0, 0.37, 1.0, 9.99)
            @test evaluate(w, t) === evaluate(w, t)
        end
        # …and out-of-order evaluation must not change anything.
        forward = [evaluate(w, t) for t in 0.0:0.5:5.0]
        backward = reverse([evaluate(w, t) for t in reverse(0.0:0.5:5.0)])
        @test forward == backward
    end

    @testset "seed determinism and independence" begin
        mk(seed) = field_noise_waveform(
            FieldNoiseSpec(; seed, shape=:white, rms=1e-5, f_lo=1.0, f_hi=50.0,
                n_components=64), 10.0)
        a1, a2, b = mk(11), mk(11), mk(12)
        ts = 0.0:0.13:9.0
        @test [evaluate(a1, t) for t in ts] == [evaluate(a2, t) for t in ts]
        @test [evaluate(a1, t) for t in ts] != [evaluate(b, t) for t in ts]
        # Same spec, different seed ⇒ same rms by construction: an ensemble
        # varies the realisation, not the noise budget.
        @test noise_rms(a1) ≈ noise_rms(b) rtol = 1e-12
    end

    @testset "rms is delivered as specified" begin
        for shape in (:white, :pink, :brown, :lorentzian)
            w = field_noise_waveform(
                FieldNoiseSpec(; seed=5, shape, rms=2.5e-5, f_lo=1.0, f_hi=200.0,
                    f_corner=10.0, n_components=512), 20.0)
            @test noise_rms(w) ≈ 2.5e-5 rtol = 1e-12
            # Empirical rms over a long window matches the design value.
            ts = range(0.0, 20.0; length=20001)
            emp = sqrt(sum(t -> evaluate(w, t)^2, ts) / length(ts))
            @test emp ≈ 2.5e-5 rtol = 0.05
        end
    end

    @testset "spectral lines land at their frequency and amplitude" begin
        f0, r0 = 3.0, 1.0e-3
        w = field_noise_waveform(
            FieldNoiseSpec(; seed=1, lines=[(f0, r0)]), 10.0)
        @test length(w.frequencies) == 1
        @test w.frequencies[1] == f0
        @test w.amplitudes[1] ≈ sqrt(2) * r0        # rms of A·sin is A/√2
        @test noise_rms(w) ≈ r0
        # Peak excursion is √2 × rms, as an experimentalist quoting
        # peak-to-peak would expect.
        ts = range(0.0, 10.0; length=100001)
        @test maximum(t -> abs(evaluate(w, t)), ts) ≈ sqrt(2) * r0 rtol = 1e-3
    end

    @testset "mains line + harmonics compose additively" begin
        w = field_noise_waveform(
            FieldNoiseSpec(; seed=2,
                lines=[(50.0, 1.0e-5), (150.0, 3.0e-6), (250.0, 1.0e-6)]), 1.0)
        @test length(w.frequencies) == 3
        @test noise_rms(w) ≈ sqrt(1.0e-5^2 + 3.0e-6^2 + 1.0e-6^2)
    end

    @testset "empty spec is a silent zero" begin
        w = field_noise_waveform(FieldNoiseSpec(; seed=0), 1.0)
        @test isempty(w.frequencies)
        @test evaluate(w, 0.7) == 0.0
    end

    @testset "rejected specs" begin
        @test_throws ArgumentError FieldNoiseSpec(; shape=:violet, rms=1.0,
            f_lo=1.0, f_hi=2.0)
        @test_throws ArgumentError FieldNoiseSpec(; shape=:white, rms=1.0,
            f_lo=10.0, f_hi=1.0)
        # 1/f and 1/f² diverge at DC — refuse rather than silently clamp.
        @test_throws ArgumentError FieldNoiseSpec(; shape=:pink, rms=1.0,
            f_lo=0.0, f_hi=100.0, f_corner=0.0)
        @test_throws ArgumentError field_noise_waveform(
            FieldNoiseSpec(; seed=1, lines=[(1.0, 1.0)]), 0.0)
    end

    @testset "YAML: noise rides on a ramp via `sum`" begin
        ramp = Dict("from" => 6.0e-5, "to" => 3.0e-5)
        noisy = Dict(
            "sum" => [
                ramp,
                Dict(
                    "noise" => Dict(
                        "seed" => 7,
                        "lines" => [Dict("frequency" => 50.0, "rms" => 1.0e-5)],
                        "broadband" => Dict("shape" => "pink", "rms" => 5.0e-6,
                            "f_lo" => 1.0, "f_hi" => 100.0, "f_corner" => 5.0),
                        "n_components" => 64,
                    ),
                ),
            ],
        )
        w_clean = _make_waveform(ramp, 10.0)
        w_noisy = _make_waveform(noisy, 10.0)
        @test w_noisy isa CompositeWaveform
        # The ramp is preserved exactly; noise is the difference. Sample
        # well above the highest component (50 here) — the waveform is
        # analytic, but any grid that undersamples it aliases, which is the
        # same reason the integrator's dt has to resolve the noise band.
        ts = 0.0:0.0005:10.0
        resid = [evaluate(w_noisy, t) - evaluate(w_clean, t) for t in ts]
        @test sqrt(sum(abs2, resid) / length(resid)) ≈
            sqrt(1.0e-5^2 + 5.0e-6^2) rtol = 0.05
    end

    @testset "YAML: unknown noise keys are rejected, not ignored" begin
        @test_throws ArgumentError _make_waveform(
            Dict("noise" => Dict("sedd" => 7)), 1.0)
        @test_throws ArgumentError _make_waveform(
            Dict("noise" => Dict("lines" => [Dict("freq" => 50.0)])), 1.0)
        @test_throws ArgumentError _make_waveform(Dict("sum" => []), 1.0)
    end

    @testset "YAML: Hz strings convert with the sinusoidal convention" begin
        # frequency = f_phys[Hz] / ω_ref[rad/s]; ω_ref = 2π·50 ⇒ 50 Hz → 0.159…
        omega_ref = 2π * 50
        w = _make_waveform(
            Dict("noise" => Dict("lines" => [
                Dict("frequency" => "50 Hz", "rms" => 1.0e-5)])),
            1.0; omega_ref)
        @test w.frequencies[1] ≈ 50 / omega_ref rtol = 1e-12
    end
end
