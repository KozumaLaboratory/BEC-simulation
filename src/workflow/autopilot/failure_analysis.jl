# ── Failure analysis ─────────────────────────────────────────────────
#
# When a job lands in :killed_data / :killed_bug the operator wants
# "what broke?" in one sentence — not 5000 lines of Julia stacktrace.
# `analyze_failure` walks the per-run artefacts in order of authority
# (outcome.toml > _exit_summary.json > stderr.log tail > backend reason
# > kill_reason) and returns a structured summary the dashboard can
# render as a compact badge with a hover-title for the full trail.
#
# Categories the operator cares about:
#   :oom             OOM-killed (resource permanent — bump profile)
#   :timeout         walltime exceeded (resource permanent — bump time)
#   :nan_cascade     numerical blowup (physics — config / dt / tol)
#   :missing_dep     "Package X is required but not installed"
#   :config_error    inspector-style YAML / atom geometry / unit issue
#   :scheduler_kill  NODE_FAIL / PREEMPTED (transient — retry)
#   :other_julia     julia raised some other exception
#   :unknown         no recognisable signal — punt to operator
#
# Categorisation is best-effort; the structured `summary` string is
# the load-bearing UX. `details` carries the matched evidence so the
# dashboard tooltip shows WHY we classified that way.

export FailureAnalysis, analyze_failure

"""
    FailureAnalysis

Result of `analyze_failure(entry)`. `category` is one of the symbols
listed above; `summary` is a one-line operator-readable string;
`details` is the verbatim text we matched on (stderr tail / outcome
reason / etc) for audit.
"""
struct FailureAnalysis
    category::Symbol
    summary::String
    details::String
end

"""
    analyze_failure(entry::QueueEntry) -> FailureAnalysis

Classify a terminal-failed entry. Walks artefacts under
`entry.run_dir` (outcome.toml / _exit_summary.json / stderr.log) plus
`entry.kill_reason`, returns the most informative categorisation.

Cheap (≤ 1 stderr file read, bounded to last 8 KB). Safe to call
from the dashboard `/api/queue/why` route on demand.
"""
function analyze_failure(entry::QueueEntry)
    # 1. outcome.toml — `run_yaml` writes a structured terminal record.
    outcome_path = joinpath(entry.run_dir, OUTCOME_FILENAME)
    if isfile(outcome_path)
        d = try
            TOML.parsefile(outcome_path)
        catch
            nothing
        end
        if d isa AbstractDict
            outcome = get(d, "outcome", Dict())
            reason = strip(String(get(outcome, "reason", "")))
            if !isempty(reason) && reason != "no reason"
                cat = _category_from_reason(reason)
                return FailureAnalysis(cat, reason, "outcome.toml: $(reason)")
            end
        end
    end

    # 2. _exit_summary.json — `run_yaml`'s atexit hook stamps this with
    #    exception_type / nan_encountered / oom_killed flags.
    exit_path = joinpath(entry.run_dir, "_exit_summary.json")
    if isfile(exit_path)
        d = try
            JSON.parsefile(exit_path)
        catch
            nothing
        end
        if d isa AbstractDict
            if Bool(get(d, "nan_encountered", false))
                return FailureAnalysis(:nan_cascade,
                    "NaN encountered at step $(get(d, "last_step", "?"))",
                    "_exit_summary.json: nan_encountered=true")
            end
            if Bool(get(d, "oom_killed", false))
                return FailureAnalysis(:oom,
                    "OOM-killed by runtime",
                    "_exit_summary.json: oom_killed=true")
            end
            ex = String(get(d, "exception_type", ""))
            if !isempty(ex)
                cat = ex == "InterruptException" ? :scheduler_kill : :other_julia
                return FailureAnalysis(cat,
                    "Julia $(ex) at step $(get(d, "last_step", "?"))",
                    "_exit_summary.json: exception_type=$(ex)")
            end
        end
    end

    # 3. stderr.log tail — last 8 KB to find ERROR lines.
    stderr_path = joinpath(entry.run_dir, "stderr.log")
    if isfile(stderr_path)
        tail = _stderr_tail(stderr_path, 8 * 1024)
        if !isempty(tail)
            cat, summary = _classify_stderr_tail(tail)
            if cat !== :unknown
                return FailureAnalysis(cat, summary, "stderr.log tail: $(tail)")
            end
        end
    end

    # 4. kill_reason on the entry — set by the autopilot itself (OOM
    #    via sacct, timeout, etc).
    if !isempty(entry.kill_reason)
        cat = _category_from_reason(entry.kill_reason)
        return FailureAnalysis(cat, entry.kill_reason,
            "kill_reason: $(entry.kill_reason)")
    end

    return FailureAnalysis(:unknown,
        "No recognisable failure signal in artefacts",
        "checked outcome.toml / _exit_summary.json / stderr.log / kill_reason")
end

# ── classifier rules ────────────────────────────────────────────────

function _category_from_reason(s::AbstractString)
    s_lc = lowercase(String(s))
    occursin(r"out_of_memory|oom_killed|oom\b"i, s_lc) && return :oom
    occursin(r"timeout|walltime"i, s_lc) && return :timeout
    occursin(r"node_fail|preempted|interrupt"i, s_lc) && return :scheduler_kill
    occursin(r"nan"i, s_lc) && return :nan_cascade
    occursin(r"is required but does not seem to be installed"i, s_lc) &&
        return :missing_dep
    occursin(r"argumenterror|geometry|valid|inspector"i, s_lc) && return :config_error
    return :other_julia
end

function _classify_stderr_tail(tail::AbstractString)
    if occursin(r"is required but does not seem to be installed"i, tail)
        m = match(r"Package ([A-Za-z_][A-Za-z0-9_]*)", tail)
        pkg = m === nothing ? "?" : m.captures[1]
        return (:missing_dep, "Package $(pkg) not installed on the runtime")
    end
    if occursin(r"OUT_OF_MEMORY|oom_killed"i, tail)
        return (:oom, "OOM (matched in stderr tail)")
    end
    if occursin(r"NaN encountered|NaN at step"i, tail)
        return (:nan_cascade, "NaN encountered (matched in stderr tail)")
    end
    if occursin(r"signal \(11\)|Segmentation fault"i, tail)
        return (:other_julia, "Segmentation fault (Julia atexit or native lib)")
    end
    m = match(r"ERROR:\s*([A-Za-z]+(?:Error|Exception)):\s*(.+)", tail)
    if m !== nothing
        kind = m.captures[1]
        msg = strip(m.captures[2])
        cat =
            kind in ("ArgumentError", "DomainError", "InexactError") ?
            :config_error : :other_julia
        # Trim very long messages so the summary stays one-line readable.
        if length(msg) > 120
            msg = msg[1:117] * "..."
        end
        return (cat, "$(kind): $(msg)")
    end
    return (:unknown, "")
end

function _stderr_tail(path::AbstractString, max_bytes::Int)
    sz = stat(path).size
    sz == 0 && return ""
    open(path, "r") do io
        seek(io, max(0, sz - max_bytes))
        String(read(io))
    end
end
