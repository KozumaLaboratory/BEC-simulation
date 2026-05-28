# --- Catalog index: the navigable flat view over the CAS run store ---
#
# Two paths, deliberately split by cost:
#
#   run_catalog_index()   — CHEAP read path for /api/index. Reads only the
#       small sidecars (summary.json + state.toml) + mtime. NEVER opens
#       jld2, so it's safe to call synchronously on every HTTP request.
#       Runs without a summary.json appear as partial rows (has_summary
#       =false) — visible in status/family facets, correctly missing
#       observable axes. Nothing is hidden.
#
#   backfill_summaries!() — ONE-TIME slow path (the migration). Opens each
#       legacy run's jld2 once via write_run_summary and writes summary.json.
#       Resumable: skips dirs that already have one. After it runs, those
#       runs join the cheap path with full observables. Exposed via
#       `cli.jl catalog reindex`.
#
# The index is a derived, regenerable projection — truth stays in each
# run dir's jld2 + state.toml. Physical form is intentionally in-memory
# (computed per request); a central cache / DuckDB graduates in only when
# the row count makes the flat array too big to ship to the browser
# (~10^4+). At a few hundred runs, in-memory is milliseconds.

export run_catalog_index, backfill_summaries!, run_family

# Group key for the run index: the run name with its trailing content hash
# stripped, so sweep cells (same base, different hash) and re-runs collapse
# to one family. Pure-hash CAS dirs keep their hash (singleton family).
function run_family(name::AbstractString)
    fam = replace(String(name), r"_[0-9a-f]{8,}$" => "")
    isempty(fam) ? String(name) : fam
end

function _find_run_jld2(dir::AbstractString)
    isdir(dir) || return nothing
    files = readdir(dir)
    "point_001.jld2" in files && return joinpath(dir, "point_001.jld2")
    "result.jld2" in files && return joinpath(dir, "result.jld2")
    idx = findfirst(f -> startswith(f, "point_") && endswith(f, ".jld2"), files)
    idx === nothing ? nothing : joinpath(dir, files[idx])
end

_has_run_jld2(dir::AbstractString) = _find_run_jld2(dir) !== nothing

"""
    run_catalog_index(; runs_root=default_store().root) -> Vector{Dict{String,Any}}

One flat, sparse row per run, most-recently-touched first. Reads
summary.json (observables) + state.toml (autopilot status/provenance) +
mtime only — no jld2. A dir is a "run" if it has config.yaml, a jld2, or
a summary. Cheap enough to recompute per request.
"""
function run_catalog_index(; runs_root::AbstractString=default_store().root)
    rows = Dict{String, Any}[]
    isdir(runs_root) || return rows
    for d in readdir(runs_root; join=true)
        isdir(d) || continue
        name = basename(d)
        startswith(name, ".") && continue

        has_cfg = isfile(joinpath(d, "config.yaml"))
        has_jld2 = _has_run_jld2(d)
        sp = joinpath(d, RUN_SUMMARY_FILENAME)
        has_summary = isfile(sp)
        (has_cfg || has_jld2 || has_summary) || continue

        row = Dict{String, Any}(
            "name" => name,
            "family" => run_family(name),
            "mtime" => mtime(d),
            "has_summary" => has_summary,
            "has_jld2" => has_jld2,
        )

        if has_summary
            try
                merge!(row, JSON.parsefile(sp))
            catch e
                row["has_summary"] = false
                row["index_error"] = "summary parse: $(sprint(showerror, e))"
            end
        end

        # Autopilot status/provenance, when this run is queue-tracked.
        entry = try
            get_entry(d)
        catch
            nothing
        end
        if entry !== nothing
            row["status"] = String(entry.status)
            row["recipe"] =
                entry.recipe_name === nothing ? nothing : String(entry.recipe_name)
            row["group_id"] = entry.group_id
            row["enqueued_by"] = entry.enqueued_by
            isempty(entry.kill_reason) || (row["kill_reason"] = entry.kill_reason)
        end

        push!(rows, row)
    end
    sort!(rows; by=r -> -get(r, "mtime", 0.0))
    return rows
end

"""
    backfill_summaries!(; runs_root=default_store().root, force=false) -> Int

Write summary.json for every run that lacks one (the legacy migration).
Opens each run's jld2 once via `write_run_summary`. Resumable — skips dirs
that already have a summary unless `force`. Returns the count written.
One bad jld2 is logged and skipped, never aborts the sweep.
"""
function backfill_summaries!(; runs_root::AbstractString=default_store().root,
    force::Bool=false)
    isdir(runs_root) || return 0
    written = 0
    for d in readdir(runs_root; join=true)
        isdir(d) || continue
        startswith(basename(d), ".") && continue
        sp = joinpath(d, RUN_SUMMARY_FILENAME)
        (!force && isfile(sp)) && continue
        jld = _find_run_jld2(d)
        jld === nothing && continue
        try
            write_run_summary(d, jld; source="backfill")
            written += 1
        catch e
            @warn "backfill_summaries!: skipped" dir=d exception=e
        end
    end
    return written
end
