using Test
using Dates
using JSON
using TOML
using SpinorBEC
using SpinorBEC: QueueEntry, _entry_to_toml_dict, _entry_from_toml_dict,
    _is_divergent, _maybe_fire_on_complete!, OUTCOME_FILENAME,
    RUN_STATE_FILENAME,
    AutopilotConfig, AutopilotBackend, LocalBackend, UGEBackend,
    resolve_backend, stage_in, pull_live, collect!,
    UGE_PROFILE_DIRECTIVES, UGE_PROFILE_ESCALATION,
    next_profile, render_uge_script,
    _uge_remote_run_dir, _uge_remote_spec_path, _uge_jobname,
    _uge_mkdir_cmd, _uge_rsync_config_cmd, _uge_pull_live_cmd,
    _uge_collect_cmd, _uge_rsync_script_cmd, _uge_code_sync_cmd,
    _uge_qsub_cmd, _uge_qstat_cmd, _uge_qdel_cmd, _uge_qstat_list_cmd,
    _uge_qacct_cmd, _parse_qsub_jobid, _uge_extract_job_state_from_listing

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
            e = enqueue!(exp; priority=4, enqueued_by="unit-test", kick_tick=false)
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
                # Recipe spawns exactly one child on first invocation
                # (the parent), then returns nothing on every subsequent
                # call so the in-tick 2nd dispatch pass terminates at
                # parent+child rather than running until lineage cap.
                spawn_count = Ref(0)
                register_on_complete!(:_dryrun_test_recipe) do entry, params
                    if spawn_count[] >= 1
                        return nothing   # stop after the parent spawn
                    end
                    spawn_count[] += 1
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
                    qr=local_qr,
                    kick_tick=false)

                # Tick under dry-run via the persistent sentinel.
                touch(joinpath(local_qr.path, ".autopilot.dry_run"))
                @test is_autopilot_dry_run(local_qr)

                cfg = default_autopilot_config(;
                    qr=local_qr, inspect_before_dispatch=false)
                stats1 = autopilot_tick!(; config=cfg)

                # New semantics (2026-05-31): the in-tick 2nd dispatch
                # pass picks up on_complete children in the SAME tick.
                # Parent and child both dispatch + complete + land in
                # :done — no leftover :pending. spawn_count and
                # on_complete_fired are 1 because the recipe early-
                # returns for the child invocation.
                @test stats1.dispatched == 2
                @test stats1.completed == 2
                @test spawn_count[] == 1
                @test stats1.on_complete_fired == 1
                @test length(list_queue(:done; qr=local_qr)) == 2
                @test length(list_queue(:pending; qr=local_qr)) == 0

                rm(joinpath(local_qr.path, ".autopilot.dry_run"); force=true)
            end
        end

        @testset "AutopilotConfig backend registry" begin
            local_b = LocalBackend()
            uge_b = UGEBackend(ssh_host="example.tld",
                remote_runs_root="/scratch/runs",
                compute_group="tga-test")

            # Primary form: explicit registry. Mixed-typed backends are
            # held under one Dict{Symbol,AutopilotBackend} so per-entry
            # dispatch can route to the right concrete type.
            cfg = AutopilotConfig(;
                backends=Dict{Symbol, AutopilotBackend}(
                    :local => local_b, :uge => uge_b),
                qr=qr)
            @test cfg.backends[:local] === local_b
            @test cfg.backends[:uge] === uge_b

            # Resolve by entry.backend_type.
            run_dir_l = joinpath(qr.path, "reg_local_aaaa")
            run_dir_u = joinpath(qr.path, "reg_uge_bbbbbb")
            mkpath(run_dir_l);
            mkpath(run_dir_u)
            touch(joinpath(run_dir_l, "config.yaml"))
            touch(joinpath(run_dir_u, "config.yaml"))
            e_local = QueueEntry("reg_local_aaaa";
                run_dir=run_dir_l,
                spec_path=joinpath(run_dir_l, "config.yaml"),
                backend_type=:local)
            e_uge = QueueEntry("reg_uge_bbbbbb";
                run_dir=run_dir_u,
                spec_path=joinpath(run_dir_u, "config.yaml"),
                backend_type=:uge)
            @test resolve_backend(cfg, e_local) === local_b
            @test resolve_backend(cfg, e_uge) === uge_b

            # Unknown backend on the entry surfaces loudly — silent
            # mis-routing would be worse than a thrown error.
            e_bad = QueueEntry("reg_bad_cccccccc";
                run_dir=joinpath(qr.path, "reg_bad_cccccccc"),
                spec_path=joinpath(qr.path, "reg_bad_cccccccc", "config.yaml"),
                backend_type=:nonexistent)
            mkpath(e_bad.run_dir);
            touch(e_bad.spec_path)
            @test_throws ErrorException resolve_backend(cfg, e_bad)

            # Back-compat: passing a single backend wraps it as :local.
            cfg_compat = AutopilotConfig(; backend=local_b, qr=qr)
            @test cfg_compat.backends[:local] === local_b
            @test resolve_backend(cfg_compat, e_local) === local_b

            # Passing both forms is an explicit error.
            @test_throws ArgumentError AutopilotConfig(;
                backends=Dict{Symbol, AutopilotBackend}(:local => local_b),
                backend=local_b, qr=qr)
        end

        @testset "default no-op contract on AutopilotBackend" begin
            # A backend that overrides nothing inherits no-op stage_in /
            # pull_live / collect! — this is what makes "local is the
            # zero-latency instance of the same contract" hold.
            local_b = LocalBackend()
            run_dir = joinpath(qr.path, "contract_noop_aaaa")
            mkpath(run_dir)
            spec_path = joinpath(run_dir, "config.yaml")
            touch(spec_path)
            e = QueueEntry("contract_noop_aaaa";
                run_dir=run_dir, spec_path=spec_path)
            # All three must return nothing and produce no FS side-effects.
            sentinel = readdir(run_dir)
            @test stage_in(local_b, e) === nothing
            @test pull_live(local_b, e) === nothing
            @test collect!(local_b, e) === nothing
            @test readdir(run_dir) == sentinel
        end

        @testset "UGEBackend data-movement gating" begin
            # ssh_host=nothing → everything is a no-op (local UGE mode,
            # shared FS, nothing to mirror).
            b_local = UGEBackend()  # ssh_host=nothing by default
            run_dir = joinpath(qr.path, "uge_local_aaaaa")
            mkpath(run_dir)
            spec_path = joinpath(run_dir, "config.yaml")
            touch(spec_path)
            e = QueueEntry("uge_local_aaaaa";
                run_dir=run_dir, spec_path=spec_path,
                backend_type=:uge)
            @test stage_in(b_local, e) === nothing
            @test pull_live(b_local, e) === nothing
            @test collect!(b_local, e) === nothing

            # ssh_host set but remote_runs_root missing → stage_in must
            # surface that loudly (we cannot guess where on the remote
            # the run_dir lives).
            b_misconfigured = UGEBackend(ssh_host="example.tld")
            @test_throws ArgumentError stage_in(b_misconfigured, e)
        end

        @testset "UGEBackend command construction (remote mode)" begin
            # Assert the exact ssh/rsync/qsub command shapes. This is the
            # contract a real cluster sees; getting it wrong silently
            # fails at the wrong layer (e.g. config never lands on TSUBAME
            # and qsub reports "no such file").
            b = UGEBackend(ssh_host="tsubame",
                project_root="/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation",
                remote_runs_root="/gs/fs/tga-kozuma-kouhi/uk07267/runs",
                compute_group="tga-kozuma-kouhi",
                julia_path="/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia",
                cuda_module="cuda/12.8.0")
            run_dir = joinpath(qr.path, "uge_cmd_aaaaaa")
            mkpath(run_dir)
            spec_path = joinpath(run_dir, "config.yaml")
            touch(spec_path)
            e = QueueEntry("uge_cmd_aaaaaa";
                run_dir=run_dir, spec_path=spec_path,
                backend_type=:uge, code_sha="deadbeef")

            remote_dir = _uge_remote_run_dir(b, e)
            @test remote_dir ==
                "/gs/fs/tga-kozuma-kouhi/uk07267/runs/uge_cmd_aaaaaa"
            @test _uge_remote_spec_path(b, e) ==
                "/gs/fs/tga-kozuma-kouhi/uk07267/runs/uge_cmd_aaaaaa/config.yaml"

            # mkdir + config-rsync (stage_in).
            mkdir_args = _uge_mkdir_cmd(b, remote_dir).exec
            @test mkdir_args[1] == "ssh"
            @test mkdir_args[2] == "tsubame"
            @test mkdir_args[end - 1] == "-p"
            @test mkdir_args[end] == remote_dir

            rsync_args = _uge_rsync_config_cmd(b, e, remote_dir).exec
            @test rsync_args[1] == "rsync"
            @test "-e" in rsync_args && "ssh" in rsync_args
            @test e.spec_path in rsync_args
            @test "tsubame:$(remote_dir)/" in rsync_args

            # pull_live: just _live_status.json, with --ignore-missing-args
            # so the first ticks (before the file exists) don't fail.
            live_args = _uge_pull_live_cmd(b, e, remote_dir).exec
            @test "--ignore-missing-args" in live_args
            @test "tsubame:$(remote_dir)/_live_status.json" in live_args
            @test joinpath(e.run_dir, "_live_status.json") in live_args

            # collect!: mirror but PRESERVE local state.toml (canonical
            # queue metadata) and skip .state.lock.
            coll_args = _uge_collect_cmd(b, e, remote_dir).exec
            @test "--exclude=state.toml" in coll_args
            @test "--exclude=.state.lock" in coll_args
            @test "tsubame:$(remote_dir)/" in coll_args
            @test "$(e.run_dir)/" in coll_args

            # Code-sync rsync builder: SHA stripped of -dirty marker, full
            # snippet wrapped in `bash -lc`, julia_path baked in.
            code_args = _uge_code_sync_cmd(b, "abc123-dirty").exec
            @test code_args[1] == "ssh"
            @test code_args[2] == "tsubame"
            @test code_args[3] == "bash"
            @test code_args[4] == "-lc"
            snippet = code_args[5]
            @test occursin("git checkout --quiet abc123", snippet)
            @test !occursin("-dirty", snippet)
            @test occursin("Pkg.instantiate", snippet)
            @test occursin(b.julia_path, snippet)

            # rsync of the rendered submit.uge.sh.
            script_args = _uge_rsync_script_cmd(b,
                "/local/x.uge.sh",
                "/gs/fs/tga-kozuma-kouhi/uk07267/runs/x/x.uge.sh").exec
            @test "/local/x.uge.sh" in script_args
            @test ("tsubame:" *
                   "/gs/fs/tga-kozuma-kouhi/uk07267/runs/x/x.uge.sh") in script_args

            # qsub / qstat / qdel / qacct / qstat-list shells.
            # `-g <group>` lives on the qsub command line, NOT in the
            # script (TSUBAME 4's qsub wrapper rejects `#$ -g` as
            # "invalid option argument").
            @test _uge_qsub_cmd(b, "/remote/x.uge.sh").exec ==
                ["ssh", "tsubame", "qsub", "-g", "tga-kozuma-kouhi", "/remote/x.uge.sh"]
            # When no compute_group is set, the flag is omitted (trial mode).
            b_nogroup = UGEBackend(ssh_host="tsubame")
            @test _uge_qsub_cmd(b_nogroup, "/remote/x.uge.sh").exec ==
                ["ssh", "tsubame", "qsub", "/remote/x.uge.sh"]
            @test _uge_qstat_cmd(b, "12345").exec ==
                ["ssh", "tsubame", "qstat", "-j", "12345"]
            @test _uge_qdel_cmd(b, "12345").exec ==
                ["ssh", "tsubame", "qdel", "12345"]
            @test _uge_qacct_cmd(b, "12345").exec ==
                ["ssh", "tsubame", "qacct", "-j", "12345"]
            @test _uge_qstat_list_cmd(b).exec == ["ssh", "tsubame", "qstat"]
        end

        @testset "UGE script rendering" begin
            script = render_uge_script("default", "/remote/cfg.yaml";
                project_root="/remote/proj",
                log_dir="/remote/runs/cid_abcdef",
                julia_path="/remote/julia",
                cuda_module="cuda/12.8.0",
                jobname="cid_abcdef",
                compute_group="tga-kozuma-kouhi")
            @test occursin("#\$ -N cid_abcdef", script)
            # Absolute log paths land logs in the run_dir. `-cwd` +
            # relative paths would land them in $HOME because ssh to
            # TSUBAME starts in $HOME and qsub uses that as the job's
            # initial cwd.
            @test occursin("#\$ -o /remote/runs/cid_abcdef/stdout.log", script)
            @test occursin("#\$ -e /remote/runs/cid_abcdef/stderr.log", script)
            @test !occursin("#\$ -cwd", script)
            @test occursin("#\$ -l node_q=1", script)
            @test occursin("#\$ -l h_rt=12:00:00", script)
            @test occursin("module load cuda/12.8.0", script)
            @test occursin("cd \"/remote/proj\"", script)
            @test occursin("/remote/julia", script)
            @test occursin("run_yaml(ARGS[1])", script)
            @test occursin("/remote/cfg.yaml", script)
            # `-g <group>` MUST NOT appear as a script directive on
            # TSUBAME 4 (rejected with "invalid option argument").
            # The dispatch path passes it on the qsub command line instead.
            @test !occursin("#\$ -g", script)

            # Without cuda_module the load line is omitted.
            bare = render_uge_script("gpu_1", "/cfg.yaml";
                project_root="/proj", log_dir="/runs/j", jobname="j")
            @test !occursin("module load", bare)
            @test occursin("#\$ -l gpu_1=1", bare)

            # Unknown profile must throw, not silently submit nothing.
            @test_throws ArgumentError render_uge_script("nope", "/x";
                project_root="/p", log_dir="/runs/j", jobname="j")
        end

        @testset "enqueue! kick_tick: gating + async fire" begin
            # Bare `enqueue!` (default kick_tick=true) fires a tick the
            # moment the entry lands, so every path (CLI, recipe-spawn,
            # dashboard, future callers) gets immediate dispatch
            # without each site wiring its own async block. The kick is
            # GATED on autonomy_level=:dispatch — there's nothing to
            # dispatch for :propose / :suggest, so no kick is fired.
            mktempdir() do tmp
                local_qr = SpinorBEC.QueueRoot(joinpath(tmp, "runs"))
                mkpath(local_qr.path)
                SpinorBEC.autopilot_queue_root(local_qr)
                local_store = SpinorBEC.CASStore(local_qr.path)
                # Sentinel autopilot pause so any tick that does fire
                # is a no-op (we just want to verify the call shape,
                # not actually dispatch onto LocalBackend's subprocess).
                touch(joinpath(local_qr.path, ".autopilot.paused"))

                spec_a = Dict{Any, Any}(
                    "pipeline" => [Dict("ground_state" =>
                        Dict("_kick_test" => "a"))],
                )
                spec_b = Dict{Any, Any}(
                    "pipeline" => [Dict("ground_state" =>
                        Dict("_kick_test" => "b"))],
                )

                # :propose → no kick (Task list len snapshot stays the
                # same modulo other system tasks; we use the more
                # robust observation that the call returns synchronously
                # without throwing).
                e_pr = enqueue!(SpinorBEC.Experiment(spec_a; store=local_store);
                    autonomy_level=:propose, qr=local_qr)
                @test e_pr.autonomy_level === :propose

                # :dispatch with kick_tick=true → returns immediately
                # (the @async means the kick runs in the background;
                # there's no blocking lock acquire on the caller side).
                t0 = time()
                e_di = enqueue!(SpinorBEC.Experiment(spec_b; store=local_store);
                    autonomy_level=:dispatch, qr=local_qr)
                @test time() - t0 < 1.0   # enqueue returns synchronously
                @test e_di.autonomy_level === :dispatch

                # The async tick eventually runs; since pause sentinel
                # is set, dispatch is gated to 0 and no real subprocess
                # is spawned. Give the task a moment to attempt.
                sleep(0.5)

                # kick_tick=false is the explicit opt-out used by bulk
                # callers (tests, batched sweep enqueue).
                e_quiet = enqueue!(
                    SpinorBEC.Experiment(
                        Dict{Any, Any}(
                            "pipeline" => [
                                Dict("ground_state" => Dict("_kick_test" => "c"))],
                        );
                        store=local_store);
                    autonomy_level=:dispatch, kick_tick=false, qr=local_qr)
                @test e_quiet.status === :pending

                rm(joinpath(local_qr.path, ".autopilot.paused"); force=true)
            end
        end

        @testset "_uge_jobname prefixes numeric content IDs" begin
            # UGE rejects job names starting with a digit. Content IDs
            # are hex so they routinely start with 0-9; the prefix is
            # what makes `qsub -N` and `qstat`-name reconciliation
            # actually reach the scheduler.
            @test _uge_jobname("468a96d062a66d6d") == "sb_468a96d062a66d6d"
            @test _uge_jobname("abc") == "sb_abc"
            # The character class is `[a-zA-Z][a-zA-Z0-9_]*` after the
            # prefix — `_uge_jobname` doesn't try to sanitize internal
            # characters, only to defuse the leading-digit case.
            @test startswith(_uge_jobname("9foo"), "sb_")
        end

        @testset "UGE qsub jobid parsing + qstat job_state extraction" begin
            # Canonical UGE qsub stdout (a couple of common variants).
            @test _parse_qsub_jobid(
                "Your job 1234567 (\"foo\") has been submitted") == "1234567"
            @test _parse_qsub_jobid(
                "Your job-array 88.1-10:1 (\"bar\") has been submitted") == "88"
            @test_throws ErrorException _parse_qsub_jobid("\n   \n")

            # qstat listing parser extracts state from column 5 keyed
            # by job-ID. TSUBAME 4's `qstat -j <id>` detail output does
            # NOT include a `job_state:` line (only listing mode does),
            # so we parse the listing here.
            listing = """
            job-ID     prior   name       user         state submit/start at     queue                          jclass                         slots ja-task-ID
            ------------------------------------------------------------------------------------------------------------------------------------------------
               7805539 0.55256 sb_468a96d uk07267      qw    05/30/2026 22:15:59                                                                  48
               7805600 0.49000 sb_other   uk07267      r     05/30/2026 22:30:00 all.q                                                            48
               7805700 0.10000 sb_dying   uk07267      dr    05/30/2026 22:45:00                                                                  48
            """
            @test _uge_extract_job_state_from_listing(listing, "7805539") == "pending"
            @test _uge_extract_job_state_from_listing(listing, "7805600") == "running"
            @test _uge_extract_job_state_from_listing(listing, "7805700") == "failed"
            # Missing from the listing → "absent" → caller treats as
            # terminal and consults outcome.toml.
            @test _uge_extract_job_state_from_listing(listing, "9999999") == "absent"
            @test _uge_extract_job_state_from_listing("", "1") == "absent"
        end

        @testset "UGE retry-escalation ladder" begin
            b = UGEBackend()
            # node_q → node_h → node_f → nothing
            @test next_profile(b, "default") == "node_h"
            @test next_profile(b, "node_h") == "node_f"
            @test next_profile(b, "node_f") === nothing
            # Unknown profile name: no escalation, retry caps.
            @test next_profile(b, "unknown_profile") === nothing
            # LocalBackend has no ladder — always nothing.
            @test next_profile(LocalBackend(), "default") === nothing
        end

        @testset "LocalBackend subprocess shape" begin
            # End-to-end subprocess test would pay another Julia startup
            # (~30s with cache, multiple minutes cold). Skip by default
            # in fast/ci tiers; gate behind SPINORBEC_RUN_HEAVY_LOCAL.
            # What we DO test cheaply:
            #   - construction holds the configured fields
            #   - cancel! on a missing entry is a graceful false
            #   - find_job_by_name on an unknown name reports :no_such_job
            #   - n_running on empty table is 0
            b = LocalBackend(; max_concurrent=2,
                project_root="/tmp/proj", julia_bin="julia")
            @test b.max_concurrent == 2
            @test b.project_root == "/tmp/proj"
            @test b.julia_bin == "julia"
            @test SpinorBEC.n_running(b) == 0

            run_dir = joinpath(qr.path, "local_shape_aaaa")
            mkpath(run_dir)
            spec_path = joinpath(run_dir, "config.yaml")
            touch(spec_path)
            e = QueueEntry("local_shape_aaaa";
                run_dir=run_dir, spec_path=spec_path)
            @test cancel!(b, e) === false   # nothing in flight
            @test SpinorBEC.find_job_by_name(b, "no_such") === :no_such_job
            @test occursin("not in local table",
                SpinorBEC.backend_failure_reason(b, e))
        end

        @testset "default_autopilot_config: env-driven UGE registration" begin
            # When the SPINORBEC_TSUBAME_* env triple is set, the
            # systemd timer / dashboard server picks up a :uge backend
            # without code edits. Unset → :local-only.
            saved = Dict{String, Any}(
                k => get(ENV, k, nothing) for k in
                ("SPINORBEC_TSUBAME_HOST", "SPINORBEC_TSUBAME_PROJECT_ROOT",
                    "SPINORBEC_TSUBAME_RUNS_ROOT", "SPINORBEC_TSUBAME_GROUP",
                    "SPINORBEC_TSUBAME_JULIA", "SPINORBEC_TSUBAME_CUDA_MODULE",
                    "SPINORBEC_TSUBAME_SYNC_CODE")
            )
            try
                # Unset → :local only.
                for k in keys(saved)
                    ;
                    delete!(ENV, k);
                end
                cfg_bare = SpinorBEC.default_autopilot_config(; qr=qr,
                    inspect_before_dispatch=false)
                @test haskey(cfg_bare.backends, :local)
                @test !haskey(cfg_bare.backends, :uge)

                # Partial triple (missing runs root) → still :local only.
                ENV["SPINORBEC_TSUBAME_HOST"] = "tsubame"
                ENV["SPINORBEC_TSUBAME_PROJECT_ROOT"] = "/p"
                cfg_partial = SpinorBEC.default_autopilot_config(; qr=qr,
                    inspect_before_dispatch=false)
                @test !haskey(cfg_partial.backends, :uge)

                # Full triple + optional fields → :uge registered with
                # the env values plumbed through.
                ENV["SPINORBEC_TSUBAME_RUNS_ROOT"] = "/scratch/runs"
                ENV["SPINORBEC_TSUBAME_GROUP"] = "tga-test"
                ENV["SPINORBEC_TSUBAME_JULIA"] = "/opt/julia"
                ENV["SPINORBEC_TSUBAME_CUDA_MODULE"] = "cuda/12.8.0"
                ENV["SPINORBEC_TSUBAME_SYNC_CODE"] = "true"
                cfg_full = SpinorBEC.default_autopilot_config(; qr=qr,
                    inspect_before_dispatch=false)
                @test haskey(cfg_full.backends, :uge)
                u = cfg_full.backends[:uge]::UGEBackend
                @test u.ssh_host == "tsubame"
                @test u.project_root == "/p"
                @test u.remote_runs_root == "/scratch/runs"
                @test u.compute_group == "tga-test"
                @test u.julia_path == "/opt/julia"
                @test u.cuda_module == "cuda/12.8.0"
                @test u.sync_code === true
            finally
                for (k, v) in saved
                    if v === nothing
                        delete!(ENV, k)
                    else
                        ENV[k] = v
                    end
                end
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
