# The writer / admission sites that every YAML SCAN and every `Experiment`
# actually uses. Same shape as step 1's finding M10: the sites production runs
# on were the ones nothing tested.
#
# The 2026-08-01 canary pass corrupted four of them and every suite stayed green:
#
#   D1  scan-loop admission reverted to `isfile`  (`run_registry.jl:491`)
#   D2  the scan loop's `_finish_point!` deleted  (`run_registry.jl:616`)
#   D3b `Experiment._admitted_result_path` reverted to `isfile`, seen through
#       `_has_result` (`experiment.jl:194`, the `run!` / constructor predicate)
#   D4b the same, seen through `_result_path_or_nothing` (`experiment.jl:260`,
#       the predicate every observable goes through)
#
# `test_admission_requires_marker.jl` cannot reach any of them: it calls
# `_run_step(GroundStateStep(...))` directly, so it exercises the GS stage
# store and nothing else. `test_interrupted_run_recomputes.jl` reaches the
# SINGLE-point writer only.
#
# The same run also pins the `point_001.jld2` alias
# (`save_rotating_result.jl:451`), a pre-existing data-integrity bug that step 2
# surfaced rather than caused: `run_pipeline` calls `save_rotating_basis_result!`
# once per scan point, and the unconditional `rm` it used to do deleted the real
# `point_001.jld2` and re-pointed the name at the LAST point's `result.jld2`.
# Verified in the store: 3 symlinked `point_001.jld2` under `runs/`, one of them
# in `runs/eu151_edh_k3_compare`, a 3-point scan.

using Test
using JLD2
using YAML
using SpinorBEC
using SpinorBEC: marker_path, incomplete_marker_path, admit_payload,
    read_complete_marker, write_complete_marker, write_incomplete_marker,
    PayloadEntry, _has_result, _admitted_result_path, _result_path_or_nothing,
    _result_path, _reset_unmarked_warnings!

# No solver produces this. From the moment it is planted, reading it back means
# "admission served this file"; not reading it back means "this point was
# recomputed".
const SCAN_SENTINEL_E = -98765.4321

# Two points differing in an input that MOVES the answer, so a recomputed point
# is distinguishable from its NEIGHBOUR and not merely from the sentinel.
#
# The scan axis is `N_atoms` and not `c0`, measured: `_parse_gs_interactions`
# (`schema/parsing_blocks.jl:374`) takes the `N_atoms` + `omega_ref` branch when
# both are present and derives `c_total` from the atom, so `c0:` / `c1:` are
# IGNORED in that shape — a `c0` scan ran both points at the same physics and
# came back with identical energies to the last digit. Same footgun as the
# `c1_ratio`-in-a-ground_state-step arm that voided a Matsui comparison.
scan_probe_yaml(; dynamics::Bool=false) = """
scan:
  zip:
    pipeline.0.interactions.N_atoms: [100, 2000]

defaults: {kind: spinor, backend: cpu}
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [16], box: [8.0]}
      potential: {type: harmonic, omega: [1.0]}
      interactions: {N_atoms: 100, omega_ref: 100.0}
      ddi: {enabled: false}
      lhy: {kind: none}
      initial_state: polar
      method: itp
      n_steps: 40
      dt: 1.0e-3
      tol: 1.0e-6
""" * (dynamics ? """
  - dynamics:
      duration: 0.01
      dt: 0.001
      live_monitor: false
      save: {every: 5}
""" : "")

# Rewrite the payload in place with a sentinel energy, preserving every other
# dataset (the scan loop's continuation branch reads `psi` / `mz_actual` back
# out of it). `remark` controls whether the marker is refreshed to agree.
function plant_point_sentinel!(path; remark::Bool=true)
    d = JLD2.load(path)
    d["energy"] = SCAN_SENTINEL_E
    jldopen(path, "w") do f
        for k in sort!(collect(keys(d)))
            f[k] = d[k]
        end
    end
    rm(marker_path(path); force=true)
    rm(incomplete_marker_path(path); force=true)
    remark && write_complete_marker(path, [path]; kind="point")
    path
end

# Corrupt the MARKER, not the payload: if admission wrongly served the file the
# sentinel comes back and that is a clean `@test` failure, where truncating the
# jld2 would make a wrong admission throw inside JLD2 instead.
function disagree_marker!(path)
    m = read_complete_marker(marker_path(path))
    write(marker_path(path),
        "format = 1\nkind = \"$(m.kind)\"\nwritten_at = \"$(m.written_at)\"\n\n" *
        "[[payload]]\nbytes = $(filesize(path) + 1)\npath = \"$(basename(path))\"\n")
    @assert !admit_payload(path).hit
    path
end

energy_of(p) = JLD2.load(p)["energy"]

@testset "the SCAN path's admission and marker writer" begin
    mktempdir() do dir
        y = joinpath(dir, "scan.yaml")
        write(y, scan_probe_yaml())
        run_scan() = run_yaml(y; base_dir=joinpath(dir, "out"), verbose=false)

        rd = run_scan()
        p1 = joinpath(rd, "point_001.jld2")
        p2 = joinpath(rd, "point_002.jld2")
        @test isfile(p1) && isfile(p2)
        real_E1, real_E2 = energy_of(p1), energy_of(p2)
        # The two points are genuinely different cells; without this the
        # "only the corrupted point recomputed" arms below would be vacuous.
        @test real_E1 != real_E2

        @testset "D2: every scan point is marked, by the bytes it wrote" begin
            for (p, name) in ((p1, "point_001.jld2"), (p2, "point_002.jld2"))
                @test isfile(marker_path(p))
                @test !isfile(incomplete_marker_path(p))
                m = read_complete_marker(marker_path(p))
                @test m.kind == "point"
                # Named, not merely present: the size is the payload's own, and
                # the path is relative so the directory survives an rsync.
                @test m.payload == [PayloadEntry(name, filesize(p))]
                @test m.code_rev == SpinorBEC.code_tree_hash()
                @test admit_payload(p).provenance === :marked
            end
        end

        @testset "D1: the scan loop admits via `admit_payload`, not `isfile`" begin
            # POSITIVE CONTROL. A marked point is SERVED — so "it recomputed"
            # below cannot be explained by an admission that recomputes always.
            plant_point_sentinel!(p1)
            plant_point_sentinel!(p2)
            run_scan()
            @test energy_of(p1) == SCAN_SENTINEL_E
            @test energy_of(p2) == SCAN_SENTINEL_E

            @testset "a marker that DISAGREES with the bytes recomputes that point" begin
                disagree_marker!(p2)
                run_scan()
                @test energy_of(p1) == SCAN_SENTINEL_E    # untouched neighbour
                @test energy_of(p2) == real_E2            # recomputed, to its OWN value
                @test admit_payload(p2).provenance === :marked
                @test read_complete_marker(marker_path(p2)).payload[1].bytes ==
                    filesize(p2)
            end

            @testset "a TOMBSTONE recomputes that point and then clears" begin
                plant_point_sentinel!(p2)
                write_incomplete_marker(p1, [p1];
                    kind="point", reason="canary: killed mid-solve")
                run_scan()
                @test energy_of(p2) == SCAN_SENTINEL_E    # untouched neighbour
                @test energy_of(p1) == real_E1            # recomputed
                @test !isfile(incomplete_marker_path(p1))
                @test admit_payload(p1).provenance === :marked
            end

            @testset "arm (b): an UNMARKED legacy point is still served" begin
                _reset_unmarked_warnings!()
                plant_point_sentinel!(p1; remark=false)
                @test !isfile(marker_path(p1))
                run_scan()
                @test energy_of(p1) == SCAN_SENTINEL_E
                @test admit_payload(p1).provenance === :unmarked
            end
        end
    end
end

@testset "D3/D4: `Experiment` admits via `admit_payload`, not `isfile`" begin
    mktempdir() do root
        # A real `Experiment`, so the two predicates are reached through the
        # code path `run!` and every observable use, not by calling the private
        # helper directly.
        exp = Experiment(Dict{Any, Any}("probe" => "admitted_result_path");
            store=CASStore(root))
        dir = outdir(exp)
        mkpath(dir)
        res = joinpath(dir, "result.jld2")
        jldopen(res, "w") do f
            f["psi"] = ComplexF64[1.0, 2.0, 3.0]
        end

        @testset "arm (b): an unmarked payload is still admitted" begin
            _reset_unmarked_warnings!()
            @test _has_result(dir)
            @test _result_path_or_nothing(exp) == res
        end

        @testset "a valid marker is admitted" begin
            write_complete_marker(res, [res]; kind="dynamics")
            @test _has_result(dir)
            @test _result_path_or_nothing(exp) == res
            @test _result_path(exp) == res
        end

        @testset "a marker that DISAGREES is a miss on BOTH predicates" begin
            disagree_marker!(res)
            @test !_has_result(dir)                     # D3b
            @test _result_path_or_nothing(exp) === nothing   # D4b
            @test_throws ArgumentError _result_path(exp)
            # The bytes are still there. This is admission refusing to serve
            # them, not a file that went missing — which is the whole point of
            # `:rejected` being a distinct provenance from `:absent`.
            @test isfile(res)
        end

        @testset "a TOMBSTONE is a miss on both predicates" begin
            rm(marker_path(res); force=true)
            write_incomplete_marker(res, [res];
                kind="dynamics", reason="canary: killed mid-evolution")
            @test !_has_result(dir)
            @test _result_path_or_nothing(exp) === nothing
        end

        @testset "a rejection poisons the WHOLE directory" begin
            # `_RESULT_NAMES` has two entries and `save_rotating_basis_result!`
            # can make the second an alias of the first. If a rejected candidate
            # merely fell through to the next one, the alias naming those exact
            # bytes would be served and the rejection would achieve nothing. The
            # order matters: `result.jld2` is checked FIRST and admits cleanly
            # here, so only a loop that keeps going can see the bad second name.
            _reset_unmarked_warnings!()
            rm(incomplete_marker_path(res); force=true)
            write_complete_marker(res, [res]; kind="dynamics")
            @test _has_result(dir)                      # control: it admits

            alias = joinpath(dir, "point_001.jld2")
            cp(res, alias; force=true)
            write_complete_marker(alias, [alias]; kind="point")
            disagree_marker!(alias)
            @test !_has_result(dir)
            @test _result_path_or_nothing(exp) === nothing

            rm(alias)
            rm(marker_path(alias); force=true)
            @test _has_result(dir)                      # ...and it recovers
        end
    end
end

@testset "G4: a scan's `point_001.jld2` holds POINT 1, not the last point" begin
    mktempdir() do dir
        y = joinpath(dir, "scan_dyn.yaml")
        write(y, scan_probe_yaml(; dynamics=true))
        rd = run_yaml(y; base_dir=joinpath(dir, "out"), verbose=false)
        p1 = joinpath(rd, "point_001.jld2")
        p2 = joinpath(rd, "point_002.jld2")
        res = joinpath(rd, "result.jld2")

        # The dynamics auto-save fired (otherwise the alias is never written and
        # this whole testset is vacuous).
        @test isfile(res)
        @test haskey(JLD2.load(res), "dynamics/times")

        # THE assertion. Before the fix this was a symlink to `result.jld2`,
        # i.e. to the LAST point's dynamics, and the scan writer's real point-1
        # payload had been deleted.
        @test !islink(p1)
        d1 = JLD2.load(p1)
        d2 = JLD2.load(p2)
        @test d1["scan_index"] == 1
        @test d2["scan_index"] == 2
        # The two cells differ in N_atoms, so "point 1's data" is a statement
        # about the number and not only about the recorded index.
        @test d1["energy"] != d2["energy"]
        # A point payload, not the dynamics result wearing its name. Both files
        # carry a `dynamics/` group (the point writer embeds its own step's
        # trace via `_save_dynamics_timeseries!`), so the discriminator is
        # `scan_index`, which only the point writer writes.
        @test haskey(d1, "psi")
        @test !haskey(JLD2.load(res), "scan_index")

        # ...and the marker written for point 1 still certifies point 1's bytes.
        # Under the clobber it named a file that had been replaced by a symlink
        # to a different size, so admission REJECTED point 1 — which is how the
        # pre-existing bug surfaced.
        @test admit_payload(p1).provenance === :marked
        @test read_complete_marker(marker_path(p1)).payload[1].bytes == filesize(p1)
        @test admit_payload(p2).provenance === :marked
    end
end

@testset "G4: the single-run alias is still published when nothing owns the name" begin
    # The alias exists for the dashboard's run-list filter, and the fix must not
    # delete it for the case it was added for: a run whose dynamics auto-save
    # lands in a directory with no point file at all.
    mktempdir() do dir
        res = joinpath(dir, "result.jld2")
        result = Dict{Symbol, Any}(
            :dynamics_history => [(
                dynamics_result=SimulationResult([0.0, 0.1], [1.0, 1.0], [1.0, 1.0],
                    [0.0, 0.0], Array{ComplexF64}[]),
                snapshot_tmp_path=nothing, save_psi_snapshots=false,
                snapshot_count=0, ensemble_result=nothing)],
        )
        save_rotating_basis_result!(dir, result)
        link = joinpath(dir, "point_001.jld2")
        @test islink(link)
        @test readlink(link) == "result.jld2"
        @test isfile(res)

        # A second save (the multi-point case) must leave a REAL file alone.
        rm(link)
        write(link, "not a symlink")
        save_rotating_basis_result!(dir, result)
        @test !islink(link)
        @test read(link, String) == "not a symlink"
    end
end
