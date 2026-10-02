using Test
using SpinorBEC

@testset "Adaptive dt" begin
    @testset "adaptive converges to same ground state" begin
        grid = make_grid(GridConfig(64, 15.0))
        atom = Rb87
        interactions = compute_interaction_params(atom)
        potential = HarmonicTrap(1.0)

        result_fixed = find_ground_state(;
            grid, atom, interactions, potential,
            dt=0.001, n_steps=5000, tol=1e-8,
        )

        result_adaptive = find_ground_state(;
            grid, atom, interactions, potential,
            dt=0.001, n_steps=5000, tol=1e-8,
            adaptive_dt=true, dt_max=0.01,
        )

        @test abs(result_fixed.energy - result_adaptive.energy) / abs(result_fixed.energy) < 0.01
    end

    @testset "AdaptiveDtParams" begin
        p = AdaptiveDtParams()
        @test p.dt_init == 0.001
        @test p.dt_min == 1e-5
        @test p.dt_max == 0.01
        @test p.tol == 1e-3
        @test p.error_mode === :step_change

        p2 = AdaptiveDtParams(dt_init=0.005, dt_min=1e-4, dt_max=0.05, tol=1e-2)
        @test p2.dt_init == 0.005
        @test p2.dt_max == 0.05

        p3 = AdaptiveDtParams(error_mode=:richardson)
        @test p3.error_mode === :richardson

        @test_throws ArgumentError AdaptiveDtParams(dt_init=-1.0)
        @test_throws ArgumentError AdaptiveDtParams(dt_min=0.1, dt_max=0.01)
        @test_throws ArgumentError AdaptiveDtParams(tol=-1.0)
        @test_throws ArgumentError AdaptiveDtParams(error_mode=:foo)
    end

    @testset "run_simulation_adaptive!" begin
        grid = make_grid(GridConfig(64, 20.0))
        atom = Rb87
        interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5))
        potential = HarmonicTrap(1.0)

        sp = SimParams(; dt=0.001, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, potential, sim_params=sp)
        adaptive = AdaptiveDtParams(dt_init=0.001, dt_min=1e-5, dt_max=0.01, tol=1e-3)
        out = run_simulation_adaptive!(ws; adaptive, t_end=0.5, save_interval=0.1)

        # Output structure
        @test out.n_accepted > 0
        @test length(out.result.times) >= 3
        @test out.result.times[1] == 0.0
        @test out.result.times[end] >= 0.5 - 0.01

        # Norm conservation
        N0 = out.result.norms[1]
        for n in out.result.norms
            @test n ≈ N0 rtol = 1e-4
        end

        # dt grows from small initial value
        sp2 = SimParams(; dt=0.001, n_steps=1)
        ws2 = make_workspace(; grid, atom, interactions, potential, sim_params=sp2)
        adaptive2 = AdaptiveDtParams(dt_init=0.0001, dt_min=1e-5, dt_max=0.01, tol=1e-3)
        out2 = run_simulation_adaptive!(ws2; adaptive=adaptive2, t_end=0.5, save_interval=0.5)
        @test out2.final_dt > adaptive2.dt_init

        # Matches fixed dt energy
        sp_fixed = SimParams(; dt=0.001, n_steps=500, save_every=500)
        ws_fixed = make_workspace(; grid, atom, interactions, potential, sim_params=sp_fixed)
        res_fixed = run_simulation!(ws_fixed)
        @test abs(res_fixed.energies[end] - out.result.energies[end]) /
              abs(res_fixed.energies[end]) < 0.01
    end

    @testset "error estimators" begin
        a = ComplexF64[1.0, 2.0, 3.0]
        @test SpinorBEC._psi_relative_change(a, a) == 0.0
        @test SpinorBEC._density_relative_change(a, a) == 0.0

        c = ComplexF64[1.1, 2.0, 3.0]
        @test 0 < SpinorBEC._psi_relative_change(c, a) < 1
        @test 0 < SpinorBEC._density_relative_change(c, a) < 1

        # Phase rotation: density doesn't change, psi does
        phase = ComplexF64[exp(0.5im), 2exp(0.5im), 3exp(0.5im)]
        @test SpinorBEC._psi_relative_change(phase, a) > 0.1
        @test SpinorBEC._density_relative_change(phase, a) < 1e-14

        # Wavefunction L2 change
        @test SpinorBEC._wavefunction_l2_change(a, a) == 0.0
        @test SpinorBEC._wavefunction_l2_change(c, a) > 0.0
        # Phase rotation IS detected by L2 change (unlike density)
        @test SpinorBEC._wavefunction_l2_change(phase, a) > 0.01
        # Global phase: psi_new = e^{i*phi} psi_old -> L2 change = 2(1 - cos phi)
        global_phase = a .* cis(0.1)
        expected = 2 * (1 - cos(0.1))
        @test SpinorBEC._wavefunction_l2_change(global_phase, a) ≈ expected rtol=1e-10
    end

    @testset "run_simulation_adaptive! richardson mode" begin
        grid = make_grid(GridConfig(64, 20.0))
        atom = Rb87
        interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5))
        potential = HarmonicTrap(1.0)

        sp = SimParams(; dt=0.001, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, potential, sim_params=sp)
        adaptive = AdaptiveDtParams(
            dt_init=0.001, dt_min=1e-5, dt_max=0.01, tol=1e-3, error_mode=:richardson
        )
        out = run_simulation_adaptive!(ws; adaptive, t_end=0.5, save_interval=0.1)

        @test out.n_accepted > 0
        @test length(out.result.times) >= 3
        @test out.result.times[end] >= 0.5 - 0.01

        N0 = out.result.norms[1]
        for n in out.result.norms
            @test n ≈ N0 rtol = 1e-4
        end

        sp_fixed = SimParams(; dt=0.001, n_steps=500, save_every=500)
        ws_fixed = make_workspace(; grid, atom, interactions, potential, sim_params=sp_fixed)
        res_fixed = run_simulation!(ws_fixed)
        @test abs(res_fixed.energies[end] - out.result.energies[end]) /
              abs(res_fixed.energies[end]) < 0.01
    end

    # `dynamics.adaptive_dt` is REFUSED, and these testsets assert the refusal.
    #
    # They used to assert that it PARSES — three testsets reading the numbers
    # back out of `cfg.steps[i].params["adaptive_dt"]`. That surface was retired
    # deliberately in bfcaf3db: the schema validated five numeric fields with
    # ranges, and nothing under `src/workflow` ever constructed
    # `AdaptiveDtParams` or called `run_simulation_yoshida!`, so a config asking
    # for adaptive stepping validated cleanly and then ran at fixed `dt`. An
    # accuracy knob that is accepted and discarded is worse than one that does
    # not exist.
    #
    # The retirement did not update these testsets, and per-PR CI could not see
    # it: this file is in `FULL_EXTRA`, which only the nightly runs. They went
    # red on 2026-08-01 and stayed red for 92 consecutive nightly runs (#304).
    # That is the cost of a gate whose tier no PR executes — the defect is
    # three weeks old and its author's own docstring says "refusing breaks
    # nothing in the tree", which was true of `runs/` and false of `test/`.
    #
    # Adaptive stepping remains available and is exercised above, through the
    # Julia API it actually lives on.
    @testset "YAML `dynamics.adaptive_dt` is refused, not silently ignored" begin
        function _cfg(dyn_body)
            gs = Dict("atom" => "Rb87", "grid" => Dict("n" => 32, "box" => 10.0),
                "interactions" => Dict("c0" => 1.0, "c1" => 0.0),
                "dt" => 0.01, "n_steps" => 10, "tol" => 1e-4,
                "potential" => Dict("type" => "harmonic", "omega" => [1.0]))
            dyn = merge(
                Dict{String, Any}("duration" => 1.0, "dt" => 0.01,
                    "B" => Dict("p" => 0.0, "q" => 0.0)), dyn_body)
            repr(Dict("pipeline" => [Dict("ground_state" => gs), Dict("dynamics" => dyn)]))
        end

        # THE PASS DIRECTION FIRST. A `dynamics:` block with no `adaptive_dt`
        # must still parse — this is the case that matters most, because a
        # guard that reddens on ordinary configs is a guard someone deletes.
        ok = load_config_from_string(_cfg(Dict()))
        @test ok isa PipelineConfig
        @test length(ok.steps) == 2
        @test !haskey(ok.steps[2].params, "adaptive_dt")

        # Every shape the retired surface accepted is refused: fully specified,
        # partially specified, and empty. The empty-dict arm is the one a
        # `haskey`-based guard is most likely to miss.
        fully = Dict(
            "adaptive_dt" => Dict("dt_init" => 0.005, "dt_min" => 0.0001,
                "dt_max" => 0.05, "tol" => 0.002),
        )
        partial = Dict("adaptive_dt" => Dict("tol" => 0.001, "error_mode" => "richardson"))
        empty = Dict("adaptive_dt" => Dict())

        for (label, body) in
            (("fully specified", fully), ("partial", partial), ("empty", empty))
            @testset "$label" begin
                err = try
                    load_config_from_string(_cfg(body))
                    nothing
                catch e
                    e
                end
                @test err isa ArgumentError
                # The message has to route the user somewhere, or the refusal
                # just costs them the run without telling them what to do.
                @test occursin("adaptive_dt", err.msg)
                @test occursin("run_simulation_yoshida!", err.msg)
            end
        end
    end

    @testset "IntegratorConfig type" begin
        ic = IntegratorConfig()
        @test ic.method === :strang
        @test ic.params === nothing

        ic2 = IntegratorConfig(:yoshida, AdaptiveDtParams(; dt_init=0.01))
        @test ic2.method === :yoshida
        @test ic2.params.dt_init == 0.01

        @test_throws ArgumentError IntegratorConfig(:unknown)
        @test_throws ArgumentError IntegratorConfig(:adaptive, nothing)
    end

    @testset "YAML integrator string shorthand" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => 10.0,
                "n" => 32,
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 1.0,
                "c1" => 0.0,
            ),
            "n_steps" => 10,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 0.0001,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "dt" => 0.01,
            "duration" => 1.0,
            "integrator" => "strang",
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "dt" => 0.01,
            "duration" => 1.0,
            "integrator" => "yoshida",
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "dt" => 0.01,
            "duration" => 1.0,
            "integrator" => "adaptive",
        ),
    )],
)
"""
        cfg = load_config_from_string(yaml)
        @test cfg isa PipelineConfig
        @test cfg.steps[2].params["integrator"] == "strang"
        @test cfg.steps[3].params["integrator"] == "yoshida"
        @test cfg.steps[4].params["integrator"] == "adaptive"
    end

    @testset "YAML integrator dict form" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => 10.0,
                "n" => 32,
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 1.0,
                "c1" => 0.0,
            ),
            "n_steps" => 10,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 0.0001,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "dt" => 0.01,
            "duration" => 1.0,
            "integrator" => Dict{String, Any}(
                "dt_max" => 0.05,
                "dt_min" => 1.0e-5,
                "method" => "adaptive",
                "tol" => 0.0001,
            ),
        ),
    )],
)
"""
        cfg = load_config_from_string(yaml)
        ic = cfg.steps[2].params["integrator"]
        @test ic isa Dict
        @test ic["method"] == "adaptive"
        @test ic["tol"] == 1e-4
        @test ic["dt_min"] == 1e-5
        @test ic["dt_max"] == 0.05
    end

    @testset "run_pipeline with adaptive_dt" begin
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
            "duration" => 0.1,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "save" => Dict{String, Any}(
                "every" => 50,
            ),
        ),
    )],
)
"""
        config = load_config_from_string(yaml)
        result = run_pipeline(config; verbose=false)
        @test result.dynamics_result !== nothing
    end
end
