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
        return String(a)[length(pref)+1:end]
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
            paper = args[i + 1]; i += 2
        elseif args[i] == "--fig" && i + 1 <= length(args)
            fig = args[i + 1]; i += 2
        elseif args[i] == "--list"
            list = true; i += 1
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
    cuda_preflight_check(; smoke_config=smoke)
    return 0
end

# ── autopilot subcommand dispatcher ──────────────────────────────────

function _cmd_autopilot(args)
    if isempty(args)
        println(stderr, "usage: cli.jl autopilot {tick|status|enqueue|retry|pause|resume|drain|why|budget|dry-run}")
        return 2
    end
    sub, rest = args[1], args[2:end]
    sub == "tick"     && return _ap_tick(rest)
    sub == "status"   && return _ap_status(rest)
    sub == "enqueue"  && return _ap_enqueue(rest)
    sub == "retry"    && return _ap_retry(rest)
    sub == "pause"    && return _ap_pause(rest)
    sub == "resume"   && return _ap_resume(rest)
    sub == "drain"    && return _ap_drain(rest)
    sub == "why"      && return _ap_why(rest)
    sub == "budget"   && return _ap_budget(rest)
    sub == "dry-run"  && return _ap_dryrun(rest)
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
    isempty(rest) && (println(stderr, "usage: cli.jl autopilot enqueue <yaml> [--priority N] [--enqueued-by T]"); return 2)
    yaml_path = rest[1]
    priority = _kvi(rest, "priority", 5)
    tag = _kv(rest, "enqueued-by", "cli")
    e = enqueue!(Experiment(yaml_path); priority=priority, enqueued_by=tag)
    println("enqueued: $(e.run_dir)")
    0
end

function _ap_retry(rest)
    max_r = _kvi(rest, "max", 3)
    out = retry_failed!(; max_retries=max_r)
    println("retry: ", out)
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
    ok = autopilot_drain_wait(timeout_s=tmo)
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
        dcap = _kvf(rest, "daily",   b.daily_cap_gpu_hours)
        b.quarter_cap_gpu_hours = qcap
        b.daily_cap_gpu_hours   = dcap
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

# ── main ─────────────────────────────────────────────────────────────

function _main(args)
    isempty(args) && (_print_help(); return 0)
    sub, rest = args[1], args[2:end]
    sub in ("help", "-h", "--help") && (_print_help(); return 0)
    sub == "inspect"   && return _cmd_inspect(rest)
    sub == "launch"    && return _cmd_launch(rest)
    sub == "figure"    && return _cmd_figure(rest)
    sub == "preflight" && return _cmd_preflight(rest)
    sub == "autopilot" && return _cmd_autopilot(rest)
    println(stderr, "cli.jl: unknown subcommand '$sub'")
    _print_help(stderr)
    2
end

exit(_main(copy(ARGS)))
