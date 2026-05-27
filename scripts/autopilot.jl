# Operator CLI for the autopilot.
#
# Usage:
#   julia --project=. scripts/autopilot.jl tick
#   julia --project=. scripts/autopilot.jl status
#   julia --project=. scripts/autopilot.jl pause
#   julia --project=. scripts/autopilot.jl resume
#   julia --project=. scripts/autopilot.jl drain [--timeout=3600]
#   julia --project=. scripts/autopilot.jl why <content_id>
#   julia --project=. scripts/autopilot.jl budget
#   julia --project=. scripts/autopilot.jl budget set --quarter=5000 --daily=50
#   julia --project=. scripts/autopilot.jl retry [--max=3]
#
# Exit codes:
#   0   success
#   1   recoverable error (paused, no entry, budget gate, ...)
#   2   argument / I/O failure

using SpinorBEC

function _kv(args::Vector{String}, key::String, default::String="")
    pref = "--" * key * "="
    for a in args
        startswith(a, pref) || continue
        return a[length(pref)+1:end]
    end
    return default
end

function _kvf(args::Vector{String}, key::String, default::Float64)
    s = _kv(args, key, "")
    isempty(s) && return default
    parse(Float64, s)
end

function _kvi(args::Vector{String}, key::String, default::Int)
    s = _kv(args, key, "")
    isempty(s) && return default
    parse(Int, s)
end

function main(args::Vector{String})
    if isempty(args) || args[1] in ("-h", "--help")
        println(stderr, "usage: julia --project=. scripts/autopilot.jl " *
                        "tick|status|pause|resume|drain|why|budget|retry [args]")
        return 2
    end
    cmd = args[1]
    rest = args[2:end]

    if cmd == "tick"
        dry = "--dry-run" in rest
        cfg = SpinorBEC.default_autopilot_config(; dry_run=dry)
        stats = autopilot_tick!(; config=cfg)
        println(dry ? "tick (DRY-RUN): " : "tick: ", stats)
        return 0

    elseif cmd == "status"
        s = autopilot_status()
        show(stdout, s)
        return 0

    elseif cmd == "pause"
        p = autopilot_pause!()
        println("paused at: ", p)
        return 0

    elseif cmd == "resume"
        ok = autopilot_resume!()
        println(ok ? "resumed" : "(no pause sentinel)")
        return 0

    elseif cmd == "drain"
        tmo = _kvf(rest, "timeout", 3600.0)
        ok = autopilot_drain_wait(timeout_s=tmo)
        println(ok ? "drained" : "drain timed out")
        return ok ? 0 : 1

    elseif cmd == "why"
        if isempty(rest)
            println(stderr, "why: needs <content_id>")
            return 2
        end
        chain = autopilot_why(rest[1])
        SpinorBEC.print_why(chain)
        return 0

    elseif cmd == "budget"
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
            println("  ", rpad(k, 24), v)
        end
        return 0

    elseif cmd == "retry"
        max_r = _kvi(rest, "max", 3)
        result = retry_failed!(; max_retries=max_r)
        println("retry: ", result)
        return 0

    else
        println(stderr, "unknown command: ", cmd)
        return 2
    end
end

exit(main(copy(ARGS)))
