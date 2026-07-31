# `_parse_dimless_freq` Hz convention regression (Klaus 2022 magnetostir footgun).
#
# CLAUDE.md / memory `gotcha_waveform_frequency_convention.md`:
# YAML `phi_omega: "226 Hz"` must convert to `(2π · f) / ω_ref`, NOT `f / ω_ref`.
# The missing 2π was a Klaus 2022 magnetostir bug — the spinor solver received
# a quasi-DC field and produced no orbital response. This test pins the
# correct conversion so a future refactor of the units block cannot reintroduce
# the 2π drop silently.

using Test
using SpinorBEC
using SpinorBEC: _parse_dimless_freq

@testset "phi_omega Hz convention (Klaus 2022 magnetostir 2π footgun)" begin
    @testset "Real input passes through unchanged" begin
        # When the user writes `phi_omega: 4.524`, that's already the
        # dimensionless ratio ω / ω_ref — no conversion applied.
        @test _parse_dimless_freq(4.524, 2π * 50.0) ≈ 4.524
        @test _parse_dimless_freq(0.0, 1.0) ≈ 0.0
        @test _parse_dimless_freq(-3.14, 1.0) ≈ -3.14  # signed accepted (phase reversal)
    end

    @testset "Hz string converts via (2π · f) / ω_ref" begin
        # The defining test. ω_ref = 2π · 50 rad/s (= 50 Hz reference).
        # "226 Hz" → (2π · 226) / (2π · 50) = 226 / 50 = 4.52
        ω_ref = 2π * 50.0
        @test _parse_dimless_freq("226 Hz", ω_ref) ≈ 226.0 / 50.0 rtol = 1e-12

        # "100 Hz" at ω_ref = 2π · 100 → exactly 1.0
        @test _parse_dimless_freq("100 Hz", 2π * 100.0) ≈ 1.0 rtol = 1e-12

        # If the 2π were dropped (the historical bug), the result would
        # be 226 / (2π · 50) ≈ 0.719 — over 6× smaller. Catch via tight
        # comparison to the WITHOUT-2π wrong value: must differ by >5×.
        wrong_no_2pi = 226.0 / (2π * 50.0)
        actual = _parse_dimless_freq("226 Hz", ω_ref)
        @test actual / wrong_no_2pi > 5.0
    end

    @testset "rad/s string is already angular — no extra 2π factor" begin
        # `_parse_dimless_freq("1000 rad/s", ω_ref)` should give 1000/ω_ref
        # directly, NOT (2π · 1000) / ω_ref.
        ω_ref = 100.0  # rad/s
        @test _parse_dimless_freq("1000 rad/s", ω_ref) ≈ 10.0 rtol = 1e-12
    end

    @testset "kHz string scales by 1000" begin
        ω_ref = 2π * 1000.0
        @test _parse_dimless_freq("1 kHz", ω_ref) ≈ 1.0 rtol = 1e-12
        @test _parse_dimless_freq("5 kHz", ω_ref) ≈ 5.0 rtol = 1e-12
    end

    @testset "validates omega_ref > 0" begin
        @test_throws ArgumentError _parse_dimless_freq("100 Hz", 0.0)
        @test_throws ArgumentError _parse_dimless_freq("100 Hz", -1.0)
    end

    @testset "rejects non-Real / non-string input" begin
        @test_throws ArgumentError _parse_dimless_freq([100.0], 1.0)
        @test_throws ArgumentError _parse_dimless_freq(nothing, 1.0)
    end
end
