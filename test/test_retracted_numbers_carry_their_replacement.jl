# A retracted claim may not be stated as if it were live.
#
# WHY THIS EXISTS
#
# `|Omega|/omega_perp = 0.468 +- 0.003` sat in `klaus_protocol_sheet.md` — an
# experimentalist-facing sheet, quoted to three significant figures — for weeks
# after the corpus it came from had been shown to be in the wrong regime, and it
# was re-derived (2026-08-19) to `0.68 +- 0.04` with a different MECHANISM: the
# response is even in Omega, so the chirality rule the sheet built around it is
# void, and a static weakened trap reproduces the whole effect.
#
# The failure mode is not that the retraction was missing. It was written, at the
# top of the file. The failure mode is that the number appears again 200 lines
# later, and a reader who lands there by search or by scrolling to "what Omega
# should I use" never sees it. Documents are read by section, not from the top.
#
# TWO GATES, because the first one turned out not to be enough.
#
#   1. SAME FILE — the replacement must appear somewhere in any file that quotes
#      the retracted value. Cheap, mechanical, and it caught the original case.
#
#   2. POINT OF USE — the retracted value must carry a retraction marker WITHIN
#      A FEW LINES of where it is written. Gate 1 is satisfied by a retraction
#      block at the head of the file, which is exactly the arrangement
#      `klaus_protocol_sheet.md` had while its numbered lab protocol went on
#      instructing the reader to set `|Omega|/omega_perp = 0.468 +- 0.003
#      (default)` 160 lines below the retraction. Gate 1 was green throughout.
#
# THE REGISTRY IS `docs/campaign/claims.toml`, NOT THIS FILE. Both gates derive
# their patterns from the ledger's `retired_literal` / `replacement_literal`
# fields. A hand-maintained list here would be a second declaration of which
# claims are retracted, which is the same defect one layer down: retracting a
# claim in the ledger and forgetting the list would leave the gate enforcing a
# retraction nobody holds any more, or missing one that landed yesterday.
# Retracting a claim is a ledger edit, and it costs one field.

using SpinorBEC
using Test

include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))
include(joinpath(@__DIR__, "helpers", "live_docs.jl"))

const _REPO = normpath(joinpath(@__DIR__, ".."))

# THE CORPUS IS THE LIVE SET **PLUS EVERY DOCUMENT THE LEDGER CITES**.
#
# The live set alone was the first answer and it was too narrow. A document
# carrying a dated FROZEN header is not required to be *true* — that is the deal
# `test_docs_live_set.jl` strikes, and it is what makes 180-odd documents
# affordable. But `docs/manuscript/klaus_protocol_sheet.md` was FROZEN and still
# carried a numbered lab protocol telling a reader which rotation frequency to
# set: its label said "not maintained", its content said "follow me". "Not
# required to be true" is not the same permission as "may issue instructions".
#
# So the second term. A `doc` field in `claims.toml` is a declaration that this
# file STATES a claim, and a file that states a claim must mark the ones that
# died — frozen or not. It is derived from the ledger rather than listed here, so
# adding a row extends the corpus automatically and nobody has to remember.
#
# Note the asymmetry this preserves: a frozen document still need not be
# *correct*. It must only not present a retracted claim as live. Rewriting
# history is not being demanded; issuing orders from it is being stopped.
function _gated_docs()
    from_live = [joinpath(_REPO, d) for d in LIVE_DOCS if endswith(d, ".md")]
    from_ledger = [joinpath(_REPO, c.doc) for c in claim_ledger() if endswith(c.doc, ".md")]
    sort(unique(filter(isfile, vcat(from_live, from_ledger))))
end

@testset "the claim ledger parses and its supersession graph is sound" begin
    claims = claim_ledger()
    @test !isempty(claims)

    errs = claim_ledger_link_errors(claims)
    isempty(errs) || println("  ledger link errors:\n    ", join(errs, "\n    "))
    @test errs == String[]

    # Every non-live row declares what must not be said. Enforced in the parser
    # too; asserted here so the ledger's own coverage is visible in the report.
    retired = [c for c in claims if c.status in ("superseded", "refuted")]
    @test !isempty(retired)
    @test all(!isempty(c.retired_literal) for c in retired)

    # A prediction that was written down after the fact is a description. The
    # ledger may record one, but it must say so.
    for c in claims
        c.prediction === nothing && continue
        @test c.prediction_registered in ("before", "after")
        @test c.prediction_outcome in ("hit", "miss", "pending")
    end
end

@testset "evidence declared `in_tree` actually resolves" begin
    # The column earns its keep here. Filling it for the 24 rows turned up a LIVE
    # document citing `klaus_quench_omp0p5_keeprot_mFplus.yaml`, a file `e8dafe8e`
    # renamed to `*_mirror.yaml` when the corpus was retargeted — a reproduction
    # instruction that had stopped resolving and that nothing read.
    #
    # Only path-shaped entries are checked. An arm-set description ("34
    # static-trap arms, §10") is prose by design and is what `absent` is for; a
    # gate that demanded paths there would push people to invent them.
    claims = claim_ledger()
    intree = [c for c in claims if c.evidence_status == "in_tree"]
    @test !isempty(intree)

    ispathlike(e) =
        occursin('/', e) && (
            endswith(e, ".yaml") || endswith(e, ".yml") ||
            endswith(e, ".jl") || endswith(e, ".md") || endswith(e, ".toml")
        )

    dead = String[]
    checked = 0
    for c in intree, e in c.evidence
        ispathlike(e) || continue
        checked += 1
        isfile(joinpath(_REPO, e)) || push!(dead, "$(c.id): $e")
    end
    # Positive control on the scan itself: if nothing path-shaped was examined,
    # "no dead paths" is the same string as "the extractor matched nothing".
    @test checked > 0
    isempty(dead) || println("  `in_tree` evidence that does not resolve:\n    ",
        join(dead, "\n    "))
    @test dead == String[]
end

@testset "a retracted claim never appears without its replacement in the same file" begin
    docs = _gated_docs()
    @test !isempty(docs)
    claims = claim_ledger()

    # Only rows that HAVE a replacement can be checked this way. A claim refuted
    # with no replacement (1.3 nT has no operating window) is handled by the
    # point-of-use gate below and must not be silently dropped here — so assert
    # that the split is non-degenerate in both directions.
    withrep = [c for c in claims if !isempty(c.retired_literal) &&
                                    !isempty(c.replacement_literal)]
    norep = [c for c in claims if !isempty(c.retired_literal) &&
                                  isempty(c.replacement_literal)]
    @test !isempty(withrep)
    @test !isempty(norep)

    mktempdir() do d
        for c in withrep, lit in c.retired_literal
            bad = joinpath(d, "carries_retracted_only.md")
            good = joinpath(d, "carries_both.md")
            write(bad, "the value is $lit\n")
            write(good, "$lit was superseded by $(first(c.replacement_literal))\n")

            offend(f) =
                let body = read(isabspath(f) ? f : joinpath(_REPO, f), String)
                    occursin(lit, body) &&
                        !any(occursin(rep, body) for rep in c.replacement_literal)
                end

            offenders = calibrated_scan(
                docs; match=offend, present=bad, absent=good,
                describe=f -> isabspath(f) ? basename(f) : f,
            )
            isempty(offenders) || println(
                "  quotes retracted `", lit, "` (claim `", c.id,
                "`) with no replacement in the same file:\n    ",
                join(offenders, "\n    "))
            @test offenders == String[]
        end
    end
end

@testset "a retracted claim is marked WHERE IT IS USED, not only at the top" begin
    sites = unmarked_retired_literal_sites(; files=_gated_docs())

    if !isempty(sites)
        println("  retracted claims stated with no retraction marker nearby:")
        for s in sites
            println("    ", s.file, ":", s.line, "  [", s.claim_id, "] ",
                first(s.text, 100))
        end
        println("  → mark the line itself. One of ",
            join(SpinorBEC.CLAIM_RETRACTION_MARKERS, ", "),
            " within 6 lines. The retraction at the head of the file does not ",
            "reach a reader who lands on the table.")
    end
    @test sites == NamedTuple[]
end

@testset "a neighbouring table row's marker does not shield an unmarked one" begin
    # Measured 2026-08-20, in the very document this gate exists for. The §0
    # verdict table's row 17 stated the REFUTED `2.25×` bare, and one line below
    # it row 13 said "**refuted**" about an unrelated claim. Proximity was
    # satisfied, so the gate was green over a live table asserting a refuted
    # result in the present tense — the exact failure it was built to catch,
    # surviving inside it.
    #
    # The rule that fixes it: in a markdown table the window is the line, because
    # a row is one claim and its neighbours are always other claims. Prose keeps
    # the loose window; a gate that reddens on correct writing gets deleted.
    claims = claim_ledger()
    c = claim_by_id(claims, "edh-longtime-static-sustains")
    @test c !== nothing
    lit = first(c.retired_literal)

    mktempdir() do d
        shielded = joinpath(d, "shielded.md")
        marked = joinpath(d, "marked.md")
        write(shielded,
            "| 17 | long time | the endpoint differs by $lit at 145 ms. |\n" *
            "| 13 | 5.2 nT | the old window is **refuted**, not merely unresolved. |\n")
        write(marked,
            "| 17 | long time | $lit is **RETRACTED**; see the 64³ re-run. |\n" *
            "| 13 | 5.2 nT | the old window is **refuted**, not merely unresolved. |\n")

        # Red must be reachable, and green must be too — a rule that reddens on
        # a correctly-marked row is worse than the hole it closes. `marked` also
        # pins the casing fold: it says RETRACTED, and the marker list carries
        # `retracted` in lower case only.
        @test length(unmarked_retired_literal_sites(files=[shielded])) == 1
        @test unmarked_retired_literal_sites(files=[marked]) == NamedTuple[]

        # And prose must keep the loose window, or the fix has quietly become a
        # different, stricter gate than the one argued for.
        prose = joinpath(d, "prose.md")
        write(prose, "This result is **RETRACTED**.\n\nThe endpoint ratio was $lit.\n")
        @test unmarked_retired_literal_sites(files=[prose]) == NamedTuple[]
    end
end

@testset "the point-of-use gate can see the defect it was built for" begin
    # Red must be reachable before any green above is worth anything. The probe
    # is the REAL shape: a retracted literal in a protocol step, with the
    # retraction present in the same file but far above it — the arrangement
    # gate 1 passes and gate 2 must not.
    claims = claim_ledger()
    c = claim_by_id(claims, "edh-omega-window-0p468")
    @test c !== nothing
    lit = first(c.retired_literal)

    mktempdir() do d
        docs = joinpath(d, "docs")
        mkpath(docs)
        far = string("> This value is superseded; see the ledger.\n",
            repeat("filler line\n", 40),
            "6. Rotation frequency:  |Ω| / ω_⊥ = ", lit, "  (default)\n")
        write(joinpath(docs, "point_of_use.md"), far)
        write(joinpath(docs, "marked_at_use.md"),
            "| window | $lit | **SUPERSEDED** → 0.68 ± 0.04 |\n")

        found = unmarked_retired_literal_sites(; claims, docs_root=docs)
        # Positive control: the far-retraction file MUST be flagged.
        @test any(s -> endswith(s.file, "point_of_use.md"), found)
        # Negative control: a line carrying its own marker must NOT be.
        @test !any(s -> endswith(s.file, "marked_at_use.md"), found)
    end
end
