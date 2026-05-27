# Unified SpinorBEC CLI — single entry point that dispatches to library
# functions. Replaces the per-task scripts (inspect_config.jl, launch_run.jl,
# manuscript/render_figures.jl). Build-time scripts (tsubame/build_sysimage.jl)
# remain separate because they invoke PackageCompiler, not SpinorBEC.
#
# Usage:
#   julia --project=. scripts/cli.jl <subcommand> [args...]
#
# Subcommands:
#   inspect <config.yaml> [--json]               # pre-run lint
#   launch  [<batch>] <run_name>                 # full per-run launcher
#   figure  --paper <p> --fig <n> | --list       # manuscript figure builder
#   preflight [<smoke_config>]                   # cluster CUDA + smoke
#   autopilot {tick|status|enqueue|retry} ...    # queue meta-loop
#   help                                         # this message

using SpinorBEC

function _print_help(io::IO=stdout)
    println(io, "Usage: julia --project=. scripts/cli.jl <subcommand> [args...]")
    println(io)
    println(io, "Subcommands:")
    println(io, "  inspect <config.yaml> [--json]               pre-run YAML lint")
    println(io, "  launch  [<batch>] <run_name>                 full per-run launcher")
    println(io, "  figure  --paper <p> --fig <n> | --list       manuscript figure builder")
    println(io, "  preflight [<smoke_config>]                   cluster CUDA + smoke")
    println(io, "  autopilot {tick|status|enqueue|retry|pause|resume|drain|why} ...   queue meta-loop")
    println(io, "  help                                         this message")
end

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
    cuda_preflight_check(; smoke_config=smoke)
    return 0
end

function _cmd_autopilot(args)
    isempty(args) && (println(stderr, "usage: cli.jl autopilot {tick|status|enqueue|retry}"); return 2)
    sub, rest = args[1], args[2:end]
    if sub == "status"
        print(stdout, autopilot_status())
        return 0
    elseif sub == "tick"
        stats = autopilot_tick!()
        println("dispatched=$(stats.dispatched) completed=$(stats.completed) " *
                "failed=$(stats.failed) inspected_blocked=$(stats.inspected_blocked) " *
                "killed_divergent=$(stats.killed_divergent) " *
                "on_complete_fired=$(stats.on_complete_fired) " *
                "n_pending=$(stats.n_pending) n_running=$(stats.n_running)")
        return 0
    elseif sub == "enqueue"
        # cli.jl autopilot enqueue <yaml_path> [--priority N] [--enqueued-by TAG]
        isempty(rest) && (println(stderr, "usage: cli.jl autopilot enqueue <yaml> [--priority N]"); return 2)
        yaml_path = rest[1]
        priority = 5
        tag = "cli"
        i = 2
        while i <= length(rest)
            if rest[i] == "--priority" && i + 1 <= length(rest)
                priority = parse(Int, rest[i + 1]);
                i += 2
            elseif rest[i] == "--enqueued-by" && i + 1 <= length(rest)
                tag = rest[i + 1];
                i += 2
            else
                i += 1
            end
        end
        path = enqueue!(Experiment(yaml_path);
            priority=priority, enqueued_by=tag)
        println("enqueued: $path")
        return 0
    elseif sub == "retry"
        max_r = isempty(rest) ? 3 : parse(Int, rest[1])
        out = retry_failed!(; max_retries=max_r)
        println("retried=$(out.retried) escalated=$(out.escalated) abandoned=$(out.abandoned)")
        return 0
    elseif sub == "pause"
        autopilot_pause!()
        println("autopilot paused (dispatch halted; running jobs continue)")
        return 0
    elseif sub == "resume"
        autopilot_resume!()
        println("autopilot resumed")
        return 0
    elseif sub == "drain"
        # block until running queue drains
        autopilot_drain_wait()
        println("drained")
        return 0
    elseif sub == "why"
        isempty(rest) && (println(stderr, "usage: cli.jl autopilot why <content_id>"); return 2)
        chain = autopilot_why(rest[1])
        print_why(stdout, chain)
        return 0
    else
        println(stderr, "cli.jl autopilot: unknown subcommand '$sub'");
        return 2
    end
end

function _main(args)
    isempty(args) && (_print_help(); return 0)
    sub, rest = args[1], args[2:end]
    if sub in ("help", "-h", "--help")
        _print_help();
        return 0
    elseif sub == "inspect"
        return _cmd_inspect(rest)
    elseif sub == "launch"
        return _cmd_launch(rest)
    elseif sub == "figure"
        return _cmd_figure(rest)
    elseif sub == "preflight"
        return _cmd_preflight(rest)
    elseif sub == "autopilot"
        return _cmd_autopilot(rest)
    else
        println(stderr, "cli.jl: unknown subcommand '$sub'")
        _print_help(stderr)
        return 2
    end
end

exit(_main(copy(ARGS)))
