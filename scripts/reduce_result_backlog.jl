# Reduce EXISTING result.jld2 files to the summaries they are declared to be.
#
#   julia --project=. scripts/reduce_result_backlog.jl <root>            # DRY RUN
#   julia --project=. scripts/reduce_result_backlog.jl <root> --apply
#
# The forward fix (`make_result_a_summary!`, called when a point file lands) only
# helps runs written after it. The backlog measured 2026-08-21 is 136 pairs and
# 148.4 GB of result.jld2 on a volume with 693 GB free.
#
# This does NOT reimplement the reduction. It calls the same gated function, so
# every refusal — point file absent / short / differently shaped, rotating-basis
# runs whose point_NNN is a symlink at result.jld2 — is the one the unit tests
# canary. A sweep with its own copy of the safety logic is how the two drift.
#
# WHAT THIS ADDS is the one thing a sweep needs and the writer does not: it runs
# NEXT TO LIVE JOBS. A directory being written while it is rewritten loses data
# in a way no per-file check can catch, so the interference guard is first and it
# is deliberately conservative:
#
#   - `_live_status.json` present and touched within QUIET_S  -> skip
#   - ANY file in the directory touched within QUIET_S        -> skip
#
# The second one is the load-bearing one. `_live_status.json` is written by
# `run_yaml`; a campaign script or a hand-run job has none, and skipping only on
# the status file would sweep exactly those.
#
# DRY RUN IS THE DEFAULT and prints what each directory would do, because the
# failure mode is destroying the only copy of a multi-GB run and the check is
# cheap enough that there is no reason to skip it.

using SpinorBEC
using Printf

const QUIET_S = parse(Float64, get(ENV, "REDUCE_QUIET_S", "3600"))

"""Recently touched by anything — a job may still be writing here."""
function _is_live(dir::String)
    now_s = time()
    for (root, _, files) in walkdir(dir)
        for f in files
            p = joinpath(root, f)
            try
                (now_s - mtime(p)) < QUIET_S && return true
            catch
                continue        # vanished mid-walk: something IS writing
            end
        end
    end
    false
end

function main()
    length(ARGS) >= 1 || error("usage: reduce_result_backlog.jl <root> [--apply]")
    root = ARGS[1]
    apply = "--apply" in ARGS
    isdir(root) || error("not a directory: $root")

    @printf("%s over %s   (quiet window %.0f s)\n",
        apply ? "APPLYING" : "DRY RUN", root, QUIET_S)

    counts = Dict{Symbol, Int}()
    freed = 0
    for (dir, _, files) in walkdir(root)
        "result.jld2" in files || continue
        pts = sort([f for f in files if startswith(f, "point_") && endswith(f, ".jld2")])
        isempty(pts) && (counts[:no_point] = get(counts, :no_point, 0) + 1; continue)
        point = joinpath(dir, pts[1])
        res = joinpath(dir, "result.jld2")

        if _is_live(dir)
            counts[:live] = get(counts, :live, 0) + 1
            @printf("  live    %s\n", dir)
            continue
        end

        before = try
            filesize(res)
        catch
            0
        end
        st = if apply
            try
                make_result_a_summary!(dir, point)
            catch err
                @warn "reduction failed" dir exception = err
                :error
            end
        else
            # The same predicate the writer uses, without writing: ask it on a
            # scratch COPY so a dry run cannot modify anything by construction.
            mktempdir() do d
                cp(res, joinpath(d, "result.jld2"))
                # a hardlink would let the real file be rewritten; copy is the point
                symlink(abspath(point), joinpath(d, basename(point)))
                make_result_a_summary!(d, joinpath(d, basename(point)))
            end
        end
        counts[st] = get(counts, st, 0) + 1
        if st === :summarised
            after = apply ? filesize(res) : 0
            gain = apply ? before - after : before
            freed += gain
            @printf("  %-11s %6.2f GB  %s\n",
                apply ? "summarised" : "would free", gain / 2^30, dir)
        elseif st !== :already_summary
            @printf("  %-11s %s\n", String(st), dir)
        end
    end

    println()
    for (k, v) in sort(collect(counts); by=first)
        @printf("  %-18s %d\n", String(k), v)
    end
    @printf("  %-18s %.1f GB\n", apply ? "freed" : "recoverable", freed / 2^30)
    apply || println("\nDRY RUN — nothing was written. Re-run with --apply.")
end

main()
