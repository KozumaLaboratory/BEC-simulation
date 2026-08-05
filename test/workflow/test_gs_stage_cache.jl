# The automatic content-addressed GS stage cache (SPINORBEC_STAGE_CACHE).
#
# Cutover step 3 flipped the key from `_gs_cache_key` to `artifact_id` and
# deleted the old function, so this file was split rather than edited:
#
#   DIED WITH THE KEY, and moved to `test/model/test_gs_admission_axes.jl` in a
#   stronger form — the `_hashable` NaN-laundering arms (the recursion is gone;
#   `content_id` still refuses non-finite floats and `gs_ddi`'s NaN reaches it
#   through `DDISpec`'s `nothing`-means-auto union instead), key determinism and
#   format, and the six "sensitive to real physics" probes. Those six are now 31
#   axes with one assertion each, because the claim they were making — that the
#   key sees everything the solve sees — was FALSE for eleven inputs and a
#   six-probe sample could not have found that.
#
#   SURVIVED, and is here: everything about the stage cache as a MECHANISM
#   rather than as a key. The env switches, the store location, the claim that
#   two configs differing only in their `analyze:` block share one ground state
#   (this is what the cache is FOR), and the light-point indirection.
#
# The insensitivity claim survives in a changed form and is worth stating: the
# old key read a hand-picked list of sub-blocks out of `p`, so it was insensitive
# to unknown keys BY CONSTRUCTION. `artifact_id` is built from a `Model` plus a
# declared parameter set, so it is insensitive to them for a different reason —
# nothing outside those two is mapped in. The cross-analyze arm below is the
# end-to-end statement of that, and it is the one that matters.

using Test
using JLD2
using SpinorBEC
using SpinorBEC:
    _gs_stage_dir, _stage_cache_enabled, _light_points_enabled,
    _gs_artifact_id, resolve_gs

@testset "GS stage cache" begin
    @testset "stage dir + flag env" begin
        withenv("SPINORBEC_STAGE_DIR" => "/tmp/spinorbec_stage_probe") do
            @test _gs_stage_dir() == "/tmp/spinorbec_stage_probe"
        end
        # The default location is derived from the store root, not hard-coded.
        withenv("SPINORBEC_STAGE_DIR" => nothing, "SPINORBEC_STORE" => "/tmp/some_store") do
            @test _gs_stage_dir() == joinpath("/tmp/some_store", "_stage", "gs")
        end
        withenv("SPINORBEC_STAGE_CACHE" => "1") do
            @test _stage_cache_enabled()
        end
        withenv("SPINORBEC_STAGE_CACHE" => "0") do
            @test !_stage_cache_enabled()
        end
        withenv("SPINORBEC_LIGHT_POINTS" => "on") do
            @test _light_points_enabled()
        end
        withenv("SPINORBEC_LIGHT_POINTS" => nothing) do
            @test !_light_points_enabled()
        end
    end

    @testset "the id ignores keys that are not inputs to the solve" begin
        # What the deleted "INSENSITIVE to non-physics" arm was really claiming.
        # `cache:` names WHERE an artifact goes and an unknown key names nothing
        # at all; neither changes what is computed, so neither may change the id.
        # (`cache:` also disables the auto path outright, so it can only be
        # observed at the id level, which is why it is checked here.)
        base = Dict{String, Any}(
            "atom" => "Rb87",
            "method" => "itp",
            "grid" => Dict{String, Any}("n" => [16], "box" => [8.0]),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 100, "omega_ref" => 100.0, "c0" => 1.0, "c1" => 0.0),
            "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0]),
            "initial_state" => "polar",
            "n_steps" => 20,
            "dt" => 1.0e-3,
            "tol" => 1.0e-6,
        )
        idof(p) = (q=deepcopy(p);
            _gs_artifact_id(resolve_gs(q, nothing, nothing, nothing; verbose=false), q))
        b = idof(base)
        @test b !== nothing

        noisy = deepcopy(base)
        noisy["cache"] = "/some/explicit/path.jld2"
        noisy["irrelevant_note"] = "hello"
        @test idof(noisy) == b

        # Positive control: the comparison is not trivially true. Moving a knob
        # that IS an input moves it.
        moved = deepcopy(base)
        moved["tol"] = 1.0e-7
        @test idof(moved) != b
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
                # This is the whole purpose of a content-addressed stage store,
                # and it is the property a too-inclusive id would destroy.
                cfgA = joinpath(dir, "a.yaml");
                write(cfgA, base("{energy_decomposition: {}}"))
                cfgB = joinpath(dir, "b.yaml");
                write(cfgB, base("{phase_classify_distance: {}}"))
                withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => stage) do
                    # Isolated base_dir per config so the per-point cache (runs/<hash>)
                    # doesn't short-circuit the GS step on a re-run of the suite.
                    run_yaml(cfgA; base_dir=joinpath(dir, "runsA"), verbose=false)
                    art(d) = filter(f -> endswith(f, ".jld2"), readdir(d))
                    n_after_A = length(art(stage))
                    @test n_after_A == 1                        # one GS artifact cached
                    run_yaml(cfgB; base_dir=joinpath(dir, "runsB"), verbose=false)
                    @test length(art(stage)) == n_after_A       # different analyze → NO new GS
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
