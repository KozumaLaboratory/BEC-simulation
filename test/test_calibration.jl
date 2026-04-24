using Test
using SpinorBEC
using SpinorBEC: _parse_bfield, Units
using YAML

@testset "Calibration layer (Phase 5.3)" begin

    @testset "unit conversions" begin
        coil = CoilCalibration(0.4, 0.05, (-100.0, 100.0))
        @test coil_mv_to_gauss(0.0, coil) ≈ 0.05
        @test coil_mv_to_gauss(2.5, coil) ≈ 1.05
        @test coil_mv_to_gauss(-10.0, coil) ≈ -3.95

        fort = FORTCalibration((450.0, 450.0, 600.0), (0.0, 0.0, 0.0))
        @test fort_mw_to_trap_hz(0.0, 1, fort) ≈ 0.0
        @test fort_mw_to_trap_hz(4.0, 1, fort) ≈ 900.0    # 450 * sqrt(4)
        @test fort_mw_to_trap_hz(1.0, 3, fort) ≈ 600.0

        mw = RabiCalibration(1.2e6)
        @test rabi_mw_to_rad_s(0.0, mw) ≈ 0.0
        @test rabi_mw_to_rad_s(2.5, mw) ≈ 3.0e6
    end

    @testset "apply_calibration! rewrites zeeman p_mv" begin
        calib = CalibrationSet(
            coil_strong = CoilCalibration(0.4, 0.05, (-Inf, Inf)),
            coil_weak   = CoilCalibration(0.04, 0.002, (-Inf, Inf)),
        )
        cfg = Dict{String,Any}(
            "pipeline" => Any[
                Dict{String,Any}("ground_state" => Dict{String,Any}(
                    "zeeman" => Dict{String,Any}("p_mv" => 2.5, "coil_mode" => "strong"),
                )),
            ],
        )
        apply_calibration!(cfg, calib)
        z = cfg["pipeline"][1]["ground_state"]["zeeman"]
        @test !haskey(z, "p_mv")
        @test haskey(z, "p")
        @test z["p"] isa AbstractString
        @test occursin("Gauss", z["p"])
        # 2.5 * 0.4 + 0.05 = 1.05 G
        parsed = Units.safe_parse_quantity(z["p"])
        @test abs(Float64(Units.ustrip(Units.u"Gauss", parsed)) - 1.05) < 1e-10
    end

    @testset "apply_calibration! weak-mode coil" begin
        calib = CalibrationSet(
            coil_strong = CoilCalibration(0.4, 0.0, (-Inf, Inf)),
            coil_weak   = CoilCalibration(0.04, 0.0, (-Inf, Inf)),
        )
        cfg = Dict{String,Any}(
            "zeeman" => Dict{String,Any}("p_mv" => 10.0, "coil_mode" => "weak"),
        )
        apply_calibration!(cfg, calib)
        # 10 * 0.04 = 0.4 G (weak mode picked)
        parsed = Units.safe_parse_quantity(cfg["zeeman"]["p"])
        @test abs(Float64(Units.ustrip(Units.u"Gauss", parsed)) - 0.4) < 1e-10
    end

    @testset "apply_calibration! rewrites trap fort_power_mw" begin
        calib = CalibrationSet(
            fort = FORTCalibration((500.0, 500.0, 700.0), (0.0, 0.0, 0.0)),
        )
        cfg = Dict{String,Any}(
            "potential" => Dict{String,Any}(
                "type" => "harmonic",
                "fort_power_mw" => [4.0, 4.0, 1.0],
            ),
        )
        apply_calibration!(cfg, calib)
        p = cfg["potential"]
        @test !haskey(p, "fort_power_mw")
        @test haskey(p, "omega")
        @test length(p["omega"]) == 3
        # 500*sqrt(4) = 1000 Hz
        q1 = Units.safe_parse_quantity(p["omega"][1])
        @test abs(Float64(Units.ustrip(Units.u"Hz", q1)) - 1000.0) < 1e-8
        # axis 3: 700*sqrt(1) = 700 Hz
        q3 = Units.safe_parse_quantity(p["omega"][3])
        @test abs(Float64(Units.ustrip(Units.u"Hz", q3)) - 700.0) < 1e-8
    end

    @testset "apply_calibration! raman power_mw gated on detuning" begin
        calib = CalibrationSet(microwave = RabiCalibration(1.0e6))
        # Raman: gated because detuning is present
        cfg_r = Dict{String,Any}("raman" => Dict{String,Any}(
            "power_mw" => 2.0, "detuning" => 0.5,
        ))
        apply_calibration!(cfg_r, calib)
        @test haskey(cfg_r["raman"], "Omega")
        @test !haskey(cfg_r["raman"], "power_mw")
        q = Units.safe_parse_quantity(cfg_r["raman"]["Omega"])
        @test abs(Float64(Units.ustrip(Units.u"rad/s", q)) - 2.0e6) < 1e-6

        # Unrelated dict with power_mw but no detuning: untouched
        cfg_other = Dict{String,Any}("misc" => Dict{String,Any}("power_mw" => 5.0))
        apply_calibration!(cfg_other, calib)
        @test haskey(cfg_other["misc"], "power_mw")
        @test !haskey(cfg_other["misc"], "Omega")
    end

    @testset "load_calibration from YAML" begin
        mktempdir() do tmp
            path = joinpath(tmp, "calib.yaml")
            write(path, """
            calibration:
              epoch: "lab_2026_04"
              date: "2026-04-20"
              coil_strong:
                gauss_per_mv: 0.4
                gauss_offset: 0.05
                valid_range_mv:
                  min: -1000.0
                  max: 1000.0
              coil_weak:
                gauss_per_mv: 0.04
                gauss_offset: 0.0
              fort:
                sqrt_coeffs_hz: [450.0, 450.0, 600.0]
                offsets_hz: [0.0, 0.0, 0.0]
              microwave:
                rad_per_s_per_mw: 1.5e6
            """)
            calib = load_calibration(path)
            @test calib.epoch == "lab_2026_04"
            @test calib.date == "2026-04-20"
            @test calib.coil_strong.gauss_per_mv ≈ 0.4
            @test calib.coil_strong.gauss_offset ≈ 0.05
            @test calib.coil_strong.valid_range_mv == (-1000.0, 1000.0)
            @test calib.coil_weak.gauss_per_mv ≈ 0.04
            @test calib.fort.sqrt_coeffs_hz == (450.0, 450.0, 600.0)
            @test calib.microwave.rad_per_s_per_mw ≈ 1.5e6
        end
    end

    @testset "invalid coil_mode raises" begin
        cfg = Dict{String,Any}("zeeman" => Dict{String,Any}(
            "p_mv" => 1.0, "coil_mode" => "bogus",
        ))
        @test_throws ArgumentError apply_calibration!(cfg, DEFAULT_CALIBRATION)
    end

    @testset "range-warning on out-of-range mv" begin
        calib = CalibrationSet(
            coil_strong = CoilCalibration(0.4, 0.0, (-10.0, 10.0)),
        )
        cfg = Dict{String,Any}("zeeman" => Dict{String,Any}(
            "p_mv" => 50.0, "coil_mode" => "strong",
        ))
        # Warns but doesn't throw
        @test_logs (:warn, r"outside validated range") apply_calibration!(cfg, calib)
    end
end
