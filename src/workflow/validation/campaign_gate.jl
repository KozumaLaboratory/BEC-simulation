# --- Campaign ancestor gate (docs/campaign/CAMPAIGN.md §4 guard 1) ---
#
# `docs/campaign/fix_list.toml` declares the corrections a run must descend from
# to be quotable as campaign evidence. The charter has always described the check
# as "mechanical, not a judgement call" — but until 2026-08-19 nothing executed
# it: the only file in the tree that read `fix_list.toml` was
# `test/test_docs_live_set.jl`, which asserts the file EXISTS. A gate nobody runs
# disqualifies nothing, which is how a fix cited by
# `docs/manuscript/klaus_protocol_sheet.md` as the reason its numbers are stale
# was never added to the list (issue #343).
#
# Three-valued on purpose. `:pass` / `:disqualified` / `:unknown_provenance` are
# different facts, and the third is the common one here: the vintage audit found
# 230 stored summaries with zero producing commits. Folding "cannot tell" into
# either of the other two is the failure this whole campaign exists to stop, so
# the report keeps the three counts separate and the summary line prints all
# three.

using TOML

export CampaignFix, campaign_fix_list, campaign_fix_list_path,
    run_producing_commit, campaign_gate_verdict, campaign_gate_report

"""
    CampaignFix

One row of `docs/campaign/fix_list.toml`. `ref` is the only field the gate reads;
the rest exist so a failing verdict can say what the run is missing.
"""
struct CampaignFix
    id::String
    ref::String
    merged::String
    summary::String
    effect::String
end

"""
    campaign_fix_list_path(; repo=nothing) -> String

Path to `docs/campaign/fix_list.toml`. `repo` defaults to the package root.
"""
function campaign_fix_list_path(; repo::Union{Nothing, AbstractString}=nothing)
    root = repo === nothing ? normpath(joinpath(@__DIR__, "..", "..", "..")) : repo
    joinpath(root, "docs", "campaign", "fix_list.toml")
end

"""
    campaign_fix_list(; path=campaign_fix_list_path()) -> Vector{CampaignFix}

Parse the fix list. Throws when a row is missing `id` or `ref` — a row that
cannot be checked must not be silently skipped, since skipping is exactly what
lets a run pass a gate it never met.
"""
function campaign_fix_list(; path::AbstractString=campaign_fix_list_path())
    isfile(path) || throw(ArgumentError("campaign fix list not found: $path"))
    doc = TOML.parsefile(path)
    rows = get(doc, "fix", nothing)
    rows isa AbstractVector ||
        throw(ArgumentError("$path has no [[fix]] array"))
    out = CampaignFix[]
    for (i, r) in enumerate(rows)
        id = get(r, "id", nothing)
        ref = get(r, "ref", nothing)
        (id isa AbstractString && ref isa AbstractString) || throw(
            ArgumentError(
                "$path [[fix]] #$i is missing `id` or `ref`; a row the gate cannot " *
                "check must not exist"),
        )
        push!(
            out,
            CampaignFix(id, ref, string(get(r, "merged", "")),
                string(get(r, "summary", "")), string(get(r, "effect", ""))),
        )
    end
    isempty(out) && throw(ArgumentError("$path declares no fixes"))
    out
end

"""
    _rev_exists(rev; repo) -> Bool
    _is_ancestor(anc, desc; repo) -> Bool

Thin `git` wrappers. `_is_ancestor` is false both when `anc` is genuinely not an
ancestor and when either rev is unknown to this clone — the caller separates
those with `_rev_exists`, because "the ref is not in this history" is a broken
fix list, not a disqualified run.
"""
function _rev_exists(rev::AbstractString; repo::AbstractString)
    success(
        pipeline(setenv(`git rev-parse --quiet --verify $(rev * "^{commit}")`; dir=repo);
            stdout=devnull, stderr=devnull),
    )
end

function _is_ancestor(anc::AbstractString, desc::AbstractString; repo::AbstractString)
    success(
        pipeline(setenv(`git merge-base --is-ancestor $anc $desc`; dir=repo);
            stdout=devnull, stderr=devnull),
    )
end

"""
    run_producing_commit(run_dir) -> (; commit, dirty, source)

The commit that produced a stored run, from whichever of the two provenance
channels carries it: `run_summary.json`'s `_repo_commit` (`summary_provenance`)
or `env/git_hash` inside a point/result jld2. Returns `commit === nothing` when
neither does — `source = :none`.

The two channels disagree in scope, not in value: the summary stamp is written by
the extractor and only exists post-#139, while `env/git_hash` is written by the
runner on every point. Preferring the jld2 therefore recovers provenance for runs
whose summary predates the stamping fix.
"""
function run_producing_commit(run_dir::AbstractString)
    for f in ("result.jld2", "point_001.jld2")
        p = joinpath(run_dir, f)
        isfile(p) || continue
        got = try
            JLD2.jldopen(p, "r") do d
                haskey(d, "env") || return nothing
                g = d["env"]
                h = get(g, "git_hash", nothing)
                h isa AbstractString && !isempty(h) && h != "unknown" || return nothing
                (String(h), Bool(get(g, "git_dirty", true)))
            end
        catch
            nothing
        end
        got === nothing || return (commit=got[1], dirty=got[2], source=Symbol(f))
    end
    prov = summary_provenance(run_dir)
    prov.stamped && prov.commit !== nothing &&
        return (commit=String(prov.commit), dirty=prov.dirty, source=:run_summary)
    (commit=nothing, dirty=false, source=:none)
end

"""
    campaign_gate_verdict(commit; fixes, repo, dirty=false) -> (; verdict, missing)

Mechanical guard 1. `verdict` is one of

  `:pass`                — descends from every ref, tree was clean
  `:disqualified`        — `missing` names the refs it does not descend from,
                           or the tree was dirty
  `:unknown_provenance`  — `commit === nothing`, or the commit is not in this
                           clone's history

`:unknown_provenance` is never folded into either other value. A run whose
producing commit cannot be resolved has not passed anything.
"""
function campaign_gate_verdict(commit::Union{Nothing, AbstractString};
    fixes::AbstractVector{CampaignFix},
    repo::AbstractString,
    dirty::Bool=false)
    commit === nothing && return (verdict=:unknown_provenance, missing=String[])
    _rev_exists(commit; repo) || return (verdict=:unknown_provenance, missing=String[])
    miss = [f.id for f in fixes if !_is_ancestor(f.ref, commit; repo)]
    (isempty(miss) && !dirty) && return (verdict=:pass, missing=String[])
    (verdict=:disqualified, missing=miss)
end

"""
    campaign_gate_report(; runs_root, repo, fixes, filter=nothing) -> NamedTuple

Sweep every stored run directory under `runs_root` and classify it. A run
directory is any directory holding a `result.jld2` or a `point_001.jld2` —
directories with neither are not runs and are not counted either way.

`filter` is an optional predicate on the directory's basename, used to scope the
sweep (e.g. to the Eu corpus).

Returns `(; total, pass, disqualified, unknown, rows, refs_missing_from_clone)`.
`rows` is one NamedTuple per run: `(dir, commit, dirty, source, verdict, missing)`.

`refs_missing_from_clone` is checked FIRST and reported separately: if a fix-list
ref is not in this clone, every verdict below it is meaningless, and a sweep that
returned all-`:pass` under that condition would be the "monitor that can only
return green" failure this repo has shipped five times.
"""
function campaign_gate_report(;
    runs_root::AbstractString,
    repo::AbstractString,
    fixes::AbstractVector{CampaignFix}=campaign_fix_list(),
    filter::Union{Nothing, Function}=nothing)
    refs_missing = [f.id for f in fixes if !_rev_exists(f.ref; repo)]
    rows = NamedTuple[]
    isdir(runs_root) || return (; total=0, pass=0, disqualified=0, unknown=0,
        rows, refs_missing_from_clone=refs_missing)
    for d in sort(readdir(runs_root; join=true))
        isdir(d) || continue
        (isfile(joinpath(d, "result.jld2")) || isfile(joinpath(d, "point_001.jld2"))) ||
            continue
        filter === nothing || filter(basename(d)) || continue
        p = run_producing_commit(d)
        v = campaign_gate_verdict(p.commit; fixes, repo, dirty=p.dirty)
        push!(
            rows,
            (dir=d, commit=p.commit, dirty=p.dirty, source=p.source,
                verdict=v.verdict, missing=v.missing),
        )
    end
    (; total=length(rows),
        pass=count(r -> r.verdict === :pass, rows),
        disqualified=count(r -> r.verdict === :disqualified, rows),
        unknown=count(r -> r.verdict === :unknown_provenance, rows),
        rows, refs_missing_from_clone=refs_missing)
end
