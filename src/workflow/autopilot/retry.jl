# ── Retry classification ──────────────────────────────────────────────
#
# When a job lands in killed_bug, the retry pass consults _exit_summary.json
# (or the backend's post-mortem reason) and decides:
#
#   TRANSIENT             → re-enqueue with attempt+1, same profile
#   RESOURCE_PERMANENT    → re-enqueue with attempt+1, ESCALATED profile
#                           (e.g. OOM → larger memory class)
#   PERMANENT             → leave in killed_bug, no retry
#   UNKNOWN_CLASS         → treated as TRANSIENT (give it one more shot)
#
# killed_data entries are NEVER retried automatically — they carry data
# value (divergence is information, not failure) and a re-run would
# produce the same divergence with the same params.

export retry_failed!, RetryClassification, classify_failure

@enum RetryClassification PERMANENT TRANSIENT RESOURCE_PERMANENT UNKNOWN_CLASS

"""
    classify_failure(outcome::AbstractDict, backend_reason::AbstractString="")
        -> RetryClassification

Pure predicate. `outcome` is the parsed `_exit_summary.json`
(or empty). `backend_reason` is the scheduler post-mortem string.
"""
function classify_failure(outcome::AbstractDict, backend_reason::AbstractString="")
    # Outcome.toml takes precedence — it's the simulator's own report.
    nan_enc = get(outcome, "nan_encountered", false) === true
    nan_enc && return PERMANENT

    # `oom_killed` FIRST — and this arm really is first now. It sat BELOW the
    # `exception_type` block until 2026-08-07 while its own comment said
    # otherwise, so a GPU OOM (which sets both fields) matched the generic
    # "unrecognised exception -> PERMANENT" arm and never reached here. The
    # resource class was therefore never escalated and the job was re-queued at
    # the same size.
    get(outcome, "oom_killed", false) === true && return RESOURCE_PERMANENT

    exc = get(outcome, "exception_type", "")
    if exc isa AbstractString && !isempty(exc)
        # An OOM-shaped exception name is resource-permanent even if the Bool was
        # not set — a second reader of the same fact, because the Bool depends on
        # `_is_oom_error` having heard of the type.
        occursin(r"OutOfGPUMemory|OutOfMemory"i, exc) && return RESOURCE_PERMANENT
        if occursin(r"InterruptException|SystemError|IOError|ProcessExitedException"i, exc)
            return TRANSIENT
        end
        return PERMANENT
    end

    # Free-text `reason` field — kept for LocalBackend and for any backend whose
    # reason string does speak this vocabulary. It is now a fallback behind a
    # Boolean rather than the only route.
    outcome_reason = get(outcome, "reason", "")
    combined = String(outcome_reason) * " | " * String(backend_reason)
    if occursin(r"OUT_OF_MEMORY|OOM_KILLED|OOM\b"i, combined)
        return RESOURCE_PERMANENT      # escalate memory profile
    elseif occursin(r"TIMEOUT"i, combined)
        return RESOURCE_PERMANENT      # escalate walltime profile
    elseif occursin(r"NODE_FAIL|PREEMPTED"i, combined)
        return TRANSIENT
    end
    return UNKNOWN_CLASS
end

"""
    retry_failed!(; max_retries=3, qr=autopilot_queue_root(),
                  backend=LocalBackend())
        -> (retried::Int, escalated::Int, abandoned::Int)

Walk killed_bug entries, classify each, and re-enqueue retryable ones.
RESOURCE_PERMANENT re-enqueues with `next_profile(entry.profile)` —
escalates to a larger resource class. TRANSIENT keeps the same profile.
PERMANENT stays in killed_bug.
"""
function retry_failed!(;
    max_retries::Int=3,
    qr::QueueRoot=autopilot_queue_root(),
    backend::AutopilotBackend=LocalBackend(),
)
    retried = 0
    escalated = 0
    abandoned = 0
    for entry in list_queue(:killed_bug; qr=qr)
        outcome = _load_outcome(entry)
        backend_reason = _backend_reason(entry, backend)
        cls = classify_failure(outcome, backend_reason)

        if entry.attempt >= max_retries
            abandoned += 1
            continue
        end
        if cls === PERMANENT
            abandoned += 1
            continue
        elseif cls === RESOURCE_PERMANENT
            next = next_profile(backend, entry.profile)
            if next === nothing
                abandoned += 1                 # no larger class; give up
                continue
            end
            entry.profile = next
            entry.attempt += 1
            entry.job_id = nothing
            entry.status = :pending
            entry.kill_reason = ""
            save_entry!(entry)
            escalated += 1
        else                                    # TRANSIENT or UNKNOWN_CLASS
            entry.attempt += 1
            entry.job_id = nothing
            entry.status = :pending
            entry.kill_reason = ""
            save_entry!(entry)
            retried += 1
        end
    end
    return (retried=retried, escalated=escalated, abandoned=abandoned)
end

function _load_outcome(entry::QueueEntry)
    d = _read_exit_summary(entry)
    d === nothing ? Dict{String, Any}() : d
end

function _backend_reason(entry::QueueEntry, backend::AutopilotBackend)
    try
        backend_failure_reason(backend, entry)
    catch
        ""
    end
end
