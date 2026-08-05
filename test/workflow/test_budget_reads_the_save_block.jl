using Test
using SpinorBEC
using YAML

# The budget must read the keys configs actually carry.
#
# `estimate_run_budget` read `save_every` and `save_snapshot_compression` — the
# pre-2026 flat spellings — while the schema had folded them into `save:` and
# now REJECTS them (`SAVE_SCHEMA`, `schema.jl:123-130`). So the `get(…, 1)`
# default fired on every config that exists. Measured on
# `runs/matsui_fig4b/fig4b_scan_n64.yaml`, which carries `save: {every: 108}`
# over 3456 steps:
#
#     before   every = 1    ->  3456 snapshots
#     after    every = 108  ->    32 snapshots      (108x)
#
# The same function was already half-migrated: `save_psi` two lines down read
# the new block while these two read the old keys. That is the tell — one
# function, two vocabularies.

@testset "budget reads the save: block" begin
    root = normpath(joinpath(@__DIR__, "..", ".."))

    @testset "a real config's cadence is honoured" begin
        cfg = joinpath(root, "runs", "matsui_fig4b", "fig4b_scan_n64.yaml")
        if !isfile(cfg)
            @test_skip "fixture config not present"
        else
            d = YAML.load_file(cfg)
            dyn = only(st["dynamics"] for st in d["pipeline"] if haskey(st, "dynamics"))
            every = Int(dyn["save"]["every"])
            n_steps = round(Int, Float64(dyn["duration"]) / Float64(dyn["dt"]))
            @test every > 1                      # or this fixture proves nothing
            b = estimate_run_budget(cfg; io=devnull)
            @test b.total_steps == n_steps
            @test b.total_snapshots == max(1, n_steps ÷ every)
            # …and specifically NOT the every=1 answer the bug produced.
            @test b.total_snapshots != n_steps
        end
    end

    @testset "n_snapshots is honoured too, and compression comes from save:" begin
        mktempdir() do dir
            p = joinpath(dir, "c.yaml")
            # `estimate_run_budget` needs a ground_state step to infer the
            # grid ("No ground_state step — can't infer grid"), so a bare
            # dynamics fixture cannot exercise it.
            write(
                p,
                """
       pipeline:
         - ground_state:
             atom: Rb87
             grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
             interactions: {N_atoms: 1000, omega_ref: 100.0, c1_ratio: -0.01}
             potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
             method: itp
             n_steps: 5
             dt: 0.001
         - dynamics:
             duration: 10.0
             dt: 0.01
             save: {n_snapshots: 25, psi: true, compression: true}
       """,
            )
            b = estimate_run_budget(p; io=devnull)
            @test b.total_steps == 1000
            @test b.total_snapshots == 25
            @test b.save_psi
            @test b.save_compressed
        end
    end

    # POSITIVE CONTROL. The equalities above are satisfied by a function that
    # ignores the block entirely IF the numbers happen to line up, so pin that
    # the cadence actually MOVES the answer.
    @testset "positive control: the cadence changes the count" begin
        mk(body) = begin
            d = mktempdir()
            p = joinpath(d, "c.yaml")
            write(
                p,
                """
       pipeline:
         - ground_state:
             atom: Rb87
             grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
             interactions: {N_atoms: 1000, omega_ref: 100.0, c1_ratio: -0.01}
             potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
             method: itp
             n_steps: 5
             dt: 0.001
         - dynamics:
             duration: 10.0
             dt: 0.01
             save: $body
       """,
            )
            estimate_run_budget(p; io=devnull)
        end
        @test mk("{every: 10}").total_snapshots == 100
        @test mk("{every: 100}").total_snapshots == 10
        @test mk("{every: 10}").total_snapshots != mk("{every: 100}").total_snapshots
    end
end
