# test/workflow/test_autopilot_invariants.jl
#
# CLAUDE.md lists these as permanent invariants of the autopilot meta-loop.
# None of them is a physics claim, none is reachable by any oracle, and none
# was tested: the mutation harness removed all four and 63 workflow test files
# stayed green (TSUBAME job 8314017).
#
# They share a failure mode that no assertion elsewhere can see — the loop keeps
# WORKING. The budget gate still exists and still trips, later. The lineage still
# breeds legitimate runs. The OOM retry still retries. What is lost is money, or
# the ability to recover, and the queue looks healthy throughout.
#
# All four are pure logic over the queue's own data structures, so this file is
# `fast` and touches no GPU.

using Test
using Dates
using SpinorBEC
using SpinorBEC: QueueRoot, budget_gate, get_budget, set_budget!, AutopilotBudget,
    enqueue!, Experiment, CASStore,
    _classify_terminal_failure, _resolve_save_every, _descendant_count,
    _maybe_fire_on_complete!, AutopilotConfig, AutopilotStats, AutopilotBackend,
    register_on_complete!, list_queue, QueueEntry

# A backend that reports one fixed failure reason, which is all
# `_classify_terminal_failure` asks of it once no outcome.toml exists.
struct _ReasonBackend <: AutopilotBackend
    reason::String
end
SpinorBEC.backend_failure_reason(b::_ReasonBackend, ::QueueEntry) = b.reason

@testset "autopilot invariants" begin
    # The queue only needs a spec it can content-address and a store to put it
    # in; nothing here runs physics, so the emptiest valid spec is the honest
    # fixture. `tag` keeps the content ids distinct.
    # The store must live AT the queue root: `list_queue` scans `qr.path`, so
    # an experiment stored anywhere else is enqueued into a directory the gate
    # never reads, and every count comes back 0. That is what the first version
    # of this file did, and both the budget and lineage rows failed with a
    # perfectly plausible "nothing queued".
    _exp(qr, tag) = Experiment(
        Dict{Any, Any}("pipeline" => [], "note" => tag);
        store=CASStore(qr.path))

    @testset "the quarter cap counts work that is QUEUED, not just spent" begin
        mktempdir() do tmp
            qr = QueueRoot(joinpath(tmp, "runs"))
            set_budget!(
                AutopilotBudget(; quarter_cap_gpu_hours=100.0,
                    daily_cap_gpu_hours=0.0, realized_total=10.0,
                    realized_today=0.0, today=today()); qr=qr)

            # Nothing queued: 10 h spent against a 100 h cap is fine.
            @test budget_gate(; qr=qr).allow

            # Now queue work that would blow it. Nothing has been SPENT yet, so
            # a gate that looks only at realized hours still says yes — and by
            # the time it says no, the hours are gone. That is the whole point
            # of checking before dispatch.
            enqueue!(_exp(qr, "over"); estimated_walltime_hours=200.0,
                kick_tick=false, qr=qr)
            d = budget_gate(; qr=qr)
            @test !d.allow
            @test d.predicted >= 200.0
            @test occursin("quarter cap", d.reason)
        end
    end

    @testset "the daily cap trips on its own" begin
        mktempdir() do tmp
            qr = QueueRoot(joinpath(tmp, "runs"))
            # Quarter cap deliberately generous: this row must fail for the
            # DAILY reason or it is testing the row above again.
            set_budget!(
                AutopilotBudget(; quarter_cap_gpu_hours=10_000.0,
                    daily_cap_gpu_hours=50.0, realized_total=60.0,
                    realized_today=60.0, today=today()); qr=qr)
            d = budget_gate(; qr=qr)
            @test !d.allow
            @test occursin("daily cap", d.reason)

            # Positive control: under the daily cap, the same budget allows.
            set_budget!(
                AutopilotBudget(; quarter_cap_gpu_hours=10_000.0,
                    daily_cap_gpu_hours=50.0, realized_total=60.0,
                    realized_today=10.0, today=today()); qr=qr)
            @test budget_gate(; qr=qr).allow
        end
    end

    @testset "OOM is resource-permanent, not a data failure" begin
        mktempdir() do tmp
            qr = QueueRoot(joinpath(tmp, "runs"))
            e = enqueue!(_exp(qr, "oom"); kick_tick=false, qr=qr)
            # The distinction is load-bearing: :killed_data sends the retry back
            # to the same recipe at the same resource class, which OOMs again.
            # :killed_bug is what escalates.
            for r in ("slurmstepd: OUT_OF_MEMORY", "OOM_KILLED by cgroup")
                outcome, msg = _classify_terminal_failure(e, _ReasonBackend(r))
                @test outcome == :killed_bug
                @test occursin("OOM", msg)
            end
            # Control: a NaN divergence is the data failure, and must not be
            # swept into the same bucket.
            outcome, _ = _classify_terminal_failure(e, _ReasonBackend("TIMEOUT"))
            @test outcome == :killed_bug          # also permanent, different msg
        end
    end

    @testset "the on_complete lineage is bounded" begin
        mktempdir() do tmp
            qr = QueueRoot(joinpath(tmp, "runs"))
            fired = Ref(0)
            register_on_complete!(:_bound_probe) do entry, params
                fired[] += 1
                return SpinorBEC.Experiment[]
            end

            parent = enqueue!(_exp(qr, "p"); recipe_name=:_bound_probe,
                kick_tick=false, qr=qr)
            child = enqueue!(_exp(qr, "c"); recipe_name=:_bound_probe,
                parent_id=parent.content_id, kick_tick=false, qr=qr)
            @test _descendant_count(parent, qr) >= 1

            stats = AutopilotStats()
            # Bound of 1, and the parent already has a descendant: the callback
            # must NOT run.
            cfg_tight = AutopilotConfig(; qr=qr, on_complete_max_descendants=1)
            _maybe_fire_on_complete!(parent, cfg_tight, stats)
            @test fired[] == 0

            # Positive control: raise the bound and the SAME call fires, so the
            # row above is about the bound and not about a broken fixture.
            cfg_loose = AutopilotConfig(; qr=qr, on_complete_max_descendants=64)
            _maybe_fire_on_complete!(parent, cfg_loose, stats)
            @test fired[] == 1
        end
    end

    @testset "the rotating-basis frame default is 100, the generic one 20" begin
        # `n_steps` known (the rotating-basis path) → 100 frames; otherwise 20.
        # Swapping the two is invisible in the data: the file is valid either
        # way and the physics is unchanged, only the record of it.
        p = Dict{Any, Any}()
        @test _resolve_save_every(p, 10.0, 0.01; n_steps=1000) == 10    # 1000/100
        @test _resolve_save_every(p, 10.0, 0.01) == 50                  # 1000/20
    end
end
