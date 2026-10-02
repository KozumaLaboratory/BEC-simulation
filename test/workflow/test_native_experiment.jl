function _write_julia_fixture(path, data)
    open(io -> show(io, data), path, "w")
    path
end

using Test
using SpinorBEC
using JSON
using JLD2
using SpinorBEC: _load_config_data, _config_snapshot_path, write_complete_marker,
    DEALIAS_2_3_ENABLED, DEALIAS_K_CUTOFF

native_probe(; n_steps=3) = PipelineConfig([
    GroundStateStep(
        atom=:Rb87, grid=(n=[8], box=[8.0]),
        interactions=(N_atoms=10, omega_ref=100.0, c0=1.0, c1=0.0),
        potential=(type=:harmonic, omega=[1.0]), initial_state=:polar,
        n_steps=n_steps, dt=0.001, tol=1e-6,
    ),
])

@testset "Julia-defined persistent experiments" begin
    cfg = native_probe()
    before = deepcopy(cfg.raw_data)
    @test cfg.steps[1] isa GroundStateStep
    @test PipelineConfig([GroundStateStep(atom=:Rb87), DynamicsStep(duration=1.0)]).steps[2] isa
        DynamicsStep
    @test PipelineConfig([RotatingBasisGroundStateStep(atom=:Rb87)]).steps[1] isa
        RotatingBasisGroundStateStep
    @test PipelineConfig([BinaryGroundStateStep(atom=:Rb87)]).steps[1] isa BinaryGroundStateStep
    @test PipelineConfig([ScalarEGPEGroundStateStep(atom=:Rb87)]).steps[1] isa
        ScalarEGPEGroundStateStep
    @test PipelineConfig([AnalyzeStep(:populations)]).steps[1] isa AnalyzeStep
    @test_throws ArgumentError PipelineConfig([])
    @test_throws ArgumentError PipelineConfig([:ground_state])

    mktempdir() do root
        exp = Experiment(cfg; store=CASStore(root))
        path = write_run!(exp)
        @test basename(path) == "config.json"
        @test !isfile(joinpath(outdir(exp), "config.experiment.jl"))
        @test content_id(_load_config_data(path)) == content_id(cfg.raw_data)
        @test Experiment(path; store=CASStore(root)).outdir == exp.outdir
        @test load_config(path).steps[1] isa GroundStateStep
        @test inspect_config(cfg).raw == inspect_config(path).raw
        preview_dir = joinpath(root, "dry-run")
        dry = run_experiment(cfg; run_dir=preview_dir, dry_run=true, verbose=false, audit=false)
        @test JSON.parse(dry)["pipeline"][1]["ground_state"]["n_steps"] == 3
        @test !ispath(preview_dir)

        withenv("SPINORBEC_STAGE_CACHE" => "0", "SPINORBEC_ALLOW_STALE_POINTS" => "1") do
            @test run!(exp; verbose=false, audit=false) === exp
            point = joinpath(exp.outdir, "point_001.jld2")
            @test isfile(point)
            saved = JSON.parsefile(path; use_mmap=false)
            @test haskey(saved, "resolved")
            @test cfg.raw_data == before
            @test exp.spec == before
            @test isfile(joinpath(exp.outdir, "_exit_summary.json"))
            @test basename(exp.outdir) in list_runs(root)
            @test run_status(exp.outdir).completed == 1
            # Differential oracle: the Julia file must reach the
            # identical solver with identical inputs, without a second engine.
            legacy_dir = mkpath(joinpath(root, "legacy"))
            legacy_path = joinpath(legacy_dir, "config.experiment.jl")
            _write_julia_fixture(legacy_path, before)
            run_experiment(legacy_path; run_dir=legacy_dir, verbose=false, audit=false)
            @test JLD2.load(point, "psi") ==
                JLD2.load(joinpath(legacy_dir, "point_001.jld2"), "psi")

            jldopen(point, "a+") do f
                f["force_canary"] = true
            end
            write_complete_marker(point, [point]; kind="point")
            config_mtime = mtime(path)
            @test run_experiment(path; verbose=false, audit=false) == exp.outdir
            @test mtime(path) == config_mtime
            @test status(exp) == :cached
            @test JLD2.load(point, "force_canary") === true
            other = native_probe(n_steps=4)
            @test_throws ArgumentError run_experiment(
                other; run_dir=exp.outdir, verbose=false, audit=false
            )
            @test _load_config_data(path) == cfg.raw_data
            run!(exp; force=true, verbose=false, audit=false)
            @test !haskey(JLD2.load(point), "force_canary")

            qr = QueueRoot(joinpath(root, "queue"))
            entry = enqueue!(exp; qr, kick_tick=false)
            @test entry.spec_path == path
            @test _load_config_data(entry.spec_path) == exp.spec
            @test isempty(store_census(root).stale_key)
            changed = JSON.parsefile(path; use_mmap=false)
            changed["spec"]["pipeline"][1]["ground_state"]["n_steps"] += 1
            write(path, JSON.json(changed))
            @test haskey(store_census(root).stale_key, basename(exp.outdir))
            write_run!(exp)

            replay_dir = joinpath(root, "replayed")
            @test run_experiment(path; run_dir=replay_dir, verbose=false, audit=false) == replay_dir
            @test JLD2.load(joinpath(replay_dir, "point_001.jld2"), "psi") ==
                JLD2.load(point, "psi")
        end
    end

    @testset "failed preparation restores numerical and source scopes" begin
        old = (DEALIAS_2_3_ENABLED[], DEALIAS_K_CUTOFF[])
        withenv("SPINORBEC_CONFIG_DIR" => "native-scope-canary") do
            broken = deepcopy(cfg.raw_data)
            broken["dealias"] = Dict("enabled" => !old[1])
            broken["unrecognized_native_key"] = true
            @test_throws ArgumentError run_experiment(broken; verbose=false, audit=false)
            @test (DEALIAS_2_3_ENABLED[], DEALIAS_K_CUTOFF[]) == old
            @test ENV["SPINORBEC_CONFIG_DIR"] == "native-scope-canary"
        end
    end
end

@testset "Julia-only experiment definitions" begin
    @test !isdefined(SpinorBEC, :run_yaml)
    @test !isdefined(SpinorBEC, :run_yaml_calibrated)
    @test !isdefined(SpinorBEC, :read_model_toml)
    @test !isdefined(SpinorBEC, :model_from_toml)
    @test !isdefined(SpinorBEC, :YAML)
    mktempdir() do dir
        for extension in ("yaml", "yml", "toml")
            path = joinpath(dir, "experiment.$extension")
            write(path, "error(\"must not execute\")")
            @test_throws ArgumentError load_config(path)
            @test_throws ArgumentError run_experiment(path; dry_run=true, verbose=false)
            @test_throws ArgumentError Experiment(path)
            @test_throws ArgumentError inspect_config(path)
        end
        # Relative includes and ordinary Julia functions are the sharing mechanism.
        write(joinpath(dir, "parameters.jl"), "grid_size() = 8")
        path = joinpath(dir, "probe.experiment.jl")
        write(
            path,
            """
include("parameters.jl")
PipelineConfig([GroundStateStep(atom=:Rb87,
    grid=(n=[grid_size()], box=[8.0]), n_steps=3)])
""",
        )
        @test load_config(path).steps[1].params["grid"]["n"] == [8]
        @test compute_run_dir(path; base_dir=dir) ==
            joinpath(dir, content_id(SpinorBEC._load_config_data(path)))
        # An unsupported extension must not revive through snapshot discovery.
        write(joinpath(dir, "config.yaml"), "pipeline: []")
        @test SpinorBEC._config_snapshot_path(dir) == joinpath(dir, "config.json")
    end
end
