# Automatic content-addressed GS stage cache (SPINORBEC_STAGE_CACHE).
# The key `_gs_cache_key` must be a pure function of the RESOLVED ground-state
# physics — stable across configs/analyze blocks, sensitive to real physics
# changes, and never thrown by the NaN the gs_ddi tuple carries for an unset
# ddi_trunc_radius. A regression that folds the analyze block / scan into the
# key (or that throws on non-finite ddi) would silently disable cross-config
# reuse; these probes flip red on that.

using Test
using JLD2
using SpinorBEC
using SpinorBEC: _gs_cache_key, _gs_stage_dir, _hashable, _stage_cache_enabled,
    _light_points_enabled, make_grid, GridConfig, InteractionParams, resolve_atom

@testset "GS stage cache" begin
    atom = resolve_atom(:Eu151)
    grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
    inter = InteractionParams(Dict(0 => 1.0, 1 => 0.03))
    # gs_ddi tuple carries NaN in slot 6 (unset ddi_trunc_radius) — must not throw.
    ddi = (true, 1.0, false, false, 0.0, NaN, false, 2.0)
    p = Dict{String, Any}(
        "initial_state" => "m_plus_F",
        "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
        "B" => Dict("Bz" => "0.0 Gauss"),
    )
    k(; a=atom, g=grid, i=inter, d=ddi, tol=1e-9, ns=2500, dt=1e-3, pp=p) =
        _gs_cache_key(:lbfgs, a, g, i, d, tol, ns, dt, pp)

    @testset "non-finite ddi is hashable (no throw)" begin
        @test _hashable(NaN) isa AbstractString
        @test _hashable(Inf) isa AbstractString
        @test _hashable(0.03) === 0.03
        @test (k(); true)                       # NaN in ddi does not throw
    end

    @testset "determinism + format" begin
        @test k() == k()
        key = k()
        @test key isa AbstractString
        @test length(key) == 16
        @test all(c -> c in "0123456789abcdef", key)
    end

    @testset "sensitivity to real physics" begin
        @test k(i=InteractionParams(Dict(0 => 1.0, 1 => 0.031))) != k()   # c1
        @test k(g=make_grid(GridConfig((32, 32, 32), (8.0, 8.0, 8.0)))) != k()  # grid
        @test k(tol=1e-8) != k()
        @test k(ns=1500) != k()
        let p2 = copy(p)
            p2["initial_state"] = "polar"
            @test k(pp=p2) != k()                                          # seed
        end
        let p3 = copy(p)
            p3["potential"] = Dict("type" => "harmonic", "omega" => [1.0, 1.0, 0.5])
            @test k(pp=p3) != k()                                          # κ (ω_z)
        end
        let p4 = copy(p)
            p4["B"] = Dict("Bz" => "6.0e-5 Gauss")
            @test k(pp=p4) != k()                                          # field
        end
    end

    @testset "INSENSITIVE to non-physics (analyze / metadata / cache in p)" begin
        # The key reads only physics sub-blocks from p; extra keys must not move it.
        #
        # `analyze` is the one that matters and this testset did not have it until
        # 2026-07-30 — the name said "analyze / metadata / cache" while the body
        # added only `cache` and a note, so folding `analyze` into the key escaped
        # the mutation harness. Cross-analyze reuse IS covered further down, but
        # only inside the `SPINORBEC_RUN_HEAVY_YAML` block, which the default suite
        # does not run. Reusing one ground state across several analyze blocks is
        # the cache's whole purpose, so it belongs in the cheap row too.
        let p5 = copy(p)
            p5["cache"] = "/some/explicit/path.jld2"
            p5["irrelevant_note"] = "hello"
            @test k(pp=p5) == k()
        end
        let p6 = copy(p)
            p6["analyze"] = Any[Dict("column_density_movie" => Dict("axis" => 3))]
            @test k(pp=p6) == k()
        end
        let p7 = copy(p)
            p7["analyze"] = Any[Dict("vortex_extraction" => Dict())]
            p7["metadata"] = Dict("operator" => "anko", "note" => "rerun for figure 3")
            @test k(pp=p7) == k()
        end
        # Positive control: the two analyze blocks above really do differ, so a
        # key that folded them in would give three different values.
        let pa = copy(p), pb = copy(p)
            pa["analyze"] = Any[Dict("column_density_movie" => Dict("axis" => 3))]
            pb["analyze"] = Any[Dict("vortex_extraction" => Dict())]
            @test pa["analyze"] != pb["analyze"]
        end
    end

    @testset "stage dir + flag env" begin
        withenv("SPINORBEC_STAGE_DIR" => "/tmp/spinorbec_stage_probe") do
            @test _gs_stage_dir() == "/tmp/spinorbec_stage_probe"
        end
        withenv("SPINORBEC_STAGE_CACHE" => "1") do
            @test _stage_cache_enabled()
        end
        withenv("SPINORBEC_STAGE_CACHE" => "0") do
            @test !_stage_cache_enabled()
        end
    end

    # ── Integration: cross-analyze reuse via run_yaml (heavy; env-guarded) ──
    if lowercase(get(ENV, "SPINORBEC_RUN_HEAVY_YAML", "")) in ("1", "true", "on")
        @testset "run_yaml reuses GS across differing analyze blocks" begin
            mktempdir() do dir
                stage = joinpath(dir, "stage")
                base(an) = """
                defaults: {kind: spinor, backend: cpu}
                pipeline:
                  - ground_state:
                      atom: Eu151
                      interactions: {N_atoms: 5000, omega_ref: 691.1504, c1_ratio: 0.03}
                      grid: {n: [16, 16, 16], box: [8.0, 8.0, 8.0]}
                      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
                      method: lbfgs
                      n_steps: 60
                      tol: 1.0e-7
                  - analyze: [$an]
                """
                # Two configs identical in physics, differing ONLY in the analyze
                # block — the GS must be computed once and reused by the second.
                cfgA = joinpath(dir, "a.yaml");
                write(cfgA, base("{energy_decomposition: {}}"))
                cfgB = joinpath(dir, "b.yaml");
                write(cfgB, base("{phase_classify_distance: {}}"))
                withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => stage) do
                    # Isolated base_dir per config so the per-point cache (runs/<hash>)
                    # doesn't short-circuit the GS step on a re-run of the suite.
                    run_yaml(cfgA; base_dir=joinpath(dir, "runsA"), verbose=false)
                    n_after_A = length(readdir(stage))
                    @test n_after_A == 1                        # one GS artifact cached
                    run_yaml(cfgB; base_dir=joinpath(dir, "runsB"), verbose=false)
                    @test length(readdir(stage)) == n_after_A   # different analyze → NO new GS
                end
            end
        end

        # Stage 1: light points carry a gs_ref (no inline psi); open_result resolves
        # the psi back from the stage store. Old full points stay readable.
        @testset "light points reference stage psi; open_result resolves them" begin
            mktempdir() do dir
                stage = joinpath(dir, "stage")
                cfg = joinpath(dir, "c.yaml")
                write(
                    cfg,
                    """
         defaults: {kind: spinor, backend: cpu}
         pipeline:
           - ground_state:
               atom: Eu151
               interactions: {N_atoms: 5000, omega_ref: 691.1504, c1_ratio: 0.03}
               grid: {n: [16, 16, 16], box: [8.0, 8.0, 8.0]}
               potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
               method: lbfgs
               n_steps: 50
               tol: 1.0e-7
           - analyze: [{energy_decomposition: {}}]
         scan:
           product: {pipeline.0.interactions.c1_ratio: {from: 0.030, to: 0.031, n: 2}}
         """,
                )
                withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_LIGHT_POINTS" => "1",
                    "SPINORBEC_STAGE_DIR" => stage) do
                    rd = run_yaml(cfg; base_dir=joinpath(dir, "runs"), verbose=false)
                    is_point(f) = startswith(f, "point_") && endswith(f, ".jld2")
                    pts = sort(filter(is_point, readdir(rd)))
                    @test length(pts) == 2
                    p1 = joinpath(rd, pts[1])
                    d = JLD2.load(p1)
                    @test haskey(d, "gs_ref")          # light: pointer present
                    @test !haskey(d, "psi")            # light: no inline psi
                    @test haskey(d, "energy")          # scalars stay inline
                    # open_result transparently resolves psi from the stage store.
                    r = open_result(p1)
                    @test size(r.psi, 4) == 13         # Eu F=6 → 13 components
                    @test all(isfinite, abs.(r.psi))
                    @test isfile(joinpath(stage, String(d["gs_ref"]) * ".jld2"))
                    # summary scalars carry the rotation-invariant order param mF,
                    # so a phase scan reads it without loading psi.
                    bag = SpinorBEC.run_scalar_summary(r)
                    @test haskey(bag, "mF")
                    @test 0.0 <= bag["mF"] <= 1.0 + 1e-9
                end
            end
        end
    end
end
