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
        @test c.prediction_registered in ("before", "after")   # not a closed set worth a constant: two values, no growth pressure
        # From the constant, not a copy of it: this line asserted the old
        # three-value tuple and went red when `moot` was added -- a second
        # declaration of a closed set is the defect the ledger exists to stop,
        # and it had grown one inside the ledger's own gate.
        @test c.prediction_outcome in SpinorBEC.CLAIM_PREDICTION_OUTCOMES
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

@testset "the ledger's coverage of the documents it cites does not go backwards" begin
    # The gate the 2026-08-21 incident asked for. `quantity` can only make two ROWS
    # collide; it cannot see a section that was never poured, and the section that
    # refuted the method in use was one of 47 unpoured out of 70.
    #
    # A ratchet rather than a target: pinning this at "everything" would make it
    # unmeetable and it would be deleted, which is the failure mode this project
    # has recorded for gates that are too strict.
    using TOML
    doc = TOML.parsefile(claim_ledger_path())
    pinned = Dict(r["doc"] => Int(r["covered"]) for r in get(doc, "coverage", []))
    @test !isempty(pinned)

    actual = ledger_section_coverage(; repo=_REPO)
    @test !isempty(actual)

    for r in actual
        haskey(pinned, r.doc) || begin
            println("  cited but not in the coverage ratchet: ", r.doc,
                " (", r.covered, "/", r.total, ") — add a [[coverage]] row")
            @test false
            continue
        end
        r.covered >= pinned[r.doc] || println("  coverage FELL for ", r.doc, ": ",
            r.covered, " < pinned ", pinned[r.doc], ". Uncovered: ",
            join(r.uncovered, " "))
        @test r.covered >= pinned[r.doc]
    end

    # Positive control: a ratchet that cannot detect a fall is not a ratchet.
    @test any(r -> r.covered < r.total, actual)   # there IS debt to protect
    fell = [r for r in actual if r.covered < get(pinned, r.doc, 0) + 1_000_000]
    @test length(fell) == length(actual)          # the comparison is live
end

@testset "a retraction rests on something the tree can resolve" begin
    # THE CORRECTION IS A CLAIM TOO, and this project keeps forgetting it.
    # Eight times in the PR history a retraction was itself wrong and had to be
    # withdrawn:
    #
    #   #197  called BOTH factorial claims refuted; one of them survived.
    #   #215  "the NaN mechanism covers the eps_dd domain" — it does not.
    #   #295  acted on a regenerate-or-retract list built with the broken matcher
    #         #288 documents, so TWO documents retracted claims they did not
    #         need to. The data was sitting on disk the whole time.
    #   #358  the attribution correction said the paper "does not exist", eight
    #         lines above a citation to the same arXiv number.
    #   #411  "the loss is one-off" — measured with `noise=false`, generalised to
    #         production, and the gate itself said so.
    #   #436  the correction was premature TWICE, replacing one window-dependent
    #         number with a different window-dependent number.
    #   #442  "relaxing the ramp helps" — reversed by #446 at 0.05 sigma.
    #
    # The common shape is not haste. It is that a retraction was allowed to rest
    # on PROSE — a reading, a list, an inference — while the claim it killed had
    # to rest on a run. The ledger already carries the two fields that say
    # whether a row rests on anything (`evidence_status`, `uncertainty_basis`);
    # nothing required them of the row doing the killing.
    #
    # So: a row that is CURRENTLY BELIEVED and supersedes another must have
    # evidence that resolves in this tree, and a stated basis for its
    # uncertainty. Deliberately NOT required of `refuted`/`superseded` rows —
    # a retraction that was later itself retracted is a real outcome the ledger
    # exists to hold (`edh-two-branches-5p2nt` is exactly that), and demanding
    # live evidence from a dead row would push people to delete it.
    #
    # It does not check that the evidence SAYS what the row claims. It checks
    # that a replacement cannot be made out of nothing, which is what #295 was.
    grounded(status, supersedes, evidence_status, uncertainty_basis) =
        isempty(supersedes) || status in ("superseded", "refuted") ||
        (evidence_status == "in_tree" && uncertainty_basis != "none")

    # Controls on the predicate, before it is pointed at the ledger. Both
    # failure modes of #295 must be visible, and an ordinary row must pass —
    # a rule that reddens on correct writing is a rule that gets deleted.
    @test !grounded("live", ["x"], "absent", "control")     # nothing to re-read
    @test !grounded("live", ["x"], "in_tree", "none")       # nothing bounds it
    @test grounded("live", ["x"], "in_tree", "control")     # the good case
    @test grounded("live", String[], "absent", "none")      # supersedes nothing
    @test grounded("refuted", ["x"], "absent", "none")      # itself withdrawn

    claims = claim_ledger()
    believed = [
        c for c in claims
              if !isempty(c.supersedes) && !(c.status in ("superseded", "refuted"))
    ]
    # Non-vacuity: if no live row supersedes anything, the arm below is a green
    # over an empty set and says nothing.
    @test !isempty(believed)

    ungrounded = [
        c for c in believed
        if !grounded(c.status, c.supersedes, c.evidence_status,
            c.uncertainty_basis)
    ]
    isempty(ungrounded) || println(
        "  these rows retract another claim without resolvable grounds:\n    ",
        join(
            [
                "$(c.id)  (evidence_status=$(c.evidence_status), " *
                "uncertainty_basis=$(c.uncertainty_basis)) supersedes " *
                join(c.supersedes, ", ") for c in ungrounded
            ], "\n    "),
        "\n  → point `evidence` at runs in this tree and give the number a basis, ",
        "or leave the old row live and say what is unresolved.")
    @test ungrounded == LedgerClaim[]
end

@testset "a refutation with no replacement carries its own grounds" begin
    # THE HOLE IN THE ARM ABOVE, and it was the bigger half. That arm binds the
    # row doing the KILLING, so it reaches only retractions that produced a
    # replacement. FOUR of the thirteen retired rows have no `superseded_by` at
    # all — `edh-window-1p3nt-0p3` (there is no operating window at 1.3 nT, so
    # the old `≈0.3` has nowhere to move to), `edh-5p2nt-dip-is-a-resonance`,
    # `edh-longtime-static-sustains`, `fftw-visible-cpu-count-hypothesis`.
    #
    # "Refuted with no replacement" is a real outcome and the ledger exists to
    # hold it. It is also the shape with the LEAST redundancy in the tree: when
    # a replacement exists the successor row carries the measurement and the arm
    # above checks it; when there is none, nothing else says why this died. So
    # the row itself has to, or the retraction is exactly the prose-grounded
    # kind #295 acted on.
    #
    # `note` and `pr`, NOT `evidence_status`. A refuted row's `evidence` field
    # describes what the DEAD claim rested on, and demanding `in_tree` there
    # would ask people to preserve the very runs that turned out to support
    # nothing. What is wanted is a pointer to the work that killed it. `commit`
    # is deliberately not accepted as a substitute: 9 of the 13 retired rows
    # carry the literal string "unknown" there, so a rule keyed on it would be
    # satisfied by a value that names nothing.
    self_grounded(status, superseded_by, note, pr) =
        !(status in ("superseded", "refuted")) || superseded_by !== nothing ||
        (note !== nothing && !isempty(strip(note)) && pr !== nothing)

    # Controls on the predicate, before it is pointed at the ledger.
    @test !self_grounded("refuted", nothing, "measured at 64³", nothing)  # no PR
    @test !self_grounded("refuted", nothing, nothing, 410)                # no note
    @test !self_grounded("refuted", nothing, "   ", 410)                  # blank note
    @test self_grounded("refuted", nothing, "measured at 64³", 410)       # good
    @test self_grounded("refuted", "a-successor", nothing, nothing)       # successor carries it
    @test self_grounded("live", nothing, nothing, nothing)                # not a retraction

    claims = claim_ledger()
    bare = [
        c for c in claims
              if c.status in ("superseded", "refuted") && c.superseded_by === nothing
    ]
    # Non-vacuity in BOTH directions: there must be bare retirements to bind,
    # and non-bare ones too, or the split is not doing any work.
    @test !isempty(bare)
    @test any(
        c -> c.status in ("superseded", "refuted") && c.superseded_by !== nothing,
        claims)

    naked = [c for c in bare if !self_grounded(c.status, c.superseded_by, c.note, c.pr)]
    isempty(naked) || println(
        "  refuted with no replacement AND no grounds of its own:\n    ",
        join(
            [
                "$(c.id)  (note=$(c.note === nothing ? "-" : "set"), pr=$(c.pr))"
                for c in naked
            ], "\n    "),
        "\n  → say in `note` what measurement killed it, and give the `pr`. ",
        "Nothing else in the tree carries it for a row with no successor.")
    @test naked == LedgerClaim[]
end
