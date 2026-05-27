# --- Batch-level inspector (sweep across Vector{Experiment}) ----------
#
# Lifts the per-config inspector to sweeps. Catches:
#   (1) per-cell findings from the Check registry (same as inspect_config)
#   (2) :sweep_axis_silent_drift — keys that vary across cells but were
#       NOT in the declared sweep axis. Symptom: "I thought I was sweeping
#       loss.K3 but cell-to-cell my omega_ref is also moving."
#
# Markdown export (markdown_report) drops into research log / paper SI.

export inspect_batch, BatchInspection, markdown_report

struct BatchInspection
    inspections::Vector{ConfigInspection}
    cross_cell::Vector{ConfigWarning}
    declared_axes::Vector{String}          # paths the user said they're sweeping
end

"""
    inspect_batch(exps; expected_axes=String[], n_samples=64)
        -> BatchInspection

Run the inspector on every Experiment in `exps`. Per-cell findings live
in `inspections[i].warnings`. Batch-level findings live in `cross_cell`.

`expected_axes` lists the dotted paths the caller knows they are sweeping
(e.g. `["pipeline[3].dynamics.B.Bz.to"]`). Paths that vary across cells
but are NOT in this list become `:sweep_axis_silent_drift` findings. If
empty, every varying path is still reported as `:info` so the user can
audit "did I actually vary what I meant to vary".
"""
function inspect_batch(exps::AbstractVector;
    expected_axes::Vector{String}=String[],
    n_samples::Int=64,
    strict::Bool=true,
)
    inspections = ConfigInspection[]
    for (i, exp) in enumerate(exps)
        spec = _coerce_spec(exp)
        path = _coerce_label(exp, i)
        push!(inspections, _inspect_loaded(spec, path; n_samples, strict))
    end
    cross_cell = _inspect_cross_cell(inspections, expected_axes)
    return BatchInspection(inspections, cross_cell, expected_axes)
end

# Accept either an Experiment (with .spec) or a raw Dict.
_coerce_spec(exp) = hasproperty(exp, :spec) ? Dict{Any, Any}(exp.spec) : Dict{Any, Any}(exp)

function _coerce_label(exp, i::Int)
    if hasproperty(exp, :spec)
        # Best-effort content-id prefix.
        try
            cid = String(content_id(exp.spec))
            return "cell[$(i)]/$(cid[1:min(8, length(cid))])"
        catch
            return "cell[$(i)]"
        end
    end
    return "cell[$(i)]"
end

# --- Cross-cell drift detection -----------------------------------------

function _inspect_cross_cell(inspections::Vector{ConfigInspection},
    expected_axes::Vector{String})
    findings = ConfigWarning[]
    length(inspections) >= 2 || return findings

    # Take cell[1] as anchor; collect every path that differs from it
    # in at least one other cell. Aggregate by path.
    anchor = inspections[1].normalised
    drift_paths = Dict{String, Set{Int}}()    # path → set of cell indices that differ
    drift_values = Dict{String, Vector{Any}}()    # path → ordered values across cells

    # Seed drift_values with anchor's values; populate lazily.
    for (i, ins) in enumerate(inspections)
        i == 1 && continue
        d = diff_dicts(anchor, ins.normalised)
        for entry in d.changed
            p = path_string(entry.path)
            push!(get!(drift_paths, p, Set{Int}()), i)
        end
        for entry in d.added
            p = path_string(entry.path)
            push!(get!(drift_paths, p, Set{Int}()), i)
        end
        for entry in d.removed
            p = path_string(entry.path)
            push!(get!(drift_paths, p, Set{Int}()), i)
        end
    end

    # Emit findings: declared axes → :info (acknowledge); undeclared → :warn
    for (p, cells) in drift_paths
        is_declared = _matches_any_axis(p, expected_axes)
        if is_declared
            push!(
                findings,
                ConfigWarning(
                    :sweep_axis_declared, :info, 0,
                    "Declared sweep axis varies: `$(p)`",
                    "Path varies across cells $(sort(collect(cells))) (anchor = cell 1). " *
                    "This matches your `expected_axes`.",
                    "",
                    Dict{String, Any}("path" => p,
                        "cells" => sort(collect(cells))),
                ),
            )
        else
            sev = isempty(expected_axes) ? :info : :warn
            push!(
                findings,
                ConfigWarning(
                    :sweep_axis_silent_drift, sev, 0,
                    "Undeclared variation across cells: `$(p)`",
                    "Path differs between cells $(sort(collect(cells))) and " *
                    "cell 1 — but is not in your `expected_axes`. Either you " *
                    "are unintentionally varying more than the declared axis, " *
                    "or `expected_axes` is incomplete.",
                    "If this is intentional, add `$(p)` to expected_axes. " *
                    "If not, your sweep generator has an unintended degree of freedom.",
                    Dict{String, Any}("path" => p,
                        "cells" => sort(collect(cells))),
                ),
            )
        end
    end

    return findings
end

function _matches_any_axis(p::AbstractString, axes::Vector{String})
    for ax in axes
        # Either exact match or prefix match (so users can list a
        # subtree root and inspect_batch accepts any leaf below it).
        (p == ax || startswith(p, ax * ".") || startswith(p, ax * "[")) &&
            return true
    end
    return false
end

# --- Markdown export ----------------------------------------------------

"""
    markdown_report(batch::BatchInspection; title="Batch inspection") -> String

Produce a Markdown summary of the batch. Suitable for pasting into a
research log, PR description, or paper SI. Includes:

  - Per-cell summary table (counts of info/warn/error/block findings)
  - Cross-cell sweep-axis drift list
  - Per-kind aggregation across all cells (which findings recur)
"""
function markdown_report(batch::BatchInspection; title::String="Batch inspection")
    io = IOBuffer()
    println(io, "# ", title)
    println(io)
    println(io, "Cells: ", length(batch.inspections), "  ",
        if isempty(batch.declared_axes)
            "(no expected_axes declared)"
        else
            "declared axes: `" * join(batch.declared_axes, "`, `") * "`"
        end)
    println(io)

    # --- Per-cell summary ---
    println(io, "## Per-cell summary")
    println(io)
    println(io, "| Cell | Path | info | warn | error | block |")
    println(io, "|---|---|---:|---:|---:|---:|")
    for (i, ins) in enumerate(batch.inspections)
        c = _severity_counts(ins.warnings)
        println(io, "| ", i, " | `", _short_label(ins.path), "` | ",
            c[:info], " | ", c[:warn], " | ", c[:error], " | ", c[:block], " |")
    end
    println(io)

    # --- Cross-cell drift ---
    if !isempty(batch.cross_cell)
        println(io, "## Sweep axis audit")
        println(io)
        declared = filter(w -> w.kind === :sweep_axis_declared, batch.cross_cell)
        silent = filter(w -> w.kind === :sweep_axis_silent_drift, batch.cross_cell)
        if !isempty(declared)
            println(io, "### Declared axes (varying as intended)")
            for w in declared
                println(io, "- `", get(w.details, "path", "?"), "` — cells ",
                    get(w.details, "cells", []))
            end
            println(io)
        end
        if !isempty(silent)
            println(io, "### ⚠ Undeclared drift")
            for w in silent
                println(io, "- **`", get(w.details, "path", "?"), "`** — cells ",
                    get(w.details, "cells", []))
            end
            println(io)
        end
    end

    # --- Per-kind aggregation ---
    by_kind = Dict{Tuple{Symbol, String}, Vector{Int}}()    # (kind,title) → list of cells
    for (i, ins) in enumerate(batch.inspections)
        for w in ins.warnings
            push!(get!(by_kind, (w.kind, w.title), Int[]), i)
        end
    end
    if !isempty(by_kind)
        println(io, "## Findings by kind (across all cells)")
        println(io)
        for ((kind, ttitle), cells) in sort(collect(by_kind);
            by=p -> (string(p[1][1]), p[1][2]))
            unique_cells = sort(unique(cells))
            println(io, "- `", kind, "` (", length(unique_cells), " cells) — ",
                ttitle)
        end
        println(io)
    end

    return String(take!(io))
end

function _severity_counts(warnings::Vector{ConfigWarning})
    counts = Dict(:info => 0, :warn => 0, :error => 0, :block => 0)
    for w in warnings
        counts[w.severity] = get(counts, w.severity, 0) + 1
    end
    counts
end

_short_label(p::AbstractString) =
    length(p) <= 40 ? p : "…" * p[(end - 38):end]
