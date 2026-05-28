using Test
using Dates
using JSON
using TOML
using SpinorBEC
using SpinorBEC: QueueEntry, _entry_to_toml_dict, _entry_from_toml_dict,
    _is_divergent, _maybe_fire_on_complete!, OUTCOME_FILENAME,
    RUN_STATE_FILENAME

@testset "autopilot" begin
    mktempdir() do tmp
        qr = SpinorBEC.QueueRoot(joinpath(tmp, "runs"))
        SpinorBEC.autopilot_queue_root(qr)
        store = SpinorBEC.CASStore(qr.path)

        @testset "queue entry round-trip via TOML" begin
            run_dir = joinpath(qr.path, "abc123def456")
            mkpath(run_dir)
            spec_path = joinpath(run_dir, "config.yaml")
            touch(spec_path)
            e = QueueEntry("abc123def456";
                run_dir=run_dir, spec_path=spec_path,
                priority=3, enqueued_by="testing",
                recipe_name=:my_cb,
                recipe_params=Dict{String, Any}("step" => 2),
                parent_id="xyz789",
                job_id="42", profile="single_h100",
                autonomy_level=:propose)
            d = _entry_to_toml_dict(e)
            e2 = _entry_from_toml_dict(d, run_dir)
            @test e2.content_id == "abc123def456"
            @test e2.priority == 3
            @test e2.enqueued_by == "testing"
            @test e2.recipe_name === :my_cb
            @test e2.recipe_params["step"] == 2
            @test e2.parent_id == "xyz789"
            @test e2.job_id == "42"
            @test e2.profile == "single_h100"
            @test e2.autonomy_level === :propose
            @test e2.status === :pending
        end

        @testset "enqueue! + list_queue + set_status!" begin
            spec = Dict{Any, Any}("pipeline" => [])
            exp = SpinorBEC.Experiment(spec; store=store)
            e = enqueue!(exp; priority=4, enqueued_by="unit-test")
            @test e.status === :pending
            @test isfile(joinpath(e.run_dir, RUN_STATE_FILENAME))

            pending = list_queue(:pending; qr=qr)
            @test length(pending) == 1
            @test pending[1].priority == 4

            set_status!(e, :running)
            @test length(list_queue(:pending; qr=qr)) == 0
            @test length(list_queue(:running; qr=qr)) == 1

            set_status!(e, :killed_data; kill_reason="test divergence")
            @test e.status === :killed_data
            @test e.kill_reason == "test divergence"
            @test length(list_queue(:killed_data; qr=qr)) == 1
        end

        @testset "is_divergent_status" begin
            @test !is_divergent_status(Dict("norm_drift" => 1e-5))
            @test is_divergent_status(Dict("norm_drift" => 0.5))
            @test is_divergent_status(Dict("classify" => "collapse"))
            @test !is_divergent_status(Dict("classify" => "stable"))
            @test is_divergent_status(Dict("fz_jump" => 2.0))
        end

        @testset "classify_failure" begin
            @test classify_failure(Dict("nan_encountered" => true), "") ===
                SpinorBEC.PERMANENT
            @test classify_failure(
                Dict("exception_type" => "InterruptException"), "") ===
                SpinorBEC.TRANSIENT
            @test classify_failure(
                Dict("exception_type" => "ArgumentError"), "") ===
                SpinorBEC.PERMANENT
            @test classify_failure(Dict(), "OUT_OF_MEMORY|...") ===
                SpinorBEC.RESOURCE_PERMANENT
            @test classify_failure(Dict(), "TIMEOUT|...") ===
                SpinorBEC.RESOURCE_PERMANENT
            @test classify_failure(Dict(), "NODE_FAIL|...") ===
                SpinorBEC.TRANSIENT
            @test classify_failure(Dict(), "") === SpinorBEC.UNKNOWN_CLASS
        end

        @testset "on_complete registry" begin
            counter = Ref(0)
            register_on_complete!(:test_cb) do entry
                counter[] += 1
                return nothing
            end
            @test haskey(on_complete_registry(), :test_cb)
            run_dir = joinpath(qr.path, "zzz_test")
            mkpath(run_dir)
            spec_path = joinpath(run_dir, "config.yaml")
            touch(spec_path)
            e = QueueEntry("zzz_test"; run_dir=run_dir, spec_path=spec_path,
                recipe_name=:test_cb)
            SpinorBEC.on_complete_call(:test_cb, e)
            @test counter[] == 1
            @test isempty(SpinorBEC.on_complete_call(:no_such, e))
        end

        @testset "with_autopilot_lock" begin
            results = String[]
            with_autopilot_lock(; qr=qr) do
                push!(results, "in-critical-section")
            end
            @test results == ["in-critical-section"]
            # Lock released after block
            @test !isfile(joinpath(qr.path, ".autopilot.lock"))
        end

        @testset "autopilot_tick! empty queue is a no-op" begin
            stats = autopilot_tick!(;
                config=default_autopilot_config(;
                    qr=qr, inspect_before_dispatch=false))
            @test stats.dispatched == 0
            @test stats.completed == 0
        end

        @testset "pause sentinel halts dispatch" begin
            touch(joinpath(qr.path, ".autopilot.paused"))
            @test is_autopilot_paused(qr)
            rm(joinpath(qr.path, ".autopilot.paused"); force=true)
            @test !is_autopilot_paused(qr)
        end

        @testset "dry-run fires on_complete chain (recipe fan-out)" begin
            # Regression for the 2026-05-28 observation: pre-fix, the
            # dry-run path bypassed _maybe_fire_on_complete! because it
            # advanced :pending → :done in-line, never letting the reap
            # loop see :running. Recipes registered against a parent
            # silently produced no children under dry-run, masking the
            # main value of the observation lap.

            # Fresh root so this test is independent of any state above.
            mktempdir() do tmp
                local_qr = SpinorBEC.QueueRoot(joinpath(tmp, "runs"))
                local_store = SpinorBEC.CASStore(local_qr.path)

                # Recipe that spawns exactly one child per invocation,
                # tagged so we can find it. Stop at depth 1 to avoid
                # unbounded fan-out in the test.
                spawn_count = Ref(0)
                register_on_complete!(:_dryrun_test_recipe) do entry, params
                    spawn_count[] += 1
                    depth = Int(get(params, "depth", 0))
                    depth >= 1 && return nothing
                    child_spec = deepcopy(entry.spec_path)
                    # Distinct content by tweaking a non-load-bearing
                    # field; here we just clone the YAML byte-for-byte
                    # but with a unique enqueued_by tag downstream.
                    new_spec = Dict{Any, Any}(
                        "pipeline" => [Dict("ground_state" =>
                            Dict("_dryrun_child_tag" => spawn_count[]))],
                    )
                    [SpinorBEC.Experiment(new_spec; store=local_store)]
                end

                parent_spec = Dict{Any, Any}(
                    "pipeline" => [Dict("ground_state" =>
                        Dict("_dryrun_parent_tag" => 1))],
                )
                parent = SpinorBEC.Experiment(parent_spec; store=local_store)
                e = enqueue!(parent;
                    recipe_name=:_dryrun_test_recipe,
                    recipe_params=Dict{String, Any}("depth" => 0),
                    autonomy_level=:dispatch,
                    qr=local_qr)

                # Tick under dry-run via the persistent sentinel.
                touch(joinpath(local_qr.path, ".autopilot.dry_run"))
                @test is_autopilot_dry_run(local_qr)

                cfg = default_autopilot_config(;
                    qr=local_qr, inspect_before_dispatch=false)
                stats1 = autopilot_tick!(; config=cfg)

                @test stats1.dispatched == 1
                @test stats1.completed == 1
                @test spawn_count[] == 1
                @test stats1.on_complete_fired == 1

                # Parent done, child pending.
                @test length(list_queue(:done; qr=local_qr)) == 1
                @test length(list_queue(:pending; qr=local_qr)) == 1

                rm(joinpath(local_qr.path, ".autopilot.dry_run"); force=true)
            end
        end

        @testset "backfill_group_ids! clusters legacy lineage" begin
            # Entries enqueued before group_id inheritance deserialize with
            # group_id == their own content_id (each its own singleton).
            # backfill walks parent_id to the lineage root and adopts the
            # root's group_id, reconstructing what inheritance would produce.
            mktempdir() do tmp
                local_qr = SpinorBEC.QueueRoot(joinpath(tmp, "runs"))

                function _legacy_entry(cid, parent)
                    rd = joinpath(local_qr.path, cid)
                    mkpath(rd)
                    sp = joinpath(rd, "config.yaml")
                    touch(sp)
                    e = QueueEntry(cid; run_dir=rd, spec_path=sp,
                        parent_id=parent, group_id="")  # empty → own cid
                    save_entry!(e)
                    e
                end

                r = _legacy_entry("rootaaaaaaaaaaaa", nothing)
                c1 = _legacy_entry("child1bbbbbbbbbb", "rootaaaaaaaaaaaa")
                c2 = _legacy_entry("child2cccccccccc", "child1bbbbbbbbbb")
                s = _legacy_entry("standaloneddddd", nothing)

                # Pre-state: scattered (each is its own group).
                @test get_entry(c1.run_dir).group_id == "child1bbbbbbbbbb"

                changes = backfill_group_ids!(; qr=local_qr)
                @test length(changes) == 2  # c1, c2 reassigned; r, s untouched

                @test get_entry(r.run_dir).group_id == "rootaaaaaaaaaaaa"
                @test get_entry(c1.run_dir).group_id == "rootaaaaaaaaaaaa"
                @test get_entry(c2.run_dir).group_id == "rootaaaaaaaaaaaa"
                @test get_entry(s.run_dir).group_id == "standaloneddddd"

                # Idempotent: a second pass is a no-op.
                @test isempty(backfill_group_ids!(; qr=local_qr))
            end
        end
    end
end
