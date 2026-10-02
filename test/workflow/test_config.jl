using Test
using SpinorBEC

@testset "Unified Config" begin
    @testset "parsing - ground_state type" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0],
                "n" => [32],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-8,
        ),
    )],
)
"""
        cfg = load_config_from_string(yaml)
        @test cfg isa PipelineConfig

        @test length(cfg.steps) == 1
        p = cfg.steps[1].params
        @test p["atom"] == "Rb87"
        @test p["grid"]["n"] == [32]
        @test p["interactions"]["c0"] == 10.0
        @test p["dt"] == 0.005
        @test p["n_steps"] == 100
        @test p["B"]["q"] == 0.1
    end

    @testset "parsing - dynamics type" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0],
                "n" => [32],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-8,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => Dict{String, Any}(
                    "from" => 0.1,
                    "to" => -0.5,
                ),
            ),
            "dt" => 0.01,
            "duration" => 0.1,
            "noise_seed" => 42,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "save" => Dict{String, Any}(
                "every" => 5,
            ),
            "temperature_ratio" => 0.1,
        ),
    )],
)
"""
        cfg = load_config_from_string(yaml)
        @test cfg isa PipelineConfig
        @test length(cfg.steps) == 2
        @test cfg.steps[1] isa SpinorBEC.GroundStateStep
        @test cfg.steps[2] isa SpinorBEC.DynamicsStep
        dp = cfg.steps[2].params
        @test dp["temperature_ratio"] == 0.1
        @test dp["noise_seed"] == 42
        @test dp["B"]["q"] isa Dict
    end

    @testset "parsing - dynamics without perturbation" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0],
                "n" => [32],
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-8,
        ),
    )],
)
"""
        cfg = load_config_from_string(yaml)
        @test cfg isa PipelineConfig
        @test length(cfg.steps) == 1
    end

    @testset "parsing - phase_scan type" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => 6.0,
                "n" => 8,
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 100.0,
                "c1" => -5.0,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    )],
    "scan" => Dict{String, Any}(
        "continuation" => true,
        "zip" => Dict{String, Any}(
            "pipeline.0.interactions[1]" => [-5.0, -2.0, 0.0, 2.0, 5.0],
        ),
    ),
)
"""
        cfg = load_config_from_string(yaml)
        @test cfg isa PipelineConfig
        @test cfg.scan isa OverrideScan
        @test length(cfg.scan.points) == 5
        @test cfg.scan.continuation == true
    end

    @testset "parsing - c_total/c1_ratio" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "c_dd" => 211.0,
                "enabled" => true,
            ),
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => 6.0,
                "n" => 8,
            ),
            "interactions" => Dict{String, Any}(
                "c1_ratio" => 0.02778,
                "c_total" => 4689.0,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-8,
        ),
    )],
)
"""
        cfg = load_config_from_string(yaml)
        @test cfg isa PipelineConfig
        p = cfg.steps[1].params
        @test p["atom"] == "Eu151"
        @test p["interactions"]["c_total"] == 4689.0
        @test p["ddi"]["c_dd"] == 211.0
    end

    @testset "parsing - DDI image handling defaults ON" begin
        # Flipped 2026-07-29. The bare periodic kernel carries a 2.1e-2 … 4.7e-2
        # dipolar field error against free space, FLAT in resolution (1.91e-2 at
        # 32³, 48³ and 64³ alike), so it is not something a finer grid fixes.
        # Measured by ddi_cutoff_geometry_jz_probe.jl (archived: BEC-simulation-archive/scripts_2026_08_18/).
        atom = SpinorBEC.resolve_atom(:Eu151)
        inter = Dict("N_atoms" => 30000, "omega_ref" => 628.3)

        _, _, _, _, _, trunc, padded, pf = SpinorBEC._parse_gs_ddi(Dict{String, Any}(), inter, atom)
        @test padded == true
        @test trunc == SpinorBEC.DDI_TRUNC_RADIUS_DEFAULT
        @test trunc <= 0        # make_workspace's "auto" sentinel
        @test pf == 2.0

        # Both knobs stay individually addressable — the opt-out is the escape
        # hatch for reproducing a pre-flip run.
        _, _, _, _, _, _, padded_off, _ = SpinorBEC._parse_gs_ddi(
            Dict{String, Any}("padded" => false), inter, atom)
        @test padded_off == false
        @test isnan(SpinorBEC._parse_ddi_trunc_radius("none"))
        @test isnan(SpinorBEC._parse_ddi_trunc_radius("off"))
        @test SpinorBEC._parse_ddi_trunc_radius("auto") == -1.0
        @test SpinorBEC._parse_ddi_trunc_radius(7.5) == 7.5

        # The dynamics step rebuilds the DDI kernel instead of inheriting it, so
        # it must default the same way or a config with no explicit `ddi:` block
        # gets a padded ground state feeding bare-kernel dynamics. Pinning the
        # shared constants is what keeps the two call sites from drifting apart
        # again — they used to carry independent literals.
        @test SpinorBEC.DDI_PADDED_DEFAULT == true
        @test SpinorBEC.DDI_TRUNC_RADIUS_DEFAULT == -1.0

        # `pad_factor: auto` has to survive schema validation as a String, not
        # just parse — the FieldSpec type is what rejects it otherwise.
        yaml_auto = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "pad_factor" => "auto",
            ),
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [6.0, 6.0, 12.0],
                "n" => [8, 8, 16],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 1000,
                "omega_ref" => 628.3,
            ),
            "n_steps" => 10,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    )],
)
"""
        cfg_auto = load_config_from_string(yaml_auto)
        _, _, _, _, _, _, _, pf_auto = SpinorBEC._parse_gs_ddi(
            cfg_auto.steps[1].params["ddi"], inter, atom
        )
        @test pf_auto == -1.0
    end

    @testset "run_pipeline - ground_state" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0],
                "n" => [32],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 200,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    )],
)
"""
        cfg = load_config_from_string(yaml)
        result = run_pipeline(cfg; verbose=false)
        @test result.ground_state_energy isa Float64
        @test isfinite(result.ground_state_energy)
        @test result.ground_state_converged isa Bool
        @test result.psi isa AbstractArray
    end

    @testset "run_pipeline - dynamics" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0],
                "n" => [32],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 200,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "dt" => 0.001,
            "duration" => 0.05,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "save" => Dict{String, Any}(
                "every" => 25,
            ),
        ),
    )],
)
"""
        cfg = load_config_from_string(yaml)
        result = run_pipeline(cfg; verbose=false)
        @test result.ground_state_energy isa Float64
        @test result.dynamics_result !== nothing
    end

    @testset "run_pipeline - dynamics with perturbation" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0],
                "n" => [32],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 200,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "dt" => 0.001,
            "duration" => 0.05,
            "noise_seed" => 42,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "save" => Dict{String, Any}(
                "every" => 25,
            ),
            "temperature_ratio" => 0.05,
        ),
    )],
)
"""
        cfg = load_config_from_string(yaml)
        result = run_pipeline(cfg; verbose=false)
        @test result.dynamics_result !== nothing
    end

    @testset "parsing - comparison_runs" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => 6.0,
                "n" => 8,
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 100.0,
                "c1" => -5.0,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "polar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
                "pipeline.0.tol" => 1.0e-10,
            ),
        ), Dict{String, Any}(
            "name" => "ferro",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
            ),
        )],
        "zip" => Dict{String, Any}(
            "pipeline.0.interactions[1]" => [-5.0, 0.0, 5.0],
        ),
    ),
)
"""
        cfg = load_config_from_string(yaml)
        @test cfg.scan isa OverrideScan
        @test length(cfg.scan.comparison_runs) == 2
        @test cfg.scan.comparison_runs[1][1] == "polar"
        @test cfg.scan.comparison_runs[1][2]["pipeline.0.tol"] == 1e-10
        @test cfg.scan.comparison_runs[2][1] == "ferro"
    end

    @testset "parsing - constrained_jz scan" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => [6.0, 6.0],
                "n" => [8, 8],
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 100.0,
                "c1" => -5.0,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    )],
    "scan" => Dict{String, Any}(
        "max_iter" => 5,
        "omega_range" => [-5.0, 5.0],
        "target_values" => [0.0, 1.0],
        "tolerance" => 0.1,
        "type" => "constrained_jz",
    ),
)
"""
        cfg = load_config_from_string(yaml)
        @test cfg isa PipelineConfig
        @test cfg.scan isa ConstrainedJzScan
        @test cfg.scan.tolerance == 0.1
    end
end
