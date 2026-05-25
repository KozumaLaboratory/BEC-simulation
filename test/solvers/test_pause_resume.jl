@testset "Pause/Resume/Refine" begin
    @testset "ITP checkpoint save and load" begin
        ckpt_dir = mktempdir()
        result = find_ground_state(;
            grid=make_grid(GridConfig((16,), (10.0,))),
            atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            zeeman=ZeemanParams(0.0, 0.1),
            potential=HarmonicTrap((1.0,)),
            dt=0.01, n_steps=100, tol=1e-20,  # tol impossible → runs all steps
            checkpoint_dir=ckpt_dir,
            checkpoint_every=50,
        )

        ckpt_file = joinpath(ckpt_dir, "itp_checkpoint.jld2")
        @test isfile(ckpt_file)

        ckpt = load_itp_checkpoint(ckpt_dir)
        @test ckpt isa ITPCheckpoint
        @test ckpt.step == 100  # last checkpoint at step 100
        @test ckpt.dt == 0.01
        @test size(ckpt.psi) == (16, 3)
        @test isfinite(ckpt.energy)
    end

    @testset "resume_ground_state continues from checkpoint" begin
        ckpt_dir = mktempdir()

        # Run 50 steps
        r1 = find_ground_state(;
            grid=make_grid(GridConfig((16,), (10.0,))),
            atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            zeeman=ZeemanParams(0.0, 0.1),
            potential=HarmonicTrap((1.0,)),
            dt=0.01, n_steps=50, tol=1e-20,
            checkpoint_dir=ckpt_dir,
            checkpoint_every=50,
        )
        @test r1.last_step == 50

        # Resume for 50 more steps (total 100)
        r2 = resume_ground_state(ckpt_dir;
            grid=make_grid(GridConfig((16,), (10.0,))),
            atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            zeeman=ZeemanParams(0.0, 0.1),
            potential=HarmonicTrap((1.0,)),
            n_steps=100, tol=1e-20,
        )
        @test r2.last_step == 100
        # Energy should be lower after more steps
        @test r2.energy <= r1.energy + 1e-6
    end

    @testset "refine_ground_state tightens convergence" begin
        r1 = find_ground_state(;
            grid=make_grid(GridConfig((16,), (10.0,))),
            atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            zeeman=ZeemanParams(0.0, 0.1),
            potential=HarmonicTrap((1.0,)),
            dt=0.01, n_steps=200, tol=1e-4,
        )

        r2 = refine_ground_state(r1;
            tol=1e-8,
            n_steps=500,
        )

        @test r2.energy <= r1.energy + 1e-8
        @test r2.workspace !== nothing
    end

    @testset "ITPCheckpoint struct" begin
        ckpt = ITPCheckpoint(
            zeros(ComplexF64, 8, 3), 42, 100, -5.0, 1e-6, 1e-4, false, 0.01, 1e-8
        )
        @test ckpt.step == 42
        @test ckpt.n_steps == 100
        @test ckpt.energy == -5.0
        @test ckpt.converged == false
    end

    @testset "find_ground_state returns interrupted field" begin
        r = find_ground_state(;
            grid=make_grid(GridConfig((16,), (10.0,))),
            atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            zeeman=ZeemanParams(0.0, 0.1),
            potential=HarmonicTrap((1.0,)),
            dt=0.01, n_steps=50, tol=1e-20,
        )
        @test haskey(r, :interrupted)
        @test r.interrupted == false
        @test haskey(r, :last_step)
        @test r.last_step == 50
    end

    @testset "pause file mechanism" begin
        # Create a minimal run dir with config
        run_dir = mktempdir()
        config_yaml = joinpath(run_dir, "config.yaml")
        write(
            config_yaml,
            """
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: 8, box: 6.0}
      interactions: {c0: 10.0, c1: 0.0}
      dt: 0.01
      n_steps: 20
      tol: 1e-4
      potential: {type: harmonic, omega: [1.0]}
scan:
  zip:
    pipeline.0.interactions[1]: [0.0, -0.5, -1.0]
""",
        )

        # Run first — should complete point 1
        # Then create .pause file
        # We can't easily test mid-run pause, but verify the mechanism exists
        # by touching .pause before running → should complete 0 points
        touch(joinpath(run_dir, ".pause"))
        run_yaml(config_yaml; verbose=false)

        # No points should have been computed
        jld2_files = filter(f -> endswith(f, ".jld2"), readdir(run_dir))
        @test isempty(jld2_files)

        # Remove pause and run — should complete all
        rm(joinpath(run_dir, ".pause"))
        run_yaml(config_yaml; verbose=false)
        jld2_files = filter(f -> endswith(f, ".jld2"), readdir(run_dir))
        @test length(jld2_files) == 3
    end
end
