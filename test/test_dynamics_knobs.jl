# Fast unit tests for the YAML-side wiring of the new dynamics knobs
# (seed_k_cut, live_monitor). These tests bypass run_pipeline entirely so
# they don't trip the heavy YAML JIT cascade — they only verify
#   1. schema.jl accepts the new keys (no "unknown key" warning),
#   2. parse_pipeline emits the keys into the DynamicsStep params dict, and
#   3. _build_live_callback wires up correctly when given a real path.

using Test
using SpinorBEC
using JSON

@testset "Dynamics knobs — YAML wiring" begin
    @testset "schema accepts seed_k_cut + live_monitor" begin
        cfg = SpinorBEC.load_config_from_string("""
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: 16, box: 8.0}
      interactions: {c0: 5.0, c1: 0.0}
      dt: 0.005
      n_steps: 5
      tol: 1.0e-3
  - dynamics:
      duration: 0.05
      dt: 0.01
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      live_monitor: {every: 1}
""")
        @test length(cfg.steps) == 2
        dyn = cfg.steps[2]
        @test dyn isa SpinorBEC.DynamicsStep
        # parse_pipeline keeps the raw key strings on the step's params dict
        @test dyn.params["seed_k_cut"] ≈ 2.5
        @test dyn.params["live_monitor"] isa Dict
        @test dyn.params["live_monitor"]["every"] == 1
    end

    @testset "_build_live_callback writes JSON" begin
        mktempdir() do tmp
            status_path = joinpath(tmp, "_live_status.json")
            cb = SpinorBEC._build_live_callback(Dict("every" => 1), status_path)
            @test cb !== nothing
            @test cb isa Function
            # Construct a minimal workspace + invoke the callback once.
            grid = make_grid(GridConfig(8, 4.0))
            ws = make_workspace(;
                grid=grid,
                atom=AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0),
                interactions=InteractionParams(5.0, 0.0),
                sim_params=SimParams(dt=0.001, n_steps=1, save_every=1),
            )
            cb(ws, 1, [0.0], [1.234])
            @test isfile(status_path)
            data = JSON.parsefile(status_path)
            @test data["step"] == 1
            @test data["energy"] ≈ 1.234
            @test haskey(data, "norm")
            @test data["populations"] isa AbstractVector
            @test length(data["populations"]) == 3   # F=1 → D=3
        end
    end

    @testset "_build_live_callback returns nothing when off" begin
        # YAML omits the knob → nothing
        @test SpinorBEC._build_live_callback(nothing, "/tmp/x.json") === nothing
        # YAML says false → nothing
        @test SpinorBEC._build_live_callback(false, "/tmp/x.json") === nothing
        # YAML asks for it but no status_path is set → silently skip
        @test SpinorBEC._build_live_callback(true, nothing) === nothing
    end

    @testset "_build_live_callback every>1 throttling" begin
        mktempdir() do tmp
            status_path = joinpath(tmp, "_live_status.json")
            cb = SpinorBEC._build_live_callback(Dict("every" => 5), status_path)
            grid = make_grid(GridConfig(8, 4.0))
            ws = make_workspace(;
                grid=grid,
                atom=AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0),
                interactions=InteractionParams(5.0, 0.0),
                sim_params=SimParams(dt=0.001, n_steps=1, save_every=1),
            )
            cb(ws, 1, Float64[], Float64[])    # not a multiple of 5
            @test !isfile(status_path)
            cb(ws, 5, Float64[], [-0.5])
            @test isfile(status_path)
            data = JSON.parsefile(status_path)
            @test data["step"] == 5
        end
    end
end
