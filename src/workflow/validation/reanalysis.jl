# --- reanalyze: one entry point for reading a stored run a NEW way ---
#
# Re-analysis is the cheapest kind of progress this project has: `97ec124e`
# corrected the EdH observable (the peak must be taken inside the hold) and
# re-extracted every affected number from the stored ψ with zero recompute — a
# whole 10.4 nT window correction paid for in seconds. #478 then measured why
# that is possible at all: 224 of 230 `point_*.jld2` carry `env/git_hash`, over
# 23 producing commits.
#
# So the tool is not what was missing. What was missing is the BOOKKEEPING, and
# the shape of the gap is the one this repo keeps re-learning:
#
#   * every re-analysis so far has been a bespoke driver (`klaus2022_reanalyse.jl`,
#     `scripts/validation/klaus_weff_extract.jl`), each re-implementing the window
#     and the reduction, and each writing its numbers with no record of WHICH
#     VINTAGE of run they came off;
#   * all 224 stamped points also record `git_dirty = true`, which cannot be
#     repaired afterwards, so a re-analysis result can never be campaign
#     evidence — and nothing in the output said so, leaving it indistinguishable
#     from a gated measurement once it reached a document;
#   * `SPINORBEC_ALLOW_STALE_POINTS=1` is the right switch here (no propagation
#     is being redone, so the code difference provably cannot reach the answer)
#     and exactly for that reason must never be set on the caller's behalf: a
#     silently-permissive process also reuses stale points on paths that DO
#     recompute.
#
# `reanalyze` is therefore a refusal as much as a reader. It will not return a
# number until the observable has been DEFINED (window / reduction / boundary —
# the ledger's own three fields, so a result can be pasted into `claims.toml`
# without re-deciding them), and what it returns carries its vintage and its own
# inadmissibility in machine-readable form.

export ObservableDefinition, RunVintage, Reanalysis
export reanalyze, run_vintage, reanalysis_record

"""
    REANALYSIS_WINDOWS

The windows a re-analysis may take a reduction over. A named set, because the
window is part of the measurement and "the whole trajectory" is a CHOICE that
has already been wrong once at production scale.

  `:all`         — every frame. Legal, and the default nowhere: at 10.4 nT four
                   arms differing only in the hold returned peak `P_adj` equal to
                   five decimals, because the maximum sat in the pre-hold
                   transient (argmax frame 29, hold from frame 32).
  `:last`        — the last `n` frames, `n` from `window_frames`. What "inside the
                   hold" means when the hold is the final step.
  `:first`       — the first `n` frames.
  `:range`       — an explicit `window_frames = lo:hi`.
  `:predicate`   — frames where `window_predicate(i, aux)` holds. For a window
                   defined by a physical condition rather than a frame count
                   (`klaus2022_reanalyse.jl` needs "frames where θ has reached 0").
"""
const REANALYSIS_WINDOWS = (:all, :last, :first, :range, :predicate)

"""
    REANALYSIS_REDUCTIONS

How a windowed series collapses to one number. `:max` / `:min` / `:mean` /
`:final` / `:first` / `:argmax` / `:argmin` / `:sum`.

`:max` and `:final` fail DIFFERENTLY — a peak is contaminated by a transient
that a mean only dilutes and a final sample ignores — which is why
`klaus_weff_extract.jl` keeps three readings and refuses an ordering they
disagree on. `reanalyze` computes all of them (`readings`) and reports the one
asked for, so that refusal is available without a second pass.
"""
const REANALYSIS_REDUCTIONS = (:max, :min, :mean, :final, :first, :argmax, :argmin, :sum)

"""
    ObservableDefinition(name; window, reduction, boundary, window_frames, window_predicate)

What was measured, stated before the number exists.

The three required fields are the ledger's (`window`, `reduction`, `boundary` in
`docs/campaign/claims.toml`), spelled the same way and validated against the same
sets, so a `Reanalysis` can be transcribed into a `[[claim]]` row without anyone
re-deciding what the window was. `boundary` must be one of
[`CLAIM_BOUNDARY_RULES`](@ref) — and `:unchecked` is a legal answer that reads as
"nobody looked", which is the whole point of it being a field.

`boundary = "reject"` is enforced, not recorded: an argmax landing on the edge of
its window is returned as a `boundary_hit` with the value withheld, because a
truncated maximum is not a peak.
"""
struct ObservableDefinition
    name::String
    window::Symbol
    reduction::Symbol
    boundary::String
    window_frames::Union{Nothing, Int, UnitRange{Int}}
    window_predicate::Union{Nothing, Function}

    function ObservableDefinition(name::AbstractString;
        window::Symbol,
        reduction::Symbol,
        boundary::AbstractString,
        window_frames::Union{Nothing, Int, UnitRange{Int}}=nothing,
        window_predicate::Union{Nothing, Function}=nothing,
    )
        isempty(strip(name)) && throw(
            ArgumentError(
                "ObservableDefinition: `name` is what the number will be called in a " *
                "document; an unnamed observable cannot be quoted"),
        )
        window in REANALYSIS_WINDOWS || throw(
            ArgumentError(
                "ObservableDefinition: window `$window` not one of $REANALYSIS_WINDOWS"),
        )
        reduction in REANALYSIS_REDUCTIONS || throw(
            ArgumentError(
                "ObservableDefinition: reduction `$reduction` not one of $REANALYSIS_REDUCTIONS"
            ),
        )
        boundary in CLAIM_BOUNDARY_RULES || throw(
            ArgumentError(
                "ObservableDefinition: boundary `$boundary` not one of " *
                "$CLAIM_BOUNDARY_RULES. These are the ledger's own values " *
                "(`CLAIM_BOUNDARY_RULES`); `unchecked` is legal and means nobody " *
                "looked, which must not be able to read as `reject`"),
        )
        if window in (:last, :first)
            window_frames isa Int && window_frames > 0 || throw(
                ArgumentError(
                    "ObservableDefinition: window `$window` needs `window_frames::Int > 0` " *
                    "(got $(repr(window_frames)))"),
            )
        elseif window === :range
            window_frames isa UnitRange{Int} && !isempty(window_frames) || throw(
                ArgumentError(
                    "ObservableDefinition: window `:range` needs a non-empty " *
                    "`window_frames::UnitRange{Int}` (got $(repr(window_frames)))"),
            )
        elseif window === :predicate
            window_predicate === nothing && throw(
                ArgumentError(
                    "ObservableDefinition: window `:predicate` needs `window_predicate`"),
            )
        end
        new(String(name), window, reduction, String(boundary),
            window_frames, window_predicate)
    end
end

"""
    RunVintage

Which code produced the points a re-analysis read.

Aggregated over the point files actually opened, not over the directory: a
re-analysis that read three of eight arms must say three. `commits` is sorted and
deduplicated; `counts` maps each producing commit to how many points came off it;
`n_dirty` counts points recording `git_dirty = true`; `n_unstamped` counts points
carrying no provenance at all.

`n_dirty > 0` is not an anomaly in this corpus — it is all 224 stamped points —
and it is the field that makes the result inadmissible, so it is carried rather
than summarised away.
"""
struct RunVintage
    commits::Vector{String}
    counts::Dict{String, Int}
    n_points::Int
    n_dirty::Int
    n_unstamped::Int
end

RunVintage() = RunVintage(String[], Dict{String, Int}(), 0, 0, 0)

"""
    Reanalysis

The result of reading stored runs a new way, plus everything needed to keep it
distinguishable from a gated measurement.

Fields:
* `observable`     — the [`ObservableDefinition`](@ref) this was reduced under
* `values`         — `Dict` point label → reduced value (`nothing` when withheld)
* `readings`       — `Dict` point label → NamedTuple of ALL reductions over the
                     same window, so "does the ordering survive the definition?"
                     is answerable without a second pass
* `boundary_hits`  — labels whose argmax landed on a window edge
* `windows`        — `Dict` point label → the frame range actually used
* `vintage`        — [`RunVintage`](@ref) over the points read
* `sources`        — the point files read, in order
* `declared`       — the caller's re-analysis declaration string
* `stale_env`      — whether `SPINORBEC_ALLOW_STALE_POINTS` was set in the
                     AMBIENT environment. `reanalyze` never sets it; recording
                     what it found is how a permissive process stops being
                     invisible
* `admissible`     — always `false`. Present as a field so a consumer branches on
                     data instead of on a human's note
* `inadmissible_because` — machine-readable reason strings

# Why `admissible` is a field and not a docstring

A re-analysis reads stored ψ and is exactly as good as the physics that produced
it. The three dominant vintages in this corpus (2026-05-21/23/26) predate the
June–July integrator, LHY and Zeeman corrections, and no provenance work changes
that. The failure this guards against is the one `klaus_protocol_sheet.md`
suffered: a correct retraction at the head of a document and the retracted value
still prescribed 160 lines later, because the STATUS of a number was not a thing
the tree could hold. Here it is a field on the value itself.
"""
struct Reanalysis
    observable::ObservableDefinition
    values::Dict{String, Union{Nothing, Float64}}
    readings::Dict{String, NamedTuple}
    boundary_hits::Vector{String}
    windows::Dict{String, UnitRange{Int}}
    vintage::RunVintage
    sources::Vector{String}
    declared::String
    stale_env::Bool
    admissible::Bool
    inadmissible_because::Vector{String}
end

"""
    REANALYSIS_DECLARATION

The value `reanalyze`'s `declare` argument must carry: an explicit statement that
this is a re-read of stored output rather than a computation.

A magic string rather than a `Bool` because the argument is the record. It lands
verbatim in `Reanalysis.declared` and in [`reanalysis_record`](@ref), so the
output says which mode produced it instead of leaving a reader to infer it from
which function was called.
"""
const REANALYSIS_DECLARATION = "reanalysis: stored output re-read, no propagation redone"

# Provenance for ONE point file. Reads only `env/*` — a 94 GiB point must not be
# materialised to answer "which commit wrote this".
function _point_provenance(path::AbstractString)
    JLD2.jldopen(path, "r") do d
        haskey(d, "env") || return (hash=nothing, dirty=true)
        g = d["env"]
        h = get(g, "git_hash", nothing)
        dirty = get(g, "git_dirty", true)
        (hash=(h === nothing ? nothing : String(h)), dirty=(dirty === true))
    end
end

"""
    run_vintage(paths) -> RunVintage

Aggregate `env/git_hash` and `env/git_dirty` over the given point files.

Unreadable and unstamped files are COUNTED, not skipped: "6 of 230 carry no
provenance" is the kind of number that turns a census into a measurement, and a
skip prints the same total as a clean corpus.
"""
function run_vintage(paths::AbstractVector{<:AbstractString})
    counts = Dict{String, Int}()
    n_dirty = 0
    n_unstamped = 0
    for p in paths
        pr = try
            _point_provenance(p)
        catch
            (hash=nothing, dirty=true)
        end
        if pr.hash === nothing
            n_unstamped += 1
        else
            counts[pr.hash] = get(counts, pr.hash, 0) + 1
        end
        pr.dirty && (n_dirty += 1)
    end
    RunVintage(sort!(collect(keys(counts))), counts, length(paths), n_dirty, n_unstamped)
end

"""
    reanalysis_point_files(run_dir) -> Vector{String}

Every `point_*.jld2` under `run_dir`, sorted. Directly under it, not recursively:
a run directory holds its own points, and descending would silently merge a
sibling scan.
"""
function reanalysis_point_files(run_dir::AbstractString)
    isdir(run_dir) || throw(ArgumentError("reanalyze: not a directory: $run_dir"))
    sort!([
        joinpath(run_dir, f) for f in readdir(run_dir)
        if startswith(f, "point_") && endswith(f, ".jld2")
    ])
end

# (label, path) pairs. One directory labels by point file; a SCAN — many
# directories, one arm each — labels by directory, because that is the coordinate
# the caller sweeps and `point_001.jld2` repeated 24 times is not a table.
_reanalysis_targets(run_dir::AbstractString) =
    [(basename(p), p) for p in reanalysis_point_files(run_dir)]

function _reanalysis_targets(run_dirs::AbstractVector{<:AbstractString})
    out = Tuple{String, String}[]
    for d in run_dirs
        ps = reanalysis_point_files(d)
        n = length(ps)
        for p in ps
            # A multi-point arm keeps the point in its label; a single-point arm
            # is named by its directory alone.
            push!(out, (n == 1 ? basename(d) :
                        string(basename(d), "/", basename(p)), p))
        end
    end
    out
end

# The frame range a window selects out of a series of length `n`.
function _window_range(obs::ObservableDefinition, n::Int, aux)
    n > 0 || throw(ArgumentError("reanalyze: empty series for `$(obs.name)`"))
    if obs.window === :all
        return 1:n
    elseif obs.window === :last
        return max(1, n - obs.window_frames + 1):n
    elseif obs.window === :first
        return 1:min(n, obs.window_frames)
    elseif obs.window === :range
        lo, hi = first(obs.window_frames), last(obs.window_frames)
        (lo >= 1 && hi <= n) || throw(
            ArgumentError(
                "reanalyze: window $(obs.window_frames) does not fit a series of " *
                "length $n. A window silently clipped to the data is how a reduction " *
                "starts reporting a different observable than the one declared"),
        )
        return lo:hi
    else
        keep = [i for i in 1:n if obs.window_predicate(i, aux) === true]
        isempty(keep) && throw(
            ArgumentError(
                "reanalyze: window predicate selected no frames out of $n for " *
                "`$(obs.name)`. An empty window is a failed selection, not a missing " *
                "value — a NaN here would be quoted as a measurement"),
        )
        keep == collect(first(keep):last(keep)) || throw(
            ArgumentError(
                "reanalyze: window predicate selected a non-contiguous set of frames " *
                "($(length(keep)) frames spanning $(first(keep)):$(last(keep))). " *
                "A reduction over a gapped window is not the observable its name says"),
        )
        return first(keep):last(keep)
    end
end

# All reductions over one window, in one pass. Cheap, and having them all is what
# makes "the ordering does not survive the definition" a checkable statement
# instead of a suspicion.
function _readings(series::AbstractVector{<:Real}, rng::UnitRange{Int})
    w = @view series[rng]
    imax = argmax(w)
    imin = argmin(w)
    (max=Float64(w[imax]), min=Float64(w[imin]),
        mean=Float64(sum(w) / length(w)), sum=Float64(sum(w)),
        final=Float64(w[end]), first=Float64(w[1]),
        argmax=Float64(first(rng) - 1 + imax),
        argmin=Float64(first(rng) - 1 + imin),
        n=length(w), from=first(rng), to=last(rng))
end

_pick(r::NamedTuple, reduction::Symbol) = getproperty(r, reduction)

# Did the argmax (or argmin) land on an edge of the window? Only meaningful for
# the extremum reductions — a mean has no argmax to truncate.
function _boundary_hit(obs::ObservableDefinition, r::NamedTuple, n_series::Int)
    k = if obs.reduction in (:max, :argmax)
        Int(r.argmax)
    elseif obs.reduction in (:min, :argmin)
        Int(r.argmin)
    else
        return false
    end
    # An edge of the WINDOW is only a truncation when there is data beyond it.
    # The last frame of the whole run is the end of the experiment, not a cut —
    # otherwise every `:final`-shaped peak would be flagged and the rule would be
    # the too-strict kind that gets switched off.
    (k == r.from && r.from > 1) || (k == r.to && r.to < n_series)
end

"""
    reanalyze(series, run_dir; observable, declare, verbose=true) -> Reanalysis

Read the stored points under `run_dir` a new way, and refuse to hand back a
number that cannot say what produced it.

`series(path) -> AbstractVector{<:Real}` (or `-> (series, aux)`) extracts the
per-frame quantity from ONE point file. `observable` is an
[`ObservableDefinition`](@ref) — the window, the reduction and the boundary rule,
required, before any value exists. `declare` must equal
[`REANALYSIS_DECLARATION`](@ref).

A point whose `series` returns `nothing` is recorded as missing rather than
skipped, and its label appears in `values` with a `nothing`: a run that did not
save the block must be visibly absent.

# What this does NOT do

It does not set `SPINORBEC_ALLOW_STALE_POINTS`, and it does not go through
`_assert_point_provenance` — nothing here recomputes, so there is no cached
result to admit or refuse. It records whether the variable was set in the ambient
environment (`Reanalysis.stale_env`), because a process that is globally
permissive will also reuse stale points on the paths that DO recompute, and that
is worth seeing in the output rather than in a shell history.

# Example — the observable `97ec124e` had to fix

```julia
obs = ObservableDefinition("peak P_adj in hold";
    window = :last, window_frames = 11,      # 5.5292 / (0.005 * 100)
    reduction = :max, boundary = "reject")
ra = reanalyze(dir; observable = obs, declare = REANALYSIS_DECLARATION) do path
    JLD2.jldopen(path, "r") do g
        haskey(g, "dynamics") || return nothing
        P = g["dynamics"]["component_populations"]
        [P[i, 2] + P[i, 3] for i in axes(P, 1)]
    end
end
ra.vintage.commits          # which code produced the arms
ra.admissible               # false, with reasons
```
"""
function reanalyze(series::Function,
    run_dir::Union{AbstractString, AbstractVector{<:AbstractString}};
    observable::ObservableDefinition,
    declare::AbstractString,
    verbose::Bool=true,
)
    declare == REANALYSIS_DECLARATION || throw(
        ArgumentError(
            "reanalyze: `declare` must be `REANALYSIS_DECLARATION`, i.e.\n  " *
            "\"$REANALYSIS_DECLARATION\"\ngot $(repr(declare)). This is not " *
            "ceremony: the declaration is what lands in the output, so a number read " *
            "off stored ψ says so where it is USED instead of where it was produced."),
    )

    labelled = _reanalysis_targets(run_dir)
    isempty(labelled) && throw(
        ArgumentError(
            "reanalyze: no `point_*.jld2` under $(repr(run_dir)). An empty read must " *
            "fail rather than return an empty result that reads as a null."),
    )

    values = Dict{String, Union{Nothing, Float64}}()
    readings = Dict{String, NamedTuple}()
    windows = Dict{String, UnitRange{Int}}()
    hits = String[]
    read_paths = String[]

    for (label, p) in labelled
        raw = series(p)
        if raw === nothing
            values[label] = nothing
            continue
        end
        s, aux = raw isa Tuple ? raw : (raw, nothing)
        s isa AbstractVector || throw(
            ArgumentError(
                "reanalyze: `series` for $label returned $(typeof(s)); expected an " *
                "AbstractVector of frame values (or `nothing` for a missing block)"),
        )
        rng = _window_range(observable, length(s), aux)
        r = _readings(s, rng)
        readings[label] = r
        windows[label] = rng
        hit = _boundary_hit(observable, r, length(s))
        hit && push!(hits, label)
        # `reject` WITHHOLDS the value. A truncated maximum is not a peak, and
        # returning it with a flag beside it is how `edh-two-branches-5p2nt` got
        # published: the flag was in the ledger and the number was in the prose.
        values[label] = if (hit && observable.boundary == "reject")
            nothing
        else
            Float64(_pick(r, observable.reduction))
        end
        push!(read_paths, p)
    end

    vintage = run_vintage(read_paths)
    stale_env = get(ENV, "SPINORBEC_ALLOW_STALE_POINTS", "0") == "1"

    why = String[]
    vintage.n_dirty > 0 && push!(why,
        "dirty_tree: $(vintage.n_dirty) of $(vintage.n_points) points record " *
        "git_dirty=true, so no commit identifies the code that produced them")
    vintage.n_unstamped > 0 && push!(why,
        "unstamped: $(vintage.n_unstamped) of $(vintage.n_points) points carry no " *
        "env/git_hash")
    length(vintage.commits) > 1 && push!(why,
        "mixed_vintage: $(length(vintage.commits)) producing commits across the " *
        "points read")
    push!(why,
        "not_ancestor_gated: a re-read of stored output does not re-run the " *
        "physics, so it inherits the vintage's correctness and has not passed " *
        "the campaign ancestor gate")

    ra = Reanalysis(observable, values, readings, hits, windows, vintage,
        read_paths, String(declare), stale_env, false, why)
    verbose && _print_reanalysis(ra)
    ra
end

reanalyze(run_dir::AbstractString; series::Function, kwargs...) =
    reanalyze(series, run_dir; kwargs...)

function _print_reanalysis(ra::Reanalysis)
    obs = ra.observable
    println("reanalyze: $(obs.name)")
    println(
        "  window    $(obs.window)" *
        (obs.window_frames === nothing ? "" : " $(obs.window_frames)") *
        "   reduction $(obs.reduction)   boundary $(obs.boundary)",
    )
    v = ra.vintage
    println(
        "  vintage   $(v.n_points) points, $(length(v.commits)) producing " *
        "commit(s), $(v.n_dirty) dirty, $(v.n_unstamped) unstamped",
    )
    isempty(v.commits) || println("            " *
            join(("$c×$(v.counts[c])" for c in v.commits), "  "))
    ra.stale_env && println(
        "  NOTE      SPINORBEC_ALLOW_STALE_POINTS=1 was already " *
        "set in the environment (not by reanalyze)",
    )
    isempty(ra.boundary_hits) ||
        println(
            "  boundary  argmax on a window edge in $(length(ra.boundary_hits)) " *
            "point(s): $(join(ra.boundary_hits, ", "))" *
            (obs.boundary == "reject" ? "  [value withheld]" : ""),
        )
    println("  ADMISSIBLE false — " * join(ra.inadmissible_because, "; "))
    nothing
end

"""
    reanalysis_record(ra) -> Dict{String,Any}

The machine-readable record of a re-analysis: the observable's three fields, the
vintage, the declaration, and `admissible = false` with its reasons.

Written as JSON beside a re-analysis output, or transcribed into a `[[claim]]`
row — `window` / `reduction` / `boundary` come out under the ledger's own names,
and `evidence_status` / `uncertainty_basis` are filled with what a re-read can
honestly claim rather than left for the transcriber to guess.
"""
function reanalysis_record(ra::Reanalysis)
    obs = ra.observable
    Dict{String, Any}(
        "observable" => obs.name,
        "window" =>
            string(obs.window) *
            (obs.window_frames === nothing ? "" : " $(obs.window_frames)"),
        "reduction" => string(obs.reduction),
        "boundary" => obs.boundary,
        "declared" => ra.declared,
        "allow_stale_points_ambient" => ra.stale_env,
        "vintage_commits" => ra.vintage.commits,
        "vintage_counts" => ra.vintage.counts,
        "n_points" => ra.vintage.n_points,
        "n_dirty" => ra.vintage.n_dirty,
        "n_unstamped" => ra.vintage.n_unstamped,
        "boundary_hits" => ra.boundary_hits,
        # Arm directory AND point file. `basename` alone printed
        # "point_001.jld2" five times, which is a list of nothing: across a scan
        # the arm is the coordinate and the point name is a constant.
        "sources" => [joinpath(basename(dirname(p)), basename(p)) for p in ra.sources],
        "values" => Dict{String, Any}(k => v for (k, v) in ra.values),
        "admissible" => ra.admissible,
        "inadmissible_because" => ra.inadmissible_because,
        # What a transcriber would otherwise have to decide. `absent` because the
        # stored points are not in the tree, and `none` because a re-read has no
        # convergence axis of its own — the axis belongs to the run it read.
        "evidence_status" => "absent",
        "uncertainty_basis" => "none",
        "uncertainty" =>
            "unbounded: a re-read of stored output at vintage " *
            (isempty(ra.vintage.commits) ? "<unstamped>" :
             join(ra.vintage.commits, "/")) *
            "; the uncertainty is the run's, not this reduction's",
    )
end
