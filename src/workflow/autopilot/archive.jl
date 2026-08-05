# ── Archival policy ─────────────────────────────────────────────────
#
# Done/killed_data/killed_bug entries accumulate in runs/ over time. The
# dir scan that backs `list_queue` stays in millisecond territory at
# O(10³) entries but past that the per-tick walk hurts. This module
# moves terminal entries older than a threshold into `<qr.path>/_archive/`,
# preserving state.toml + _exit_summary.json + any small summary blobs and
# optionally compressing or dropping large psi.jld2 artefacts.
#
# Run periodically (monthly cron, or as part of the daily tick when
# a count threshold is crossed). NOT called automatically by
# `autopilot_tick!` — operator-driven.

export ArchivePolicy, default_archive_policy,
    archive_terminal!, archive_status

const _ARCHIVE_SUBDIR = "_archive"

"""
    ArchivePolicy

Per-state retention windows (days) plus a flag to keep `.jld2` artefacts
or not. `keep_jld2_for_done` defaults to true (recent successful runs
keep their data); killed_* defaults to false (only structured metadata
preserved).
"""
Base.@kwdef struct ArchivePolicy
    done_after_days::Int = 90
    killed_data_after_days::Int = 30
    killed_bug_after_days::Int = 14
    keep_jld2_for_done::Bool = true
    keep_jld2_for_killed::Bool = false
    archive_subdir::String = _ARCHIVE_SUBDIR
end

default_archive_policy() = ArchivePolicy()

"""
    archive_terminal!(; policy=default_archive_policy(),
                      qr=autopilot_queue_root(),
                      dry_run=false)
        -> NamedTuple

Walk done/killed_data/killed_bug entries; move ones older than the
policy's window into `<qr.path>/<archive_subdir>/<state>/<cid>/`. With
`dry_run=true`, only reports counts without moving anything.
"""
function archive_terminal!(;
    policy::ArchivePolicy=default_archive_policy(),
    qr::QueueRoot=autopilot_queue_root(),
    dry_run::Bool=false,
)
    archive_root = joinpath(qr.path, policy.archive_subdir)
    if !dry_run
        isdir(archive_root) || mkpath(archive_root)
    end
    now_ = now()
    moved = Dict{Symbol, Int}(:done => 0, :killed_data => 0, :killed_bug => 0)
    skipped = Dict{Symbol, Int}(:done => 0, :killed_data => 0, :killed_bug => 0)
    for st in (:done, :killed_data, :killed_bug)
        cutoff = now_ - Day(_days_for(policy, st))
        for entry in list_queue(st; qr=qr)
            if entry.enqueued_at >= cutoff
                skipped[st] += 1
                continue
            end
            keep_jld2 = st === :done ?
                        policy.keep_jld2_for_done : policy.keep_jld2_for_killed
            if dry_run
                moved[st] += 1
                continue
            end
            try
                _archive_one!(entry, archive_root; keep_jld2=keep_jld2)
                moved[st] += 1
            catch err
                @warn "archive failed" cid=entry.content_id exception=err
                skipped[st] += 1
            end
        end
    end
    return (moved=moved, skipped=skipped, archive_root=archive_root)
end

function _days_for(p::ArchivePolicy, state::Symbol)
    state === :done && return p.done_after_days
    state === :killed_data && return p.killed_data_after_days
    state === :killed_bug && return p.killed_bug_after_days
    return 365
end

function _archive_one!(entry::QueueEntry, archive_root::String;
    keep_jld2::Bool)
    dst_state_dir = joinpath(archive_root, String(entry.status))
    isdir(dst_state_dir) || mkpath(dst_state_dir)
    dst = joinpath(dst_state_dir, basename(entry.run_dir))
    isdir(dst) && return nothing    # already archived this cid; skip

    if keep_jld2
        # Move the entire dir intact.
        mv(entry.run_dir, dst)
    else
        # Move only metadata + outcome, drop large blobs.
        mkpath(dst)
        for name in readdir(entry.run_dir)
            src = joinpath(entry.run_dir, name)
            isfile(src) || continue
            # Keep only small structured files; drop *.jld2 / *.png / etc.
            if endswith(name, ".toml") || endswith(name, ".yaml") ||
                endswith(name, ".json") || endswith(name, ".reason")
                cp(src, joinpath(dst, name))
            end
        end
        # Remove the original (the meaningful metadata is in dst now).
        rm(entry.run_dir; recursive=true, force=true)
    end
    return dst
end

"""
    archive_status(; policy=default_archive_policy(),
                   qr=autopilot_queue_root()) -> Dict

Dry-run summary suitable for the dashboard / CLI: how many entries are
eligible for archival under the current policy, without moving anything.
"""
function archive_status(;
    policy::ArchivePolicy=default_archive_policy(),
    qr::QueueRoot=autopilot_queue_root(),
)
    result = archive_terminal!(; policy=policy, qr=qr, dry_run=true)
    Dict{String, Any}(
        "policy" => Dict{String, Any}(
            "done_after_days" => policy.done_after_days,
            "killed_data_after_days" => policy.killed_data_after_days,
            "killed_bug_after_days" => policy.killed_bug_after_days,
            "keep_jld2_for_done" => policy.keep_jld2_for_done,
            "keep_jld2_for_killed" => policy.keep_jld2_for_killed,
        ),
        "eligible" => Dict{String, Int}(
            "done" => result.moved[:done],
            "killed_data" => result.moved[:killed_data],
            "killed_bug" => result.moved[:killed_bug],
        ),
        "archive_root" => result.archive_root,
    )
end
