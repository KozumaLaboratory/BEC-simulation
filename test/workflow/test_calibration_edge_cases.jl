# Calibration parsing edge cases — pin user-input validation guards
# that production lab-units configs depend on. Each probe designed so
# that a regression flips the validation from throwing/clamping to
# silently passing garbage.

using Test
using Dates
using SpinorBEC
using SpinorBEC: _calibration_from_dict, load_calibration_history,
    interpolate_calibration

@testset "Calibration edge cases" begin
    @testset "CalibrationHistory constructor invariants" begin
        cs = CalibrationSet()

        # Mismatched dates/entries lengths.
        @test_throws ArgumentError CalibrationHistory(
            [Date("2026-01-01"), Date("2026-02-01")], [cs])

        # Empty history.
        @test_throws ArgumentError CalibrationHistory(Date[], CalibrationSet[])

        # Unsorted dates (descending).
        @test_throws ArgumentError CalibrationHistory(
            [Date("2026-02-01"), Date("2026-01-01")], [cs, cs])

        # Singleton is valid (one calibration epoch).
        h = CalibrationHistory([Date("2026-01-01")], [cs])
        @test length(h.dates) == 1
    end

    @testset "_parse_fort rejects wrong-length sqrt_coeffs_hz" begin
        # 4-element instead of 3-element.
        bad_yaml = Dict{String, Any}(
            "fort" => Dict{String, Any}(
                "sqrt_coeffs_hz" => [450.0, 450.0, 600.0, 700.0]
            ),
        )
        @test_throws ArgumentError _calibration_from_dict(bad_yaml)

        # 2-element (too short).
        bad_yaml2 = Dict{String, Any}(
            "fort" => Dict{String, Any}(
                "sqrt_coeffs_hz" => [450.0, 600.0]
            ),
        )
        @test_throws ArgumentError _calibration_from_dict(bad_yaml2)

        # offsets_hz wrong length but sqrt_coeffs_hz fine.
        bad_yaml3 = Dict{String, Any}(
            "fort" => Dict{String, Any}(
                "sqrt_coeffs_hz" => [450.0, 450.0, 600.0],
                "offsets_hz" => [0.0, 0.0],
            ),
        )
        @test_throws ArgumentError _calibration_from_dict(bad_yaml3)
    end

    @testset "interpolate_calibration clamps at extremes (no extrapolation)" begin
        cs1 = CalibrationSet(;
            epoch="early",
            fort=FORTCalibration((450.0, 450.0, 600.0), (0.0, 0.0, 0.0)),
        )
        cs2 = CalibrationSet(;
            epoch="late",
            fort=FORTCalibration((400.0, 400.0, 550.0), (0.0, 0.0, 0.0)),
        )
        history = CalibrationHistory(
            [Date("2026-01-01"), Date("2026-02-01")], [cs1, cs2])

        # Before first date: clamp to first entry's values.
        before = interpolate_calibration(history, Date("2025-12-15"))
        @test before.fort.sqrt_coeffs_hz == cs1.fort.sqrt_coeffs_hz

        # After last date: clamp to last entry's values.
        after = interpolate_calibration(history, Date("2026-03-15"))
        @test after.fort.sqrt_coeffs_hz == cs2.fort.sqrt_coeffs_hz

        # Exact endpoints: clamp branch (≤ / ≥) — should still return endpoint
        # values, not interpolated. Linear interp at a=0 or a=1 would give the
        # same answer mathematically, but the clamp branch is the documented
        # path.
        at_start = interpolate_calibration(history, Date("2026-01-01"))
        @test at_start.fort.sqrt_coeffs_hz == cs1.fort.sqrt_coeffs_hz
        @test occursin("clamped", at_start.epoch)

        # Midpoint (15 days into 31-day span): a ≈ 14/31, linear interp.
        mid = interpolate_calibration(history, Date("2026-01-15"))
        a = 14.0 / 31.0
        @test isapprox(mid.fort.sqrt_coeffs_hz[1], (1 - a) * 450.0 + a * 400.0;
            atol=1e-9)
        @test isapprox(mid.fort.sqrt_coeffs_hz[3], (1 - a) * 600.0 + a * 550.0;
            atol=1e-9)
        @test occursin("interp", mid.epoch)
    end

    @testset "load_calibration_history rejects malformed YAML" begin
        # Non-list root.
        mktempdir() do tmp
            path = joinpath(tmp, "bad.yaml")
            write(
                path,
                """
    calibration_history:
      not: a_list
    """,
            )
            @test_throws ArgumentError load_calibration_history(path)
        end

        # Entry missing `date` key.
        mktempdir() do tmp
            path = joinpath(tmp, "missing_date.yaml")
            write(
                path,
                """
    calibration_history:
      - epoch: "no_date_entry"
        coil_strong:
          gauss_per_mv: 0.4
    """,
            )
            @test_throws ArgumentError load_calibration_history(path)
        end

        # Entry not a Dict (raw scalar in list).
        mktempdir() do tmp
            path = joinpath(tmp, "scalar.yaml")
            write(
                path,
                """
    calibration_history:
      - 42
    """,
            )
            @test_throws ArgumentError load_calibration_history(path)
        end
    end

    @testset "load_calibration_history sorts dates ascending" begin
        # Input dates out of order — loader sorts.
        mktempdir() do tmp
            path = joinpath(tmp, "unsorted.yaml")
            write(
                path,
                """
    calibration_history:
      - date: "2026-02-01"
        coil_strong: {gauss_per_mv: 0.5}
      - date: "2026-01-01"
        coil_strong: {gauss_per_mv: 0.3}
    """,
            )
            hist = load_calibration_history(path)
            @test hist.dates[1] == Date("2026-01-01")
            @test hist.dates[2] == Date("2026-02-01")
            @test hist.entries[1].coil_strong.gauss_per_mv ≈ 0.3
            @test hist.entries[2].coil_strong.gauss_per_mv ≈ 0.5
        end
    end
end
