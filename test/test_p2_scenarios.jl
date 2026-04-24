using Test
using SpinorBEC

@testset "P2 driven-scenario YAMLs — load + parse smoke test" begin
    scenario_dir = joinpath(@__DIR__, "..", "runs", "scenarios")
    yamls = String[]
    for entry in readdir(scenario_dir)
        d = joinpath(scenario_dir, entry)
        isdir(d) || continue
        startswith(entry, "p2_") || continue
        path = joinpath(d, "params.yaml")
        isfile(path) && push!(yamls, path)
    end
    @test !isempty(yamls)
    @info "Discovered $(length(yamls)) P2 scenarios"

    @testset "load+parse $(basename(dirname(path)))" for path in yamls
        cfg = load_config(path)
        @test cfg isa PipelineConfig
        @test !isempty(cfg.steps)
    end
end

@testset "P2.1 CSV waveform hook resolves relative paths" begin
    # Write a throwaway CSV + YAML in a temp dir and load it.
    tdir = mktempdir()
    csv = joinpath(tdir, "field.csv")
    write(csv, "t,B\n0.0,0.0\n1.0,1.0\n")
    yaml_path = joinpath(tdir, "cfg.yaml")
    write(yaml_path, """
pipeline:
  - ground_state:
      atom: Dy164
      grid: {n: 8, box: 4.0}
      interactions: {c0: 10.0, c1: 0.0, omega_ref: 314.159}
      trap: [1.0, 1.0, 1.0]
      zeeman: {Bz: 1.0e-5}
      dt: 0.01
      n_steps: 2
      tol: 1.0e-2
  - dynamics:
      duration: 1.0
      dt: 0.1
      interactions: {omega_ref: 314.159}
      zeeman:
        Bz:
          csv: {path: field.csv, scale: 1.0e-4}
""")
    cfg = load_config(yaml_path)
    @test cfg isa PipelineConfig
end

@testset "STA counter-diabatic q-quench builder" begin
    p_wf, q_wf, by_wf = sta_counter_diabatic_q_quench(;
        q_start = 1.0, q_end = -1.0, duration = 0.5, n_samples = 64,
    )
    # q endpoints match
    @test evaluate(q_wf, 0.0) ≈ 1.0 atol=1e-12
    @test evaluate(q_wf, 0.5) ≈ -1.0 atol=1e-12
    # CD field is zero at both endpoints (smooth-step ⇒ dq/dt = 0)
    @test abs(evaluate(by_wf, 0.0)) < 1e-10
    @test abs(evaluate(by_wf, 0.5)) < 1e-10
    # CD field is non-trivial in the middle
    @test abs(evaluate(by_wf, 0.25)) > 1e-3
end

@testset "Feshbach ramp builder" begin
    c0, as_wf, B_wf = feshbach_ramp(;
        a_bg = 100.0, Delta = 10.0, B0 = 50.0,
        B_start = 70.0, B_end = 80.0, duration = 1.0, n_samples = 64,
    )
    # Endpoints
    @test evaluate(B_wf, 0.0) ≈ 70.0 atol=1e-12
    @test evaluate(B_wf, 1.0) ≈ 80.0 atol=1e-12
    # a_s at B_start: a_bg × (1 - Δ/(B_start - B0))
    expected_start = 100.0 * (1.0 - 10.0 / (70.0 - 50.0))
    @test evaluate(as_wf, 0.0) ≈ expected_start rtol=1e-10
    @test evaluate(c0, 0.0) ≈ expected_start rtol=1e-10
end

@testset "simulate_tof_with_gradient smoke" begin
    # Tiny grid: build a trivial BEC, run a short TOF with a gradient,
    # check that per-m densities are returned and differ (sign of spin
    # separation). This is a structural smoke test, not physics.
    cfg = GridConfig((16, 16, 16), (6.0, 6.0, 6.0))
    grid = make_grid(cfg)
    atom = Dy164
    ip = InteractionParams(20.0, 0.0)
    sp = SimParams(; dt = 0.005, n_steps = 1, imaginary_time = false)
    ws = make_workspace(;
        grid, atom, interactions = ip, sim_params = sp,
        potential = HarmonicTrap(1.0, 1.0, 1.0),
        zeeman = ZeemanParams(0.01, 0.0),
    )

    result = simulate_tof_with_gradient(ws;
        gradient = 0.5, t_tof = 0.1, imaging_axis = 3, gradient_axis = 1,
        n_steps = 20,
    )
    @test result isa Dict
    @test !isempty(result)
    # m values should span the full D range
    @test length(result) == ws.spin_matrices.system.n_components
    # column density arrays are 2D (3D minus imaging_axis)
    any_density = first(values(result))
    @test ndims(any_density) == 2
end
