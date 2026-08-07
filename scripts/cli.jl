# Unified SpinorBEC CLI — single entry point dispatching to library
# functions. All compute lives in `src/`; this file is pure dispatch.
#
# Usage:
#   julia --project=. scripts/cli.jl <subcommand> [args...]
#
# Subcommands:
#   inspect   <yaml> [--json]                       pre-run YAML lint
#   launch    [<batch>] <run_name>                  full per-run launcher
#   figure    --paper <p> --fig <n> | --list        manuscript figure builder
#   preflight [<smoke_config>]                      cluster CUDA + smoke
#   autopilot {tick|status|enqueue|retry|pause|resume|drain|why|budget|dry-run}
#                                                   queue meta-loop ops
#   help                                            this message

using SpinorBEC

function _print_help(io::IO=stdout)
    println(io, "Usage: julia --project=. scripts/cli.jl <subcommand> [args...]")
    println(io)
    println(io, "Subcommands:")
    println(io, "  inspect   <yaml> [--json]                       pre-run YAML lint")
    println(io, "  launch    [<batch>] <run_name>                  full per-run launcher")
    println(io, "  figure    --paper <p> --fig <n> | --list        manuscript figure builder")
    println(io, "  preflight [<smoke_config>]                      cluster CUDA + smoke")
    println(io, "  autopilot <sub> [args]                          queue meta-loop ops")
    println(io, "  tag       {add <name> <cid>|remove <name>|list} catalog human pointers")
    println(io, "  catalog   {index | reindex [--force]}            navigable run index")
    println(io, "  tsubame   {build-sysimage}                       cluster helper(s)")
    println(io, "  help                                            this message")
    println(io)
    println(io, "autopilot subcommands:")
    println(io, "  tick [--dry-run]                                one tick (cron / systemd)")
    println(io, "  status                                          snapshot of all queues")
    println(io, "  enqueue <yaml> [--priority N] [--enqueued-by T] add a run to pending")
    println(io, "  retry [--max N]                                 reschedule killed_bug")
    println(io, "  pause | resume                                  global dispatch gate")
    println(io, "  drain [--timeout=N]                             wait for running to empty")
    println(io, "  why <content_id>                                lineage chain")
    println(io, "  budget [set --quarter=X --daily=Y]              GPU·h caps")
    println(io, "  dry-run [on | off | status]                     toggle persisted flag")
end

# ── small kv-flag helpers (shared across subcommands) ────────────────

function _kv(args, key, default="")
    pref = "--" * key * "="
    for a in args
        startswith(String(a), pref) || continue
        return String(a)[(length(pref) + 1):end]
    end
    default
end
_kvf(args, key, default) =
    isempty(_kv(args, key, "")) ? Float64(default) : parse(Float64, _kv(args, key, ""))
_kvi(args, key, default) =
    isempty(_kv(args, key, "")) ? Int(default) : parse(Int, _kv(args, key, ""))

# ── top-level subcommands ────────────────────────────────────────────

function _cmd_inspect(args)
    if isempty(args) || args[1] in ("-h", "--help")
        println(stderr, "usage: cli.jl inspect <config.yaml> [--json]")
        return 2
    end
    path = args[1]
    isfile(path) || (println(stderr, "inspect: file not found: $path"); return 2)
    as_json = "--json" in args
    ins = inspect_config(path)
    if as_json
        d = SpinorBEC.to_dict(ins)
        try
            @eval using JSON3
            JSON3.write(stdout, d);
            println()
        catch
            println(stderr, "warning: JSON3 not available; printing Julia repr")
            show(stdout, MIME"text/plain"(), d);
            println()
        end
    else
        print_inspection(stdout, ins)
    end
    return count(w -> w.severity === :error, ins.warnings) == 0 ? 0 : 1
end

function _cmd_launch(args)
    if !(1 <= length(args) <= 2)
        println(stderr, "usage: cli.jl launch [<batch>] <run_name>")
        return 2
    end
    batch, run_name = length(args) == 2 ? (args[1], args[2]) : ("", args[1])
    launch_experiment(run_name; batch=batch)
    return 0
end

function _cmd_figure(args)
    paper, fig, list = nothing, nothing, false
    i = 1
    while i <= length(args)
        if args[i] == "--paper" && i + 1 <= length(args)
            paper = args[i + 1];
            i += 2
        elseif args[i] == "--fig" && i + 1 <= length(args)
            fig = args[i + 1];
            i += 2
        elseif args[i] == "--list"
            list = true;
            i += 1
        else
            i += 1
        end
    end
    if list || paper === nothing || fig === nothing
        list_manuscript_figures()
        return 0
    end
    fig_name = startswith(uppercase(fig), "FIG") ? fig : "FIG-$fig"
    render_manuscript_figure(paper, fig_name) ? 0 : 1
end

function _cmd_preflight(args)
    smoke = isempty(args) ? nothing : args[1]
    # Propagate. This discarded the verdict and returned 0 until 2026-08-07, so
    # `cli.jl preflight` exited green on a machine with no GPU — the caller threw
    # away the only signal the check produced.
    return cuda_preflight_check(; smoke_config=smoke) ? 0 : 1
end

# ── autopilot subcommand dispatcher ──────────────────────────────────

function _cmd_autopilot(args)
    if isempty(args)
        println(
            stderr,
            "usage: cli.jl autopilot {tick|status|enqueue|retry|pause|resume|drain|why|budget|dry-run|backfill-groups}",
        )
        return 2
    end
    sub, rest = args[1], args[2:end]
    sub == "tick" && return _ap_tick(rest)
    sub == "status" && return _ap_status(rest)
    sub == "enqueue" && return _ap_enqueue(rest)
    sub == "retry" && return _ap_retry(rest)
    sub == "pause" && return _ap_pause(rest)
    sub == "resume" && return _ap_resume(rest)
    sub == "drain" && return _ap_drain(rest)
    sub == "why" && return _ap_why(rest)
    sub == "budget" && return _ap_budget(rest)
    sub == "dry-run" && return _ap_dryrun(rest)
    sub == "backfill-groups" && return _ap_backfill_groups(rest)
    println(stderr, "cli.jl autopilot: unknown subcommand '$sub'")
    return 2
end

function _ap_tick(rest)
    dry = "--dry-run" in rest
    cfg = SpinorBEC.default_autopilot_config(; dry_run=dry)
    stats = autopilot_tick!(; config=cfg)
    println(dry ? "tick (DRY-RUN): " : "tick: ", stats)
    0
end

function _ap_status(_)
    print(stdout, autopilot_status())
    0
end

function _ap_enqueue(rest)
    isempty(rest) && (
        println(stderr, "usage: cli.jl autopilot enqueue <yaml> [--priority N] [--enqueued-by T]");
        return 2
    )
    yaml_path = rest[1]
    priority = _kvi(rest, "priority", 5)
    tag = _kv(rest, "enqueued-by", "cli")
    e = enqueue!(Experiment(yaml_path); priority=priority, enqueued_by=tag)
    println("enqueued: $(e.run_dir)")
    0
end

function _ap_retry(rest)
    max_r = _kvi(rest, "max", 3)
    # The config, so the backend is resolved per entry. Passing none meant every
    # entry was interrogated as if it were local.
    out = retry_failed!(; max_retries=max_r,
        config=SpinorBEC.default_autopilot_config())
    println("retry: ", out)
    0
end

function _ap_backfill_groups(rest)
    dry = "--dry-run" in rest
    changes = SpinorBEC.backfill_group_ids!(; dry_run=dry)
    if isempty(changes)
        println("backfill-groups: nothing to do (all group_ids consistent)")
    else
        println(
            if dry
                "backfill-groups (DRY-RUN), would update $(length(changes)):"
            else
                "backfill-groups: updated $(length(changes)):"
            end,
        )
        for (cid, gid) in changes
            println("  $(cid[1:min(end,16)]) → group_id $(gid[1:min(end,16)])")
        end
    end
    0
end

function _ap_pause(_)
    autopilot_pause!()
    println("autopilot paused (dispatch halted; running jobs continue)")
    0
end

function _ap_resume(_)
    autopilot_resume!()
    println("autopilot resumed")
    0
end

function _ap_drain(rest)
    tmo = _kvf(rest, "timeout", 3600.0)
    ok = autopilot_drain_wait(; timeout_s=tmo)
    println(ok ? "drained" : "drain timed out")
    ok ? 0 : 1
end

function _ap_why(rest)
    isempty(rest) && (println(stderr, "usage: cli.jl autopilot why <content_id>"); return 2)
    chain = autopilot_why(rest[1])
    print_why(stdout, chain)
    0
end

function _ap_budget(rest)
    if !isempty(rest) && rest[1] == "set"
        b = SpinorBEC.get_budget()
        qcap = _kvf(rest, "quarter", b.quarter_cap_gpu_hours)
        dcap = _kvf(rest, "daily", b.daily_cap_gpu_hours)
        b.quarter_cap_gpu_hours = qcap
        b.daily_cap_gpu_hours = dcap
        SpinorBEC.set_budget!(b)
        println("budget caps updated: quarter=$(qcap), daily=$(dcap)")
        return 0
    end
    SpinorBEC.refresh_budget!()
    d = SpinorBEC.budget_status()
    for (k, v) in d
        println("  ", rpad(string(k), 24), v)
    end
    0
end

function _ap_dryrun(rest)
    if isempty(rest) || rest[1] in ("status", "show")
        on = SpinorBEC.is_autopilot_dry_run()
        println("autopilot dry_run: ", on ? "ON" : "OFF")
        return 0
    elseif rest[1] == "on"
        SpinorBEC.autopilot_set_dry_run!(true)
        println("autopilot dry_run: ON")
        return 0
    elseif rest[1] == "off"
        SpinorBEC.autopilot_set_dry_run!(false)
        println("autopilot dry_run: OFF")
        return 0
    end
    println(stderr, "usage: cli.jl autopilot dry-run [on|off|status]")
    2
end

# ── tag subcommand (catalog human pointers) ─────────────────────────

function _cmd_tag(args)
    if isempty(args)
        println(stderr, "usage: cli.jl tag {add <name> <cid>|remove <name>|list}")
        return 2
    end
    sub, rest = args[1], args[2:end]
    if sub == "add"
        length(rest) >= 2 ||
            (println(stderr, "usage: cli.jl tag add <name> <content_id>"); return 2)
        rec = SpinorBEC.tag_run!(rest[1], rest[2]; created_by="cli")
        println("tagged \"$(rec.name)\" → $(rec.content_id)")
        return 0
    elseif sub == "remove"
        isempty(rest) && (println(stderr, "usage: cli.jl tag remove <name>"); return 2)
        ok = SpinorBEC.untag!(rest[1])
        println(ok ? "removed \"$(rest[1])\"" : "no such tag \"$(rest[1])\"")
        return ok ? 0 : 1
    elseif sub == "list"
        for t in SpinorBEC.load_tags()
            println(rpad(t.name, 28), " ", t.content_id)
        end
        return 0
    end
    println(stderr, "cli.jl tag: unknown subcommand '$sub'")
    2
end

# ── catalog subcommand (navigable index over the CAS run store) ──────

function _cmd_catalog(args)
    sub = isempty(args) ? "index" : args[1]
    if sub == "reindex" || sub == "backfill"
        force = "--force" in args
        n = SpinorBEC.backfill_summaries!(; force=force)
        println("catalog reindex: wrote $n summary.json" * (force ? " (forced)" : ""))
        return 0
    elseif sub == "index" || sub == "status"
        rows = SpinorBEC.run_catalog_index()
        n = length(rows)
        n_sum = count(r -> get(r, "has_summary", false), rows)
        println("catalog: $n runs · $n_sum with summary · $(n - n_sum) need reindex")
        return 0
    end
    println(stderr, "cli.jl catalog: unknown subcommand '$sub' (index | reindex [--force])")
    2
end

# ── tsubame helpers ──────────────────────────────────────────────────

function _cmd_tsubame(args)
    if isempty(args)
        println(stderr, "usage: cli.jl tsubame {build-sysimage}")
        return 2
    end
    sub = args[1]
    sub == "build-sysimage" && return _tsubame_build_sysimage()
    println(stderr, "cli.jl tsubame: unknown subcommand '$sub'")
    return 2
end

"""
Build a Julia sysimage on TSUBAME via PackageCompiler. One-shot
operator helper — rebuild when Project.toml / Manifest.toml change.
With the sysimage set in `SPINORBEC_TSUBAME_SYSIMAGE`, each job's
first-output latency drops from ~30 s (cold JIT) to ~2 s. Build time
is ~5–10 minutes; sysimage is ~1 GB.
"""
function _tsubame_build_sysimage()
    host = get(ENV, "SPINORBEC_TSUBAME_HOST", "")
    proj = get(ENV, "SPINORBEC_TSUBAME_PROJECT_ROOT", "")
    julia = get(ENV, "SPINORBEC_TSUBAME_JULIA", "julia")
    depot = get(ENV, "SPINORBEC_TSUBAME_DEPOT", "")
    syspath = get(ENV, "SPINORBEC_TSUBAME_SYSIMAGE", "")
    cuda_module = get(ENV, "SPINORBEC_TSUBAME_CUDA_MODULE", "")
    if isempty(host) || isempty(proj) || isempty(syspath)
        println(stderr,
            "missing env: need SPINORBEC_TSUBAME_HOST / PROJECT_ROOT / SYSIMAGE\n" *
            "(SYSIMAGE = absolute remote path where the sysimage will be written, " *
            "e.g. /gs/fs/<group>/<user>/spinor_sysimage.so)")
        return 2
    end
    depot_exp = isempty(depot) ? "" : "export JULIA_DEPOT_PATH=\"$(depot)\"; "
    mod_load =
        isempty(cuda_module) ? "" :
        ". /etc/profile.d/modules.sh && module load $(cuda_module) && "
    julia_e =
        "using Pkg; Pkg.add(\"PackageCompiler\"); " *
        "using PackageCompiler; " *
        "create_sysimage([:SpinorBEC]; sysimage_path=\"$(syspath)\")"
    snippet =
        "set -euo pipefail; $(mod_load)$(depot_exp)cd $(proj) && " *
        "$(julia) --project=. -e '$(julia_e)'"
    println("building sysimage on $(host) → $(syspath)")
    println("  (this takes ~5–10 minutes; output streams below)")
    cmd = `ssh $host bash -lc $snippet`
    try
        run(cmd)
        println("sysimage built. Job dispatches will now use `-J $(syspath)`.")
        return 0
    catch err
        println(stderr, "build failed: $(err)")
        return 1
    end
end

# ── main ─────────────────────────────────────────────────────────────

function _main(args)
    isempty(args) && (_print_help(); return 0)
    sub, rest = args[1], args[2:end]
    sub in ("help", "-h", "--help") && (_print_help(); return 0)
    sub == "inspect" && return _cmd_inspect(rest)
    sub == "launch" && return _cmd_launch(rest)
    sub == "figure" && return _cmd_figure(rest)
    sub == "preflight" && return _cmd_preflight(rest)
    sub == "autopilot" && return _cmd_autopilot(rest)
    sub == "tag" && return _cmd_tag(rest)
    sub == "catalog" && return _cmd_catalog(rest)
    sub == "tsubame" && return _cmd_tsubame(rest)
    println(stderr, "cli.jl: unknown subcommand '$sub'")
    _print_help(stderr)
    2
end

exit(_main(copy(ARGS)))
