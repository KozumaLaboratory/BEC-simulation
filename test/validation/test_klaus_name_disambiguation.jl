using Test
using SpinorBEC

include(joinpath(@__DIR__, "..", "helpers", "calibrated_scan.jl"))

# One word, three referents, and a retraction that overshot.
#
# "Klaus" named the PAPER (Klaus et al. 2022, arXiv:2206.12265), the numerical
# REGIME (`p·F·dt > π`), and this project's OWN Eu protocol — at once, in the
# same tree. On top of that, a 2026-06-02 "attribution correction" asserted that
# the paper **does not exist**, which is false, and parked that sentence eight
# lines above a citation to the same arXiv number. The live tree meanwhile went
# on citing the paper correctly, so the next session to read the archive would
# have deleted a correct citation as confabulation. Issue #344.
#
# The three referents are now named for what they are
# (`docs/conventions/klaus_name_disambiguation.md`), and this file is what keeps
# that from rotting back:
#
#   1. neither retracted false claim can return unretracted;
#   2. the retired branch labels stay retired in the maintained tree;
#   3. the paper keeps exactly one name;
#   4. every citation of the arXiv number says whose paper it is;
#   5. the regime guide is not named after a paper;
#   6. the disambiguation document actually distinguishes all three.
#
# Every arm goes through `calibrated_scan`, so an arm that has stopped being
# able to see anything fails loudly instead of reporting a clean zero — which is
# exactly the failure mode a "nothing found" naming gate is prone to.

const _REPO = normpath(joinpath(@__DIR__, "..", ".."))

"""
Files whose CONTENT this gate governs.

Deliberately excluded, and the exclusions are the substance of the naming
decision rather than convenience:

  * `runs/**` — `run_yaml` keys its output directory on the RAW BYTES of the
    YAML (`compute_run_dir`). Editing a comment there changes the content id and
    orphans cached `point_*.jld2` that cost GPU-hours. The retired labels stay.
  * `docs/validation/config_prose_harvest.toml` and `config_metadata_blocks.toml`
    — verbatim records of what those configs said, pinned by
    `test_config_prose_harvest.jl`. Rewriting a record to match a later rename
    defeats what the record is for. (Also not reached: neither is `.md`/`.jl`.)
  * `docs/audit/**` — dated dumps quoting the tree as it was.
"""
function _governed_files()
    out = String[]
    for sub in ("src", "test", "docs", "bench")
        root = joinpath(_REPO, sub)
        isdir(root) || continue
        for (dir, dirs, files) in walkdir(root)
            filter!(d -> !(d in (".git", "node_modules", "worktrees")), dirs)
            occursin(joinpath("docs", "audit"), dir) && continue
            for f in files
                any(e -> endswith(f, e), (".md", ".jl", ".py")) || continue
                push!(out, relpath(joinpath(dir, f), _REPO))
            end
        end
    end
    for f in ("CLAUDE.md", "README.md")
        isfile(joinpath(_REPO, f)) && push!(out, f)
    end
    sort!(out)
    out
end

_body(rel) = read(joinpath(_REPO, rel), String)

# A probe carries its OWN text. The first version of this held both probes in
# one `Ref`, so constructing the negative control overwrote the positive one and
# every arm threw `BlindScan` — the instrument catching its own miswiring, which
# is what it is for.
struct Probe
    text::String
end
_text(p::Probe) = p.text
_text(rel::AbstractString) = _body(rel)
_probe(text) = Probe(text)
_describe(x) = x isa Probe ? "synthetic probe: " * repr(x.text) : String(x)

"""
The files allowed to write the RETIRED forms — `Klaus-I` / `Klaus-II`,
`Dy Innsbruck 2022`, `klaus_regime.md` — because saying what moved is their job.

Listed by path, not matched by pattern. An allowlist that grows by regex is how
a gate stops gating; adding an entry here has to be a decision someone made in a
diff. Each entry is asserted below to actually carry a retirement note, so a
file cannot sit on this list while quietly using the old name as current.
"""
const _MAY_NAME_RETIRED = Set([
    joinpath("docs", "conventions", "klaus_name_disambiguation.md"),
    joinpath("docs", "guides", "fast_larmor_regime.md"),
    joinpath("docs", "archive", "klaus_quench_protocol_pivot_2026-05-26.md"),
    joinpath("docs", "manuscript", "klaus_quench_protocol_spec_2026_05_26.md"),
    joinpath("docs", "manuscript", "klaus_protocol_sheet.md"),
    joinpath("test", "validation", "test_klaus_name_disambiguation.jl"),
])

_governed(files) = filter(f -> !(f in _MAY_NAME_RETIRED), files)

@testset "the name \"Klaus\" resolves to exactly one thing per site" begin
    files = _governed_files()

    @testset "the corpus is real" begin
        # Positive control on the corpus itself: an empty or misrooted walk
        # would make every arm below pass vacuously.
        @test length(files) > 300
        @test "CLAUDE.md" in files
        @test joinpath("docs", "conventions", "klaus_name_disambiguation.md") in files
        @test joinpath("test", "validation", "test_type_c_claims.jl") in files
    end

    @testset "1. the retracted denials cannot come back unretracted" begin
        # Both sentences were false. They may be QUOTED — the retraction has to
        # say what it retracts — so the predicate is "asserts it AND does not
        # retract it", which is the distinction the corpus actually needs.
        denial = r"no such paper exists|No author named Klaus"i
        retraction = r"retract"i
        asserts_unretracted(x) = begin
            t = _text(x)
            occursin(denial, t) && !occursin(retraction, t)
        end

        offenders = calibrated_scan(
            files;
            match=asserts_unretracted,
            present=_probe("anko verified that no such paper exists in the literature."),
            absent=_probe("It said \"no such paper exists\". RETRACTED 2026-08-19: it does."),
            describe=_describe,
        )
        isempty(offenders) || println("  asserts the paper does not exist:\n    ",
            join(offenders, "\n    "))
        @test offenders == String[]

        # And the retraction is actually present where the incident happened,
        # so this arm is not green merely because both files were deleted.
        @test occursin(r"retract"i,
            _body(joinpath("docs", "archive", "klaus_quench_protocol_pivot_2026-05-26.md")))
        @test occursin("arXiv:2206.12265",
            _body(joinpath("docs", "archive", "klaus_quench_protocol_pivot_2026-05-26.md")))
    end

    @testset "2. the retired branch labels stay retired" begin
        # `Klaus-I` / `Klaus-II` named the two branches of OUR protocol. They are
        # now `trap-rotation branch` / `field-rotation branch`. The only admitted
        # form is the `(was "Klaus-I")` gloss that tells a reader what moved.
        stale = r"(?<!was \")Klaus-II?\b"
        uses_retired(x) = occursin(stale, _text(x))

        offenders = calibrated_scan(
            _governed(files);
            match=uses_retired,
            present=_probe("The Klaus-II scan was null."),
            absent=_probe("**field-rotation branch** (was \"Klaus-II\") rotates B̂."),
            describe=_describe,
        )
        isempty(offenders) || println("  still uses Klaus-I / Klaus-II:\n    ",
            join(offenders, "\n    "))
        @test offenders == String[]

        # The replacements exist and are in use — otherwise arm 2 is satisfied
        # by having deleted the discussion rather than renamed it.
        spec = _body(joinpath("docs", "manuscript",
            "klaus_quench_protocol_spec_2026_05_26.md"))
        @test occursin("trap-rotation branch", spec)
        @test occursin("field-rotation branch", spec)
    end

    @testset "3. the paper has exactly one name" begin
        # It was cited as "Dy Innsbruck 2022" in three `src/` comments and as
        # "Klaus et al. 2022" in the type-C registry. Same paper, two names.
        second_name(x) = occursin("Dy Innsbruck 2022", _text(x))

        offenders = calibrated_scan(
            _governed(files);
            match=second_name,
            present=_probe("see Dy Innsbruck 2022 [arXiv:2206.12265] for the protocol"),
            absent=_probe("see Klaus et al. 2022 [arXiv:2206.12265] for the protocol"),
            describe=_describe,
        )
        isempty(offenders) || println("  second name for the same paper:\n    ",
            join(offenders, "\n    "))
        @test offenders == String[]
    end

    @testset "4. every citation of the arXiv number names Klaus" begin
        # A bare `arXiv:2206.12265` is unattributed, which is how the tree came
        # to hold a denial and a citation of the same paper without noticing.
        cites = filter(f -> occursin("2206.12265", _body(f)), files)
        @test length(cites) >= 5          # positive control: the scan reaches them
        unattributed = calibrated_scan(
            cites;
            match=x -> !occursin("Klaus", _text(x)),
            present=_probe("caught on the 2206.12265 reproduction"),
            absent=_probe("Klaus et al. 2022 [arXiv:2206.12265]"),
            describe=_describe,
        )
        isempty(unattributed) || println("  cites arXiv:2206.12265 without naming Klaus:\n    ",
            join(unattributed, "\n    "))
        @test unattributed == String[]
    end

    @testset "5. the regime is not named after a paper" begin
        # `p·F·dt > π` is a property of (atom, field, dt). Eu at 1 G is in it and
        # Klaus et al. 2022 is Dy — the paper is an experiment IN the regime.
        @test !isfile(joinpath(_REPO, "docs", "guides", "klaus_regime.md"))
        guide = joinpath("docs", "guides", "fast_larmor_regime.md")
        @test isfile(joinpath(_REPO, guide))
        @test occursin("p · F · dt > π", _body(guide))

        # No dangling pointers to the old path. `calibrated_scan` rather than a
        # bare filter because "no file cites it" and "the walk missed docs/" are
        # otherwise the same empty vector.
        danglers = calibrated_scan(
            _governed(files);
            match=x -> occursin("klaus_regime.md", _text(x)),
            present=_probe("read `guides/klaus_regime.md` first"),
            absent=_probe("read `guides/fast_larmor_regime.md` first"),
            describe=_describe,
        )
        isempty(danglers) || println("  still points at guides/klaus_regime.md:\n    ",
            join(danglers, "\n    "))
        @test danglers == String[]
    end

    @testset "6. the disambiguation page distinguishes all three" begin
        doc = _body(joinpath("docs", "conventions", "klaus_name_disambiguation.md"))
        for needed in (
            "Klaus et al. 2022",              # ① the paper
            "arXiv:2206.12265",
            "Nat. Phys.",
            "fast-Larmor regime",            # ② the regime
            "p·F·dt > π",
            "rotation-assisted EdH quench",  # ③ our protocol
            "trap-rotation branch",
            "field-rotation branch",
        )
            @test occursin(needed, doc)
        end
        # It must also carry the reason `runs/` was NOT renamed, because that is
        # the part a future session would otherwise "finish".
        @test occursin("compute_run_dir", doc)

        # And CLAUDE.md has to send a reader here before they write the word.
        @test occursin("klaus_name_disambiguation.md", _body("CLAUDE.md"))
    end

    @testset "the allowlist is small, real, and explains itself" begin
        # An allowlist is the soft spot of any naming gate. Three properties:
        # every entry exists (so a deleted file cannot silently widen it), every
        # entry actually carries a retirement note (so it is a document ABOUT
        # the rename, not a straggler), and the list stays short.
        @test length(_MAY_NAME_RETIRED) <= 8
        for f in _MAY_NAME_RETIRED
            @testset "$f" begin
                @test isfile(joinpath(_REPO, f))
                isfile(joinpath(_REPO, f)) || return nothing
                t = _body(f)
                @test occursin(
                    r"retract|was \"Klaus|Renamed 2026-08-19|previously mislabelled|no longer has one|#344"i,
                    t,
                )
            end
        end
    end
end
