# The campaign ancestor gate, gated.
#
# `docs/campaign/CAMPAIGN.md` §4 guard 1 has always called itself "mechanical,
# not a judgement call" — and until 2026-08-19 no code ran it. The only file that
# read `fix_list.toml` asserted the file EXISTS. Two consequences, both real:
#
#   * `bce2068f` ("211 Eu configs pinned m=-F under a field that prefers m=+F")
#     was named by `docs/manuscript/klaus_protocol_sheet.md` as the reason its
#     three-significant-figure prescriptions are stale, and was absent from the
#     list the gate reads. The gate could not see the fix the prose leant on
#     (issue #343).
#   * A ref could rot out of the clone (rebase, force-push, an archived branch)
#     and every subsequent verdict would be vacuously green.
#
# This file closes both, and refuses to be a monitor that can only return green:
# the third testset PROVES a red is reachable before any of the green above is
# worth anything.

using SpinorBEC
using Test
using TOML

include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

const _REPO = normpath(joinpath(@__DIR__, ".."))
const _FIXLIST = joinpath(_REPO, "docs", "campaign", "fix_list.toml")
const _CAMPAIGN = joinpath(_REPO, "docs", "campaign", "CAMPAIGN.md")

_git_ok(cmd) = success(pipeline(setenv(cmd, dir=_REPO); stdout=devnull, stderr=devnull))
_have(rev) = _git_ok(`git rev-parse --quiet --verify $(rev * "^{commit}")`)

"""
Is this clone missing the history the gate needs?

`actions/checkout` defaults to `fetch-depth: 1`, and under a shallow clone every
`git merge-base --is-ancestor <2026-06-ref> HEAD` fails for want of the commit —
so the gate reported dead refs and blew up on `rev-parse <ref>^` with exit 128.
That is not a broken fix list, it is a blind instrument, and the two must not
share a message. `.github/workflows/ci.yml` now checks out with `fetch-depth: 0`;
this predicate exists so a regression there says so in one line instead of
surfacing as a raw git error inside an unrelated assertion.
"""
_shallow() =
    strip(read(setenv(`git rev-parse --is-shallow-repository`, dir=_REPO),
        String)) == "true"

@testset "the clone carries the history the gate needs" begin
    if _shallow()
        @warn "SHALLOW CLONE: the campaign ancestor gate cannot look. This is a " *
            "CI configuration regression, not a fix-list problem — restore " *
            "`fetch-depth: 0` on the checkout step that runs the fast tier."
    end
    @test !_shallow()
end

# Commit SHAs quoted in campaign / manuscript prose that are NOT corrections a
# run must descend from. Each needs a reason, written here, at the moment the
# citation is added — that classification is the whole point of the gate. A new
# SHA appearing in those docs fails until someone puts it in one list or the
# other.
const _NOT_A_CORRECTION = Dict(
    "96b7631" =>
        "TDHFB factor-2 / rho-index EOM fix; TDHFB has no YAML pipeline " *
        "integration, so no campaign run can descend from or predate it",
    "a323222" =>
        "introduces `canonical_mult_aware_beta_S` (a definition), cited " *
        "in paper 3 for provenance of the function, not as a correction",
    "ed3be749" =>
        "the docs commit that MEASURED q at both ends of the band; the " *
        "correction it reports is eu-quadratic-zeeman-geometry, already listed",
    "f2352c7f" => "docs cross-reference of duplicated LHY arms; corrects prose, not code",
    # edh_quench_polarisation_decision.md §1.1 — provenance of a MEASUREMENT, and
    # of the runs it measured. None is a correction anything must descend from.
    "b2d746cc" =>
        "the HEAD the #343 ancestor-gate sweep and the positive control " *
        "were run at; states when a number was taken, not what was fixed",
    "15a9f1ee" =>
        "producing commit of 137 stored runs (2026-05-26); named as the " *
        "vintage of the corpus being gated, i.e. an input to the verdict",
    "306ef71a" => "producing commit of 32 stored runs (2026-05-21); same role",
    "e8168dcb" => "producing commit of 9 stored runs (2026-05-23); same role",
)

@testset "campaign fix list — parses, and every ref is real" begin
    @test isfile(_FIXLIST)
    fixes = campaign_fix_list(; path=_FIXLIST)
    @test length(fixes) >= 15
    @test length(unique(f.id for f in fixes)) == length(fixes)
    @test length(unique(f.ref for f in fixes)) == length(fixes)

    dead = [f.id for f in fixes if !_have(f.ref)]
    @test isempty(dead)  # a ref not in this clone makes every verdict vacuous

    not_ancestor = [
        f.id for f in fixes
        if _have(f.ref) && !_git_ok(`git merge-base --is-ancestor $(f.ref) HEAD`)
    ]
    @test isempty(not_ancestor)

    # #343: the field-sign correction must be on the list a machine reads.
    @test "eu-config-field-sign" in [f.id for f in fixes]
end

@testset "CAMPAIGN.md §2 table and fix_list.toml cannot drift" begin
    fixes = campaign_fix_list(; path=_FIXLIST)
    text = read(_CAMPAIGN, String)

    # The prose states both counts; they must be the counts.
    m = match(r"It has (\d+) entries to\s+this table's (\d+)"s, text)
    @test m !== nothing
    @test parse(Int, m.captures[1]) == length(fixes)

    # Data rows of the §2 table: lines starting with `|` between the header
    # separator and the blank line after it.
    sec = split(text, "## 2. The correction fix-list")[2]
    sec = split(sec, "\n---")[1]
    rows = [
        l for l in split(sec, "\n")
        if startswith(strip(l), "|") && !occursin(r"^\|[\s\-:|]+\|$", strip(l))
    ]
    # drop the header row
    data_rows = length(rows) - 1
    @test data_rows == parse(Int, m.captures[2])
end

@testset "the gate can go red — canaries before any green is trusted" begin
    fixes = campaign_fix_list(; path=_FIXLIST)

    # 1. Unresolvable provenance is NOT a pass. This is the common case for the
    #    230 stored summaries with no producing commit, and folding it into
    #    either other verdict is the failure the campaign exists over.
    @test campaign_gate_verdict(nothing; fixes, repo=_REPO).verdict === :unknown_provenance

    # 2. A SHA-shaped string that is not in this history is also not a pass.
    @test campaign_gate_verdict("0123456789abcdef0123456789abcdef01234567";
        fixes, repo=_REPO).verdict === :unknown_provenance

    # 3. A REAL commit that predates a listed fix must be disqualified, and the
    #    verdict must name the fix. The parent of the newest listed ref is such a
    #    commit by construction, so this canary cannot silently stop being one.
    newest = last(sort(fixes; by=f -> f.merged))
    # Guard the read: under a shallow clone this `rev-parse` exits 128 and the
    # canary died with a raw `failed process` inside an assertion about
    # something else. The dedicated shallow testset above is where that is
    # reported; here it just means "cannot construct the canary".
    if _have(newest.ref * "^")
        parent = strip(read(setenv(`git rev-parse $(newest.ref * "^")`, dir=_REPO), String))
        v = campaign_gate_verdict(parent; fixes, repo=_REPO)
        @test v.verdict === :disqualified
        @test newest.id in v.missing
    else
        @warn "canary 3 skipped: $(newest.ref)^ is not in this clone (shallow?)"
        @test _shallow()   # the ONLY admissible reason; otherwise this is red
    end

    # 4. A clean HEAD passes. Only meaningful because 1-3 showed red is reachable.
    @test campaign_gate_verdict("HEAD"; fixes, repo=_REPO).verdict === :pass

    # 5. A dirty tree is disqualified even when the ancestry is perfect.
    @test campaign_gate_verdict("HEAD"; fixes, repo=_REPO, dirty=true).verdict ===
        :disqualified
end

@testset "every commit cited in campaign/manuscript prose is classified" begin
    # The #343 class: a doc names a SHA as the reason its numbers are stale, and
    # nothing checks that the SHA reached the machine-readable list. Rather than
    # pin that one citation, require EVERY cited commit to be either a fix-list
    # ref or an explicitly-reasoned non-correction.
    docs = String[]
    for root in (joinpath(_REPO, "docs", "campaign"), joinpath(_REPO, "docs", "manuscript"))
        isdir(root) || continue
        for (dir, dirs, files) in walkdir(root)
            filter!(d -> !(d in (".git", "node_modules", "worktrees")), dirs)
            for f in files
                endswith(f, ".md") && push!(docs, joinpath(dir, f))
            end
        end
    end
    @test !isempty(docs)

    # (file, token) pairs for every backticked 7-40 hex token that is a real
    # commit here. Non-commits (content_ids, hashes) drop out by construction —
    # `12174e883326ecac` in this corpus is a content_id, not a SHA.
    cited = Tuple{String, String}[]
    for d in docs, mt in eachmatch(r"`([0-9a-f]{7,40})`", read(d, String))
        tok = mt.captures[1]
        _have(tok) && push!(cited, (relpath(d, _REPO), tok))
    end

    fixrefs = Set(f.ref for f in campaign_fix_list(; path=_FIXLIST))
    classified(tok) =
        tok in fixrefs ||
        any(startswith(tok, k) || startswith(k, tok) for k in keys(_NOT_A_CORRECTION))

    # The positive control must be a real commit that is in NEITHER list and
    # never will be. HEAD was the obvious choice and was wrong: this file
    # classified HEAD's sha the moment the decision doc cited it, and the control
    # then failed for the right reason at the wrong time. The root commit cannot
    # be a correction anything must descend from — everything descends from it.
    root = strip(read(setenv(`git rev-list --max-parents=0 HEAD`, dir=_REPO), String))
    root = first(split(root))[1:8]
    @test !classified(root)
    unclassified = calibrated_scan(
        vcat(cited, [("<probe>", root)]);
        match=p -> !classified(p[2]),
        # If the predicate cannot flag the root commit, an empty result means the
        # classifier is broken, not that the docs are clean.
        present=("<probe>", root),
        # bce2068f is cited by klaus_protocol_sheet.md AND is now a fix-list ref.
        # If this matched, the predicate would be flagging classified SHAs too.
        absent=("docs/manuscript/klaus_protocol_sheet.md", "bce2068f"),
        describe=p -> "$(p[2]) in $(p[1])",
    )
    filter!(p -> p[1] != "<probe>", unclassified)

    # The extractor must have actually reached the citation this gate was written for.
    @test ("docs/manuscript/klaus_protocol_sheet.md", "bce2068f") in cited

    if !isempty(unclassified)
        @info "unclassified commit citations" unclassified
    end
    @test isempty(unclassified)
end
