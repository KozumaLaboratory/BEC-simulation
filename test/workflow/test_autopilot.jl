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
    end
end
