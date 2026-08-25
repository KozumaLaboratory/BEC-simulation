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
#
# WHAT THE MIGRATION OF THE REMAINING DRIVERS ADDED (2026-08-26). Three of the
# four stored-run readers were left un-migrated when this landed, and two carried
# the SAME reason: one pass over an expensive file yields many quantities
# (`klaus_weff_cloud_size.jl` nine off two series; `klaus2022_reanalyse.jl` seven
# per window, each frame costing an FFT), and a one-observable-per-call entry
# point would have meant re-reading streamed ψ snapshots once per number. That is
# what `observables = [...]` is for: ONE read of each file, every declared
# observable reduced off it, one shared vintage. A deferral whose reason two
# callers share is a missing API, not a deferral.
#
# And migrating the third — `lt64_endpoint_verdict.jl` — turned up a defect in
# THIS file. Its header records that the suite's first run used the wrong
# `save_every`, computed a 200-frame hold window over a 20-frame array, silently
# clamped it to the whole trajectory, and reported the pre-hold transient as the
# hold peak; it was caught only because one group of three had a stored number to
# check against. `_window_range` reproduced that clamp exactly (`max(1, n - w + 1)`)
# while `:range` next to it refused to clip. An over-long `:last` / `:first`
# window is now the same refusal, per point, named.

export RunVintage, Reanalysis, MultiReanalysis
export reanalyze, run_vintage, reanalysis_record

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
* `values`         — `Dict` point label → reduced value (`nothing` when withheld
                     or when the point could not supply the series)
* `readings`       — `Dict` point label → NamedTuple of ALL reductions over the
                     same window, so "does the ordering survive the definition?"
                     is answerable without a second pass
* `failures`       — `Dict` point label → why no number came off it. Distinct
                     from a `nothing` value: "the block is absent" and "the
                     declared window does not fit this arm" are different facts
* `boundary_hits`  — labels whose argmax landed on a window edge
* `windows`        — `Dict` point label → the frame range actually used
* `vintage`        — [`RunVintage`](@ref) over the points read
* `sources`        — the point files read, in order
* `paths`          — `Dict` point label → the file it came off. A row in a table
                     has to be able to name its own file; `sources` is the read
                     order and answers a different question
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
    failures::Dict{String, String}
    boundary_hits::Vector{String}
    windows::Dict{String, UnitRange{Int}}
    vintage::RunVintage
    sources::Vector{String}
    paths::Dict{String, String}
    declared::String
    stale_env::Bool
    admissible::Bool
    inadmissible_because::Vector{String}
end

"""
    MultiReanalysis

Several observables reduced off ONE read of each stored file, sharing one
vintage.

`results` maps observable name → [`Reanalysis`](@ref); `order` keeps the
declaration order, because the caller's table has columns in an order and a
`Dict` does not. Index it by name: `ra["r at hold start"]`.

The reason this exists rather than N calls: the expensive half of a re-analysis
is the READ. `klaus_weff_cloud_size.jl` takes nine numbers off two series of
streamed ψ snapshots, and `klaus2022_reanalyse.jl` pays an FFT per frame before
any reduction happens. Reducing one observable per pass would multiply that by
nine and by seven — which is exactly the pressure that keeps producing bespoke
drivers with the window written inline.

Every result carries the same `vintage`, `sources`, `declared`, `stale_env` and
`inadmissible_because`, so a single observable lifted out of the group is still
self-describing where it lands.
"""
struct MultiReanalysis
    results::Dict{String, Reanalysis}
    order::Vector{String}
    vintage::RunVintage
    sources::Vector{String}
    paths::Dict{String, String}
    declared::String
    stale_env::Bool
    admissible::Bool
    inadmissible_because::Vector{String}
end

Base.getindex(m::MultiReanalysis, name::AbstractString) = m.results[String(name)]
Base.haskey(m::MultiReanalysis, name::AbstractString) = haskey(m.results, String(name))
Base.keys(m::MultiReanalysis) = m.order
Base.length(m::MultiReanalysis) = length(m.order)

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

# Provenance for ONE stored file. Reads only `env/*` — a 94 GiB point must not be
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

Aggregate `env/git_hash` and `env/git_dirty` over the given stored files.

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

# (label, path) pairs, `path === nothing` for a target that holds no stored file.
# One directory labels by point file; a SCAN — many directories, one arm each —
# labels by directory, because that is the coordinate the caller sweeps and
# `point_001.jld2` repeated 24 times is not a table. An explicit FILE is taken as
# given: not every stored artifact is a `point_*.jld2` (`klaus2022_reanalyse.jl`
# reads `*_frames.jld2`), and a reader restricted to one filename would have sent
# that driver back to reading the file itself.
function _reanalysis_targets(target::AbstractString)
    isfile(target) && return Tuple{String, Union{Nothing, String}}[(basename(target), target)]
    Tuple{String, Union{Nothing, String}}[(basename(p), p)
                                          for p in reanalysis_point_files(target)]
end

function _reanalysis_targets(targets::AbstractVector{<:AbstractString})
    out = Tuple{String, Union{Nothing, String}}[]
    for t in targets
        if isfile(t)
            push!(out, (basename(t), t))
            continue
        end
        ps = reanalysis_point_files(t)
        if isempty(ps)
            # NAMED, NOT VANISHED. An arm whose directory exists but holds no
            # point file is the shape of a job that died before its first save,
            # and dropping it here is how a gap in the corpus becomes a structure
            # in the scan.
            push!(out, (basename(t), nothing))
            continue
        end
        n = length(ps)
        for p in ps
            push!(out, (n == 1 ? basename(t) :
                        string(basename(t), "/", basename(p)), p))
        end
    end
    out
end

# What one point supplied for one observable: a series, a declared absence, or a
# named failure. The three are different facts and the caller's table has to be
# able to print them differently.
function _select_series(payload, obs::ObservableDefinition, multi::Bool)
    key = obs.series_key
    if multi || (key !== nothing && (payload isa AbstractDict || payload isa NamedTuple))
        key === nothing && throw(
            ArgumentError(
                "reanalyze: observable `$(obs.name)` has no `series = ` key. With " *
                "several observables over one read, each must say which extracted " *
                "series it reduces"),
        )
        got = if payload isa AbstractDict
            haskey(payload, key) ? payload[key] : :absent
        elseif payload isa NamedTuple
            hasproperty(payload, Symbol(key)) ? getproperty(payload, Symbol(key)) : :absent
        else
            throw(
                ArgumentError(
                    "reanalyze: with several observables the extractor must return a " *
                    "Dict or NamedTuple of named series (got $(typeof(payload)))"),
            )
        end
        got === :absent && throw(
            ArgumentError(
                "reanalyze: observable `$(obs.name)` asks for series `$key`, which " *
                "the extractor did not return. Available: " *
                "$(payload isa AbstractDict ? collect(keys(payload)) : keys(payload))"),
        )
        return got
    end
    payload
end

# One (label, path) against the whole observable list — ONE read, N reductions.
function _reduce_point!(acc, label, payload, aux, observables, multi)
    for obs in observables
        a = acc[obs.name]
        s = _select_series(payload, obs, multi)
        if s === nothing
            a.values[label] = nothing            # the block is absent: visible
            continue
        elseif s isa AbstractString
            a.values[label] = nothing
            a.failures[label] = String(s)        # named, not dropped
            continue
        end
        s isa AbstractVector || throw(
            ArgumentError(
                "reanalyze: `series` for $label / `$(obs.name)` returned $(typeof(s)); " *
                "expected an AbstractVector of frame values, `nothing` for a missing " *
                "block, or a String naming why it could not be read"),
        )
        rng = try
            _window_range(obs, length(s), aux)
        catch err
            err isa ArgumentError || rethrow()
            # A window that does not fit THIS arm is a fact about the arm. It is
            # recorded per point so one short arm cannot silence nineteen good
            # ones — and if nothing at all reduced, `reanalyze` throws instead of
            # handing back a table of blanks.
            a.values[label] = nothing
            a.failures[label] = sprint(showerror, err)
            continue
        end
        r = _readings(s, rng)
        a.readings[label] = r
        a.windows[label] = rng
        hit = _boundary_hit(obs, r, length(s))
        hit && push!(a.boundary_hits, label)
        # `reject` WITHHOLDS the value. A truncated maximum is not a peak, and
        # returning it with a flag beside it is how `edh-two-branches-5p2nt` got
        # published: the flag was in the ledger and the number was in the prose.
        a.values[label] = if (hit && obs.boundary == "reject")
            nothing
        else
            Float64(_pick(r, obs.reduction))
        end
    end
    nothing
end

function _reanalysis_core(series::Function, run_dir, observables, declare, multi)
    declare == REANALYSIS_DECLARATION || throw(
        ArgumentError(
            "reanalyze: `declare` must be `REANALYSIS_DECLARATION`, i.e.\n  " *
            "\"$REANALYSIS_DECLARATION\"\ngot $(repr(declare)). This is not " *
            "ceremony: the declaration is what lands in the output, so a number read " *
            "off stored ψ says so where it is USED instead of where it was produced."),
    )
    isempty(observables) && throw(
        ArgumentError("reanalyze: no observable given; the definition comes first"))
    names = [o.name for o in observables]
    allunique(names) || throw(
        ArgumentError(
            "reanalyze: observable names must be unique — they are the keys of the " *
            "result and the headings of the table. Repeated: " *
            "$(unique([n for n in names if count(==(n), names) > 1]))"),
    )

    labelled = _reanalysis_targets(run_dir)
    isempty(labelled) && throw(
        ArgumentError(
            "reanalyze: no `point_*.jld2` under $(repr(run_dir)). An empty read must " *
            "fail rather than return an empty result that reads as a null."),
    )

    acc = Dict(
        o.name => (
            values=Dict{String, Union{Nothing, Float64}}(),
            readings=Dict{String, NamedTuple}(),
            failures=Dict{String, String}(),
            windows=Dict{String, UnitRange{Int}}(),
            boundary_hits=String[],
        ) for o in observables
    )
    read_paths = String[]
    label_paths = Dict{String, String}()

    for (label, p) in labelled
        if p === nothing
            for o in observables
                acc[o.name].values[label] = nothing
                acc[o.name].failures[label] = "no stored point file under this target"
            end
            continue
        end
        raw = series(p)
        if raw === nothing
            for o in observables
                acc[o.name].values[label] = nothing
            end
            continue
        elseif raw isa AbstractString
            for o in observables
                acc[o.name].values[label] = nothing
                acc[o.name].failures[label] = String(raw)
            end
            continue
        end
        payload, aux = raw isa Tuple ? raw : (raw, nothing)
        _reduce_point!(acc, label, payload, aux, observables, multi)
        push!(read_paths, p)
        label_paths[label] = p
    end

    # ALL FAILED IS NOT A NULL. A read where every point refused — an impossible
    # window, an extractor that could not open anything — must not come back as a
    # table of blanks that a caller prints as "no effect".
    if isempty(read_paths) || all(o -> all(isnothing, values(acc[o.name].values)) &&
                !isempty(acc[o.name].failures), observables)
        reasons = unique(vcat([collect(values(acc[o.name].failures))
                               for o in observables]...))
        isempty(reasons) || throw(
            ArgumentError(
                "reanalyze: no point could be reduced under " *
                "$(join(("`$n`" for n in names), ", ")). " *
                "$(length(labelled)) target(s) read, every one refused:\n  " *
                join(unique(reasons), "\n  ")),
        )
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

    results = Dict(
        o.name => Reanalysis(o, acc[o.name].values, acc[o.name].readings,
            acc[o.name].failures, acc[o.name].boundary_hits, acc[o.name].windows,
            vintage, read_paths, label_paths, String(declare), stale_env, false, why)
        for o in observables
    )
    (results=results, order=names, vintage=vintage, sources=read_paths,
        paths=label_paths, stale_env=stale_env, why=why)
end

"""
    reanalyze(series, run_dir; observable, declare, verbose=true) -> Reanalysis
    reanalyze(series, run_dirs; observables, declare, verbose=true) -> MultiReanalysis

Read the stored output under `run_dir` a new way, and refuse to hand back a
number that cannot say what produced it.

`series(path)` extracts the per-frame quantity from ONE stored file and may
return:

* an `AbstractVector` of frame values (the single-observable form),
* a `Dict` / `NamedTuple` of named series (required with `observables`; each
  observable names its own with `series = `),
* `(payload, aux)`, where `aux` is whatever a `:predicate` window reads,
* `nothing` — the block is absent, recorded as a missing value,
* a `String` — why this arm could not be read, recorded in `failures`. An arm
  that vanishes silently is how a gap in the corpus becomes a structure in a scan.

`run_dir` may be a run directory (its `point_*.jld2` are read), an explicit
stored FILE (`*_frames.jld2` is a stored artifact too), or a vector of either.

`observable` / `observables` are [`ObservableDefinition`](@ref)s — the window, the
reduction and the boundary rule, required, before any value exists. Several
observables are reduced off ONE read of each file, which is what makes migrating
a driver that takes nine numbers per pass cheaper than keeping it bespoke.
`declare` must equal [`REANALYSIS_DECLARATION`](@ref).

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
    window = :last,
    window_frames = hold_window_frames(5.5292; dt = 0.005, save_every = 100),
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
    observable::Union{Nothing, ObservableDefinition}=nothing,
    observables::Union{Nothing, AbstractVector{ObservableDefinition}}=nothing,
    declare::AbstractString,
    verbose::Bool=true,
)
    # ONE method, not two: Julia dispatches on positional arguments only, so a
    # second method differing solely in its keywords would silently REPLACE this
    # one.
    (observable === nothing) == (observables === nothing) && throw(
        ArgumentError(
            "reanalyze: give exactly one of `observable = ` (one definition, " *
            "returns a Reanalysis) or `observables = [...]` (several off one read, " *
            "returns a MultiReanalysis)"),
    )
    if observable !== nothing
        c = _reanalysis_core(series, run_dir, (observable,), declare, false)
        ra = c.results[observable.name]
        verbose && _print_reanalysis(ra)
        return ra
    end
    c = _reanalysis_core(series, run_dir, observables, declare, true)
    m = MultiReanalysis(c.results, c.order, c.vintage, c.sources, c.paths,
        String(declare), c.stale_env, false, c.why)
    verbose && _print_multi_reanalysis(m)
    m
end

reanalyze(run_dir::AbstractString; series::Function, kwargs...) =
    reanalyze(series, run_dir; kwargs...)

function _print_observable_line(obs::ObservableDefinition)
    println(
        "  window    $(obs.window)" *
        (obs.window_frames === nothing ? "" : " $(obs.window_frames)") *
        "   reduction $(obs.reduction)   boundary $(obs.boundary)" *
        (obs.series_key === nothing ? "" : "   series $(obs.series_key)"),
    )
end

function _print_vintage(ra_vintage::RunVintage, stale_env::Bool, why::Vector{String})
    v = ra_vintage
    println(
        "  vintage   $(v.n_points) points, $(length(v.commits)) producing " *
        "commit(s), $(v.n_dirty) dirty, $(v.n_unstamped) unstamped",
    )
    isempty(v.commits) || println("            " *
            join(("$c×$(v.counts[c])" for c in v.commits), "  "))
    stale_env && println(
        "  NOTE      SPINORBEC_ALLOW_STALE_POINTS=1 was already " *
        "set in the environment (not by reanalyze)",
    )
    println("  ADMISSIBLE false — " * join(why, "; "))
end

function _print_failures(ra::Reanalysis)
    isempty(ra.failures) && return nothing
    println("  UNREAD    $(length(ra.failures)) target(s) produced no value:")
    for k in sort!(collect(keys(ra.failures)))
        println("            $k : $(first(ra.failures[k], 120))")
    end
end

function _print_boundary(ra::Reanalysis)
    isempty(ra.boundary_hits) && return nothing
    println(
        "  boundary  argmax on a window edge in $(length(ra.boundary_hits)) " *
        "point(s): $(join(ra.boundary_hits, ", "))" *
        (ra.observable.boundary == "reject" ? "  [value withheld]" : ""),
    )
end

function _print_reanalysis(ra::Reanalysis)
    println("reanalyze: $(ra.observable.name)")
    _print_observable_line(ra.observable)
    _print_vintage(ra.vintage, ra.stale_env, ra.inadmissible_because)
    _print_boundary(ra)
    _print_failures(ra)
    nothing
end

function _print_multi_reanalysis(m::MultiReanalysis)
    println("reanalyze: $(length(m.order)) observables off one read")
    for n in m.order
        ra = m.results[n]
        println("  * $n")
        _print_observable_line(ra.observable)
        _print_boundary(ra)
    end
    _print_vintage(m.vintage, m.stale_env, m.inadmissible_because)
    # The failure list is the same for every observable only when the read
    # failed; per-observable windows fail per-observable, so print each.
    for n in m.order
        ra = m.results[n]
        isempty(ra.failures) && continue
        println("  [$n]")
        _print_failures(ra)
    end
    nothing
end

"""
    reanalysis_record(ra) -> Dict{String,Any}
    reanalysis_record(m::MultiReanalysis) -> Dict{String,Any}

The machine-readable record of a re-analysis: the observable's three fields, the
vintage, the declaration, and `admissible = false` with its reasons.

Written as JSON beside a re-analysis output, or transcribed into a `[[claim]]`
row — `window` / `reduction` / `boundary` come out under the ledger's own names,
and `evidence_status` / `uncertainty_basis` are filled with what a re-read can
honestly claim rather than left for the transcriber to guess.

The `MultiReanalysis` form writes the shared vintage once and each observable's
own three fields under `observables`, so a group of numbers taken off one read
cannot be transcribed with the vintage of a different pass.
"""
function reanalysis_record(ra::Reanalysis)
    rec = _reanalysis_shared_record(ra.vintage, ra.sources, ra.paths, ra.declared,
        ra.stale_env, ra.admissible, ra.inadmissible_because)
    merge!(rec, _observable_record(ra))
    rec
end

function reanalysis_record(m::MultiReanalysis)
    rec = _reanalysis_shared_record(m.vintage, m.sources, m.paths, m.declared,
        m.stale_env, m.admissible, m.inadmissible_because)
    rec["observables"] = Dict{String, Any}(
        n => _observable_record(m.results[n]) for n in m.order)
    rec["observable_order"] = copy(m.order)
    rec
end

function _observable_record(ra::Reanalysis)
    obs = ra.observable
    Dict{String, Any}(
        "observable" => obs.name,
        "window" =>
            string(obs.window) *
            (obs.window_frames === nothing ? "" : " $(obs.window_frames)"),
        "reduction" => string(obs.reduction),
        "boundary" => obs.boundary,
        "series" => obs.series_key === nothing ? "" : obs.series_key,
        "boundary_hits" => ra.boundary_hits,
        "values" => Dict{String, Any}(k => v for (k, v) in ra.values),
        # A target that produced no number, with WHY. Absent must not read as
        # benign, and "the window did not fit" must not read like "no data".
        "failures" => Dict{String, Any}(k => v for (k, v) in ra.failures),
    )
end

function _reanalysis_shared_record(vintage::RunVintage, sources, paths, declared,
    stale_env, admissible, why)
    Dict{String, Any}(
        # Which file each ROW came off, so a value lifted out of the table keeps
        # its provenance. `sources` below is the read order and answers a
        # different question.
        "sources_by_label" => Dict{String, Any}(
            k => joinpath(basename(dirname(v)), basename(v)) for (k, v) in paths),
        "declared" => declared,
        "allow_stale_points_ambient" => stale_env,
        "vintage_commits" => vintage.commits,
        "vintage_counts" => vintage.counts,
        "n_points" => vintage.n_points,
        "n_dirty" => vintage.n_dirty,
        "n_unstamped" => vintage.n_unstamped,
        # Arm directory AND point file. `basename` alone printed
        # "point_001.jld2" five times, which is a list of nothing: across a scan
        # the arm is the coordinate and the point name is a constant.
        "sources" => [joinpath(basename(dirname(p)), basename(p)) for p in sources],
        "admissible" => admissible,
        "inadmissible_because" => why,
        # What a transcriber would otherwise have to decide. `absent` because the
        # stored points are not in the tree, and `none` because a re-read has no
        # convergence axis of its own — the axis belongs to the run it read.
        "evidence_status" => "absent",
        "uncertainty_basis" => "none",
        "uncertainty" =>
            "unbounded: a re-read of stored output at vintage " *
            (isempty(vintage.commits) ? "<unstamped>" : join(vintage.commits, "/")) *
            "; the uncertainty is the run's, not this reduction's",
    )
end
