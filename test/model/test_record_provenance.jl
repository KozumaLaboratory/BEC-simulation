# Cutover step 1's deliverable, at the two writer sites a YAML run actually
# uses, plus the reader that has to let the ids through.
#
# THREE places write `code_rev` / `artifact_id`: the stage artifact
# (`run_step_ground_state.jl`), the scan point (`run_registry.jl`) and the single
# point (`run_registry.jl`). `test_admission_requires_marker.jl`
# calls `_run_step(GroundStateStep(...))` directly, so it reaches the first and
# only the first — deleting both `run_registry.jl` blocks left every model suite
# green. Those two are the ones every `run_yaml` goes through, i.e. the ones a
# production run's provenance actually depends on.
#
# `open_result`'s metadata whitelist is gated here for the same reason and in the
# same run: the writers can record perfectly and the reader still drop the keys
# on the floor. Removing `"code_rev"` and the id key from `_extract_metadata`
# also left everything green.
#
# The id key was spelled `gs_cache_key` through cutover steps 1 and 2, because
# the value was `_gs_cache_key`'s. Step 3 deleted that function and admission
# moved to `artifact_id`, so the dataset is renamed with it rather than kept as
# an alias for something that no longer exists.
#
# A real round trip, kept as small as one can be: 1-D, 16 points, 20 ITP steps,
# CPU, Rb87, and the scan's first point is served from the stage artifact the
# single-point run already wrote.

using Test
using JLD2
using SpinorBEC
using SpinorBEC: code_tree_hash, open_result

const PROBE_PIPELINE = """
defaults: {kind: spinor, backend: cpu}
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [16], box: [8.0]}
      potential: {type: harmonic, omega: [1.0]}
      interactions: {N_atoms: 100, omega_ref: 100.0, c0: 1.0, c1: 0.0}
      ddi: {enabled: false}
      lhy: {kind: none}
      initial_state: polar
      method: itp
      n_steps: 20
      dt: 1.0e-3
      tol: 1.0e-6
"""

# Two points, differing in an input `artifact_id` reads — so the two records
# must carry two different `artifact_id`s and one shared `code_rev`.
const PROBE_SCAN = """
scan:
  zip:
    pipeline.0.tol: [1.0e-6, 1.0e-7]

""" * PROBE_PIPELINE

@testset "a run's record carries both ids (cutover step 1)" begin
    mktempdir() do dir
        stage_dir = joinpath(dir, "stage")
        mkpath(stage_dir)
        run_probe(yaml_text, name) = withenv("SPINORBEC_STAGE_CACHE" => "1",
            "SPINORBEC_STAGE_DIR" => stage_dir) do
            y = joinpath(dir, "$name.yaml")
            write(y, yaml_text)
            run_yaml(y; base_dir=joinpath(dir, "out_$name"), verbose=false)
        end

        code_rev = code_tree_hash()

        @testset "single-point path (`_run_yaml_single`)" begin
            rd = run_probe(PROBE_PIPELINE, "single")
            p = joinpath(rd, "point_001.jld2")
            @test isfile(p)
            d = JLD2.load(p)
            @test haskey(d, "code_rev")
            @test d["code_rev"] == code_rev
            @test length(d["code_rev"]) == 64
            @test haskey(d, "artifact_id")
            @test d["artifact_id"] isa AbstractString
            @test length(d["artifact_id"]) == 16
            # Not merely a string: it is the id that named the stage artifact,
            # so a record whose key pointed at nothing would fail here.
            @test isfile(joinpath(stage_dir, d["artifact_id"] * ".jld2"))

            @testset "the reader lets both ids through (`_extract_metadata`)" begin
                r = open_result(p)
                @test r.metadata["code_rev"] == code_rev
                @test r.metadata["artifact_id"] == d["artifact_id"]
                # Negative control on the whitelist: it selects, it does not
                # copy. `grid_box_size` is written by the same block, three
                # lines away, and must NOT arrive — without this the two
                # assertions above would also pass under a wholesale copy,
                # which is not what the reader does.
                @test haskey(d, "grid_box_size")
                @test !haskey(r.metadata, "grid_box_size")
                @test !haskey(r.metadata, "psi")
            end
        end

        @testset "scan path (`_run_yaml_scan`)" begin
            rd = run_probe(PROBE_SCAN, "scan")
            p1 = joinpath(rd, "point_001.jld2")
            p2 = joinpath(rd, "point_002.jld2")
            @test isfile(p1)
            @test isfile(p2)
            d1, d2 = JLD2.load(p1), JLD2.load(p2)
            for d in (d1, d2)
                @test haskey(d, "code_rev")
                @test d["code_rev"] == code_rev
                @test haskey(d, "artifact_id")
                @test length(d["artifact_id"]) == 16
                @test isfile(joinpath(stage_dir, d["artifact_id"] * ".jld2"))
            end
            # Per-point, not a constant: the two points differ in `tol`, which
            # is an input the admission id reads. An `artifact_id` written
            # once and copied would pass every assertion above.
            @test d1["artifact_id"] != d2["artifact_id"]
            @test open_result(p1).metadata["artifact_id"] == d1["artifact_id"]
            @test open_result(p2).metadata["artifact_id"] == d2["artifact_id"]
        end
    end
end
