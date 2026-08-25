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

@testset "type-C coverage: what arbitrates, and what nothing arbitrates" begin
    # THE ARBITRATION LAYER IS `refs/<source>.toml`, and it is the only thing in
    # this tree that can decide a comparison: `src/model/ref.jl` re-measures the
    # published target off a committed fixture with the metric we apply to our own
    # runs, and DERIVES `arbitrates` rather than letting anyone assert it. A .bib
    # entry or a PDF under `docs/refs/` cannot do that.
    #
    # This arm reports the coverage rather than demanding it. A ratchet on a
    # registry with two entries would be a gate on how much reading has been done,
    # which is not a defect a test can fix — but an UNNAMED hole is, and the
    # numbers below are printed so the hole cannot be invisible.
    claims = claim_ledger()
    refsdir = joinpath(_REPO, "refs")
    registered = sort([splitext(f)[1] for f in readdir(refsdir) if endswith(f, ".toml")])
    @test !isempty(registered)
    println("  arbitration layer (refs/*.toml): ", join(registered, ", "))

    tc = [c for c in claims if c.type == "C"]
    @test !isempty(tc)
    anchored = [c for c in tc if !isempty(c.anchors)]
    println("  type-C claims: ", length(tc), ", anchored: ", length(anchored))
    for c in tc
        isempty(c.anchors) && println("    NO ANCHOR  ", c.id, "  [", c.status, "]")
    end

    # Every anchor that IS declared must resolve. The parser enforces this; the
    # assertion here makes the count visible in the report.
    for c in claims, a in c.anchors
        @test isfile(joinpath(refsdir, String(claim_anchor_source(a)) * ".toml"))
    end

    mktempdir() do d
        row(extra; ty="C", es="in_tree") = """
        schema_version = 1
        [[claim]]
        id = "x"
        claim = "c"
        status = "live"
        type = "$ty"
        scope = "s"
        uncertainty = "unbounded: probe"
        uncertainty_basis = "none"
        evidence = []
        evidence_status = "$es"
        commit = "unknown"
        doc = "CLAUDE.md"
        section = "1"
        pr = 1
        $extra
        """
        w(n, e; kw...) = (p=joinpath(d, n * ".toml"); write(p, row(e; kw...)); p)

        # An anchor naming a source with no refs/ file is refused — leaning on an
        # unregistered paper is the shape that cannot arbitrate anything.
        @test_throws ArgumentError claim_ledger(
            path=w("ghost", "anchors = [\"nosuchpaper2099\"]"))
        # A registered one passes, and the quantity suffix is accepted.
        @test length(
            claim_ledger(path=w("ok",
                "anchors = [\"matsui2025:dip_width_exp_scanwindow_nT\"]")),
        ) == 1
        # type-C may not be `registered` with nothing arbitrating it…
        @test_throws ArgumentError claim_ledger(
            path=w("tc_unanchored",
                "lifecycle = \"registered\"\nladder = \"exact: probe\""),
        )
        # …and type-B at the same lifecycle is untouched, or the rule has become a
        # tax on every claim rather than on the one kind that is a comparison.
        @test length(
            claim_ledger(
                path=w("tb_ok",
                    "lifecycle = \"registered\"\nladder = \"exact: probe\""; ty="B"),
            ),
        ) == 1
    end
end

@testset "the lifecycle gates at the moment a claim becomes words, not before" begin
    # THE FIRST STATE IS UNGATED AND THAT IS THE DESIGN. Every other rule in this
    # file binds a row already in the ledger; none reaches the stage where a
    # number is being found, and none should. The measured lesson is that a gate
    # which reddens during correct work gets disabled, and a disabled gate
    # protects nothing — so the ladder binds at `registered`, the first state
    # whose contents may be spoken in prose, a talk, or to the lab.
    claims = claim_ledger()
    @test all(c -> c.lifecycle in CLAIM_LIFECYCLE_STATES, claims)

    byl = Dict{String, Int}()
    for c in claims
        byl[c.lifecycle] = get(byl, c.lifecycle, 0) + 1
    end
    println("  lifecycle: ", sort(collect(byl), by=x -> -x[2]))

    # Non-vacuity: promotion must have happened somewhere, or the gate below is a
    # green over an empty set.
    reg = [c for c in claims if c.lifecycle in ("registered", "published")]
    @test !isempty(reg)
    @test all(c -> c.ladder !== nothing, reg)
    @test all(c -> c.evidence_status == "in_tree", reg)

    # And most rows must NOT be registered, or the state has been handed out
    # rather than earned. This is a ratchet on honesty, not on progress.
    @test length(reg) < length(claims)

    # A ladder says which axes were walked, or says there is nothing to walk.
    walked(l) = occursin(CLAIM_LADDER_EXACT_ESCAPE, l) || count(isdigit, l) >= 2
    @test !walked("we checked it carefully")
    @test walked("grid 32^3 / 48^3 / 64^3, monotone")
    @test walked("exact: an algebraic identity")
    bare = [c for c in reg if !walked(c.ladder)]
    isempty(bare) || println("  registered with a ladder that names no axis:\n    ",
        join([c.id for c in bare], "\n    "))
    @test bare == LedgerClaim[]

    mktempdir() do d
        row(extra; es="absent") = """
        schema_version = 1
        [[claim]]
        id = "x"
        claim = "c"
        status = "live"
        type = "B"
        scope = "s"
        uncertainty = "unbounded: probe"
        uncertainty_basis = "none"
        evidence = []
        evidence_status = "$es"
        commit = "unknown"
        doc = "CLAUDE.md"
        section = "1"
        pr = 1
        $extra
        """
        w(n, e; es="absent") =
            (p=joinpath(d, n * ".toml"); write(p, row(e; es=es)); p)

        # THE LOOSE SIDE, and it is the arm that matters most. An exploratory row
        # with absent evidence, no basis, no ladder MUST parse. If this ever goes
        # red the gate has crept into the exploration it was built to leave alone.
        @test length(claim_ledger(path=w("explore", "lifecycle = \"exploratory\""))) == 1
        # Default is `candidate`, since a row is in the file at all.
        @test only(claim_ledger(path=w("default", ""))).lifecycle == "candidate"

        # The strict side must be reachable.
        @test_throws ArgumentError claim_ledger(path=w("bad", "lifecycle = \"draft\""))
        @test_throws ArgumentError claim_ledger(
            path=w("reg_no_ladder", "lifecycle = \"registered\""))
        @test_throws ArgumentError claim_ledger(
            path=w("reg_absent",
                "lifecycle = \"registered\"\nladder = \"grid 24/48/64\""),
        )
        @test_throws ArgumentError claim_ledger(
            path=w("pub_no_blind",
                "lifecycle = \"published\"\nladder = \"exact: identity\"";
                es="in_tree"),
        )
        # ...and the same row WITH a blinding record must pass, or the rule has
        # quietly become "published is unreachable".
        @test length(
            claim_ledger(
                path=w("pub_ok",
                    "lifecycle = \"published\"\nladder = \"exact: identity\"\n" *
                    "blinding = \"frozen on synthetic 2026-08-20, unblinded 2026-08-25\"";
                    es="in_tree"),
            ),
        ) == 1

        # ONE discriminator is the type-3 failure in miniature: a single test that
        # agrees with the story is what the story predicts. Two is the shape that
        # killed the Coriolis reading (parity + substitution).
        @test_throws ArgumentError claim_ledger(
            path=w("one_disc", "discriminators = [\"parity in Omega\"]"))
        @test length(
            claim_ledger(
                path=w("two_disc",
                    "discriminators = [\"parity in Omega\", \"static-trap substitution\"]"),
            ),
        ) == 1
    end
end

@testset "a retraction names the axis it moved, and both values" begin
    # THE HOLE THE TWO ARMS AT THE BOTTOM OF THIS FILE LEAVE. They bind whether
    # the killing row rests on ANYTHING — `in_tree` evidence and a real basis for
    # a live successor, `note` + `pr` for a bare retirement. Neither can see the
    # COMPARISON, and the comparison is where the eight bad retractions went
    # wrong: #442 reversed at 0.05 sigma because one seed was compared against
    # one seed, #436 replaced a window-dependent number with a different
    # window-dependent number, #411 measured with `noise=false` and generalised.
    #
    # "The same convergence ladder" was the first draft of the rule and it is
    # wrong. A refutation usually differs DELIBERATELY on one axis — 32³ → 64³,
    # 8 ms → 16 ms, 1 seed → 3 — and requiring sameness would forbid the move
    # that does the work. What is wanted is that the axis is NAMED and both sides
    # are stated, so a reader can tell a refinement from a different experiment.
    #
    # The parser enforces presence fail-closed. This arm enforces that the text
    # says something checkable, and that the `premise_dissolved:` escape is
    # actually reachable rather than a phrase nobody uses.
    claims = claim_ledger()
    retired = [c for c in claims if c.status in ("superseded", "refuted")]
    @test !isempty(retired)
    @test all(c -> c.retraction_evidence !== nothing, retired)

    # Either it names a comparison (which needs numbers) or it says the premise
    # dissolved. A row that does neither is prose, which is the whole defect.
    states_a_comparison(ev) =
        occursin(CLAIM_RETRACTION_PREMISE_ESCAPE, ev) || occursin(r"\d", ev)

    # Controls on the predicate BEFORE it is pointed at the ledger, both ways.
    @test !states_a_comparison("later work disagreed with this")
    @test states_a_comparison("grid, 32^3 -> 64^3: the ordering inverts")
    @test states_a_comparison("premise_dissolved: there is no branch to explain")

    bare = [c for c in retired if !states_a_comparison(c.retraction_evidence)]
    isempty(bare) || println(
        "  retractions that name no axis and no value:\n    ",
        join([c.id for c in bare], "\n    "),
        "\n  → say which axis the killing measurement moved and give both sides, ",
        "or `", CLAIM_RETRACTION_PREMISE_ESCAPE, " <why>` if there was nothing ",
        "to compare.")
    @test bare == LedgerClaim[]

    # Non-vacuity in both directions: the escape must be used somewhere, or it is
    # an untested branch of the rule; and most rows must NOT use it, or the rule
    # has been satisfied by declaring every retraction unmeasurable.
    escaped = count(c -> occursin(CLAIM_RETRACTION_PREMISE_ESCAPE,
            c.retraction_evidence), retired)
    @test escaped >= 1
    @test escaped < length(retired) ÷ 2

    # RED MUST BE REACHABLE. The ledger is green above, so without this the arm
    # is satisfied by a parser that never rejects anything.
    mktempdir() do d
        row(extra) = """
        schema_version = 1
        [[claim]]
        id = "x"
        claim = "c"
        status = "refuted"
        type = "A"
        scope = "s"
        uncertainty = "unbounded: probe"
        uncertainty_basis = "none"
        evidence = []
        evidence_status = "absent"
        commit = "unknown"
        doc = "CLAUDE.md"
        section = "1"
        pr = 1
        note = "probe"
        retired_literal = "1.234"
        $extra
        """
        missing_ev = joinpath(d, "missing.toml")
        with_ev = joinpath(d, "with.toml")
        write(missing_ev, row(""))
        write(with_ev, row("retraction_evidence = \"grid, 32^3 -> 64^3\""))
        @test_throws ArgumentError claim_ledger(path=missing_ev)
        @test length(claim_ledger(path=with_ev)) == 1
    end
end

@testset "a reduction carries the window it was reduced over" begin
    # At B = 10.4 nT three readings of the same CACHED arms put the argmax at
    # three different points, and 16 of 20 had theirs on the hold's first frame —
    # the decaying pre-hold transient, ranked as if it were the cascade. The runs
    # were fine. The window and the reduction were chosen after the campaign.
    #
    # The parser binds this fail-closed for any `quantity` naming a reduction.
    # Here: that the detector is not vacuous, that `accept` and `unchecked` are
    # both really used (they are the values that would be quietly replaced by
    # `reject` if nobody could tell the difference), and that red is reachable.
    claims = claim_ledger()
    reducers = [
        c for c in claims
        if c.quantity !== nothing && any(
            occursin(w, lowercase(c.quantity)) for w in CLAIM_REDUCTION_NAMES)
    ]
    @test !isempty(reducers)
    @test all(c -> c.window !== nothing && c.reduction !== nothing, reducers)
    @test all(c -> c.boundary in CLAIM_BOUNDARY_RULES, reducers)

    # The detector must be a filter and not a pass-through: rows exist whose
    # quantity is NOT a reduction, and they are correctly unbound. Otherwise
    # "every reducer carries a window" is just "every row does".
    quantified = [c for c in claims if c.quantity !== nothing]
    @test length(reducers) < length(quantified)

    # `accept` is the value that records the defect rather than the fix, and a
    # ledger where nobody ever wrote it would mean the field is being used to
    # describe intentions instead of measurements.
    @test any(c -> c.boundary == "accept", reducers)

    mktempdir() do d
        row(extra) = """
        schema_version = 1
        [[claim]]
        id = "x"
        claim = "c"
        status = "live"
        type = "B"
        scope = "s"
        uncertainty = "unbounded: probe"
        uncertainty_basis = "none"
        evidence = []
        evidence_status = "absent"
        commit = "unknown"
        doc = "CLAUDE.md"
        section = "1"
        pr = 1
        quantity = "peak P_adj @ probe"
        $extra
        """
        bare = joinpath(d, "bare.toml")
        badbnd = joinpath(d, "badbnd.toml")
        good = joinpath(d, "good.toml")
        write(bare, row(""))
        write(badbnd,
            row("window = \"hold\"\nreduction = \"max\"\nboundary = \"whatever\""))
        write(good,
            row("window = \"hold\"\nreduction = \"max\"\nboundary = \"reject\""))
        @test_throws ArgumentError claim_ledger(path=bare)
        @test_throws ArgumentError claim_ledger(path=badbnd)
        @test length(claim_ledger(path=good)) == 1

        # And a non-reduction quantity must NOT be dragged in — the rule has to
        # stay a filter or it becomes the too-strict kind that gets deleted.
        notared = joinpath(d, "notared.toml")
        write(notared,
            replace(
                row(""),
                "quantity = \"peak P_adj @ probe\"" => "quantity = \"eta_start on the shipped defaults\"",
            ))
        @test length(claim_ledger(path=notared)) == 1
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
    # The rule itself lives in `claim_ledger.jl` and is called, not retyped —
    # a second copy here would be the ledger's own defect one layer down.
    grounded = retraction_is_grounded

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
    self_grounded = retraction_is_self_grounded

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
