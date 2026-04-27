using Test
using SpinorBEC

@testset "Option γ pipeline YAML parsing" begin
    # Build a minimal raw YAML dict and verify _parse_step produces the
    # right step type. We don't actually run it (JIT cost would dominate).
    @testset "kind: rotating_basis on ground_state" begin
        d = Dict(
            "ground_state" => Dict(
                "kind" => "rotating_basis",
                "atom" => "Eu151",
                "grid" => Dict("n" => [8, 8, 8], "box" => [4.0, 4.0, 4.0]),
                "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
                "interactions" => Dict("c0" => 10.0, "c1" => 0.0, "c_dd" => 0.0),
                "zeeman" => Dict("p" => 1.0, "q" => 0.0),
                "n_steps" => 10,
                "dt" => 0.01,
            ),
        )
        step = SpinorBEC._parse_step(d)
        @test step isa SpinorBEC.RotatingBasisGroundStateStep
        @test step.params["atom"] == "Eu151"
        @test step.params["zeeman"]["p"] == 1.0
    end

    @testset "kind: option_gamma alias" begin
        d = Dict(
            "ground_state" => Dict(
                "kind" => "option_gamma",
                "atom" => "Dy164",
                "grid" => Dict("n" => [8, 8, 8], "box" => [4.0, 4.0, 4.0]),
                "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
                "interactions" => Dict("c0" => 10.0),
                "zeeman" => Dict("p" => 1.0),
                "n_steps" => 10,
                "dt" => 0.01,
            ),
        )
        step = SpinorBEC._parse_step(d)
        @test step isa SpinorBEC.RotatingBasisGroundStateStep
    end

    @testset "kind: rotating_basis on dynamics" begin
        d = Dict(
            "dynamics" => Dict(
                "kind" => "rotating_basis",
                "duration" => 1.0,
                "dt" => 0.005,
                "B_hat" => Dict("theta_const" => 0.5, "phi_omega" => 2.0),
            ),
        )
        step = SpinorBEC._parse_step(d)
        @test step isa SpinorBEC.RotatingBasisDynamicsStep
        @test step.params["duration"] == 1.0
    end

    @testset "default (no kind) → spinor GroundStateStep" begin
        d = Dict(
            "ground_state" => Dict(
                "atom" => "Rb87",
                "grid" => Dict("n" => [8, 8, 8], "box" => [4.0, 4.0, 4.0]),
                "interactions" => Dict("c_total" => 10.0),
            ),
        )
        step = SpinorBEC._parse_step(d)
        @test step isa SpinorBEC.GroundStateStep
    end

    @testset "kind: binary still works" begin
        d = Dict(
            "ground_state" => Dict(
                "kind" => "binary",
                "grid" => Dict("n" => [8, 8, 8], "box" => [4.0, 4.0, 4.0]),
                "interactions" => Dict("g_AA" => 1.0, "g_BB" => 1.0, "g_AB" => 0.5),
            ),
        )
        step = SpinorBEC._parse_step(d)
        @test step isa SpinorBEC.BinaryGroundStateStep
    end

    @testset "PipelineStep union includes rotating basis types" begin
        @test SpinorBEC.RotatingBasisGroundStateStep <: SpinorBEC.PipelineStep
        @test SpinorBEC.RotatingBasisDynamicsStep <: SpinorBEC.PipelineStep
    end

    @testset "Integrator default" begin
        # Default = Yoshida6 (order 6) for all RTP durations
        @test SpinorBEC._default_rotating_integrator(0.1) == "yoshida6"
        @test SpinorBEC._default_rotating_integrator(31.4) == "yoshida6"  # Klaus 100ms
        @test SpinorBEC._default_rotating_integrator(314.0) == "yoshida6" # Klaus 1s
    end

    @testset "dt from epsilon" begin
        # ε=1e-3 over T=100 (Klaus 1 sec analog) with various integrators
        # dt = 0.1 · (ε/T)^(1/p)
        ε = 1e-3;
        T = 100.0
        @test SpinorBEC._dt_from_epsilon(ε, T, "strang") ≈ 0.1 * (1e-5)^(1/2) atol=1e-10
        @test SpinorBEC._dt_from_epsilon(ε, T, "yoshida4") ≈ 0.1 * (1e-5)^(1/4) atol=1e-10
        @test SpinorBEC._dt_from_epsilon(ε, T, "yoshida6") ≈ 0.1 * (1e-5)^(1/6) atol=1e-10
        # Higher order → larger dt budget at same ε
        dt_strang = SpinorBEC._dt_from_epsilon(ε, T, "strang")
        dt_y6 = SpinorBEC._dt_from_epsilon(ε, T, "yoshida6")
        @test dt_y6 > dt_strang * 5     # Y6 budget at least 5× larger
    end

    @testset "load_config parses rotating_basis YAML" begin
        # Use the smoke config we created
        config = SpinorBEC.load_config("runs/option_gamma_smoke/config.yaml")
        @test length(config.steps) == 2
        @test config.steps[1] isa SpinorBEC.RotatingBasisGroundStateStep
        @test config.steps[2] isa SpinorBEC.RotatingBasisDynamicsStep
    end
end

# Direct _run_step test: bypasses run_config / _step_dispatch! abstract
# dispatch (which triggers a multi-minute JIT cascade — see memory note
# "pipeline_inference"). This exercises the helper bodies directly.
@testset "Option γ pipeline _run_step direct" begin
    @testset "ground_state direct call" begin
        params = Dict{String, Any}(
            "F" => 1,
            "grid" => Dict("n" => [8, 8, 8], "box" => [4.0, 4.0, 4.0]),
            "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
            "interactions" => Dict("c0" => 10.0, "c1" => 0.0, "c_dd" => 0.0),
            "zeeman" => Dict("p" => 1.0, "q" => 0.0),
            "B_hat" => Dict("theta" => 0.0, "phi" => 0.0),
            "gauge_fix" => false,
            "n_steps" => 10,
            "dt" => 0.01,
            "init_m_idx" => 1,
            "init_sigma" => 0.5,
        )
        step = SpinorBEC.RotatingBasisGroundStateStep(params)
        psi, grid, atom, workspace, step_result = SpinorBEC._run_step(
            step, nothing, nothing, nothing, nothing; verbose=false)
        @test psi isa Array{ComplexF64, 4}
        @test size(psi, 4) == 3   # F=1 → D=3
        @test workspace === nothing
        @test haskey(step_result, :rotating_basis_ws)
        @test haskey(step_result, :rotating_basis_mu)
        @test step_result[:rotating_basis_F] == 1
    end

    @testset "dynamics direct call (continues from GS)" begin
        params_gs = Dict{String, Any}(
            "F" => 1,
            "grid" => Dict("n" => [8, 8, 8], "box" => [4.0, 4.0, 4.0]),
            "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
            "interactions" => Dict("c0" => 10.0),
            "zeeman" => Dict("p" => 1.0),
            "n_steps" => 5,
            "dt" => 0.01,
        )
        step_gs = SpinorBEC.RotatingBasisGroundStateStep(params_gs)
        psi_gs, grid_gs, atom_gs, _, gs_result = SpinorBEC._run_step(
            step_gs, nothing, nothing, nothing, nothing; verbose=false)

        # Dynamics step
        params_dyn = Dict{String, Any}(
            "duration" => 0.05,
            "dt" => 0.01,
            "save_every" => 1,
            "B_hat" => Dict("theta_const" => 0.3, "phi_omega" => 1.0),
        )
        step_dyn = SpinorBEC.RotatingBasisDynamicsStep(params_dyn)
        psi_dyn, _, _, _, dyn_result = SpinorBEC._run_step(
            step_dyn, psi_gs, grid_gs, atom_gs, nothing;
            verbose=false, pipeline_results=gs_result)
        @test psi_dyn isa Array{ComplexF64, 4}
        @test haskey(dyn_result, :rotating_basis_dynamics)
        traj = dyn_result[:rotating_basis_dynamics]
        @test length(traj[:times]) >= 1
        @test all(abs.(traj[:norms] .- 1.0) .< 1e-6)
    end
end
