# Trap drift correction smoke test (Phase 4/5 #68).

using Test
using Dates
using SpinorBEC

@testset "Trap drift correction" begin
    # Two-point calibration history: trap stiffness ramps in time.
    cs1 = CalibrationSet(;
        epoch="2026-01-01",
        fort=FORTCalibration((450.0, 450.0, 600.0), (0.0, 0.0, 0.0)),
    )
    cs2 = CalibrationSet(;
        epoch="2026-02-01",
        fort=FORTCalibration((440.0, 440.0, 590.0), (0.0, 0.0, 0.0)),  # slight drop
    )
    history = CalibrationHistory([Date("2026-01-01"), Date("2026-02-01")], [cs1, cs2])

    @testset "sample_trap_drift_omegas: linear interpolation" begin
        dates = [Date("2026-01-01"), Date("2026-01-15"), Date("2026-02-01")]
        omegas = sample_trap_drift_omegas(history, dates, 1.0)
        @test size(omegas) == (3, 3)
        # At date 0: ω_z = 600 * sqrt(1) = 600 Hz
        @test isapprox(omegas[1, 3], 600.0; atol=1e-9)
        # At date end: ω_z = 590 * sqrt(1) = 590 Hz
        @test isapprox(omegas[3, 3], 590.0; atol=1e-9)
        # Midpoint: linear interpolation → 595 Hz
        @test isapprox(omegas[2, 3], 595.0; atol=1.0)
    end

    @testset "trap_drift_waveforms: per-axis Waveform construction" begin
        wfs = trap_drift_waveforms(
            history,
            (1, 2, 3);
            start_date=Date("2026-01-01"),
            sim_seconds_per_unit=86400.0 * 30,  # 1 sim time unit = 30 days
            sim_duration=1.0,                       # full 30-day span
            fort_mw_per_axis=1.0,
            n_samples=4,
        )
        @test length(wfs) == 3
        # Each waveform spans the full sim duration
        for wf in wfs
            @test length(wf.times) == 4
            @test wf.times[1] ≈ 0.0
            @test wf.times[end] ≈ 1.0
        end
        # Z-axis waveform: starts at 600 Hz, ends at 590 Hz (linear drift).
        wf_z = wfs[3]
        @test isapprox(wf_z.values[1], 600.0; atol=1e-6)
        @test isapprox(wf_z.values[end], 590.0; atol=1.0)
    end

    @testset "apply_trap_drift: drops into TimeDependentTrap" begin
        base = HarmonicTrap((1.0, 1.0, 1.0))
        td_trap = apply_trap_drift(
            base,
            history,
            (1, 2, 3);
            start_date=Date("2026-01-01"),
            sim_seconds_per_unit=86400.0,
            sim_duration=10.0,
            fort_mw_per_axis=1.0,
            n_samples=4,
        )
        @test td_trap isa SpinorBEC.TimeDependentTrap
        @test length(td_trap.omega_wf) == 3
    end
end
