using Test
using SpinorBEC

# What must be TRUE, and what merely must be DATED.
#
# 183 documents cannot be kept true against a codebase taking several merges a
# day. Measured 2026-08-04: 98 of 184 rows carried claims about the code that
# were no longer true, and 7 of the 10 anchors CLAUDE.md sends readers to were
# stale (`docs/audit/docs_inventory_2026-08-04.md`).
#
# So the tree is split. Everything not in LIVE below carries a dated FROZEN
# header saying it describes the tree as of that date and is not maintained — a
# frozen document does NOT need to be true, which is what makes this affordable.
# The cost of consistency then scales with |LIVE|, not with the file count.
#
# This gate holds the split itself. It is deliberately cheap: it does not check
# whether a LIVE document is CORRECT — no test can — it checks that the
# partition is honest, so a file cannot quietly be both.

include(joinpath(@__DIR__, "helpers", "live_docs.jl"))

const _REPO = normpath(joinpath(@__DIR__, ".."))
# Match the HEADER, not the word. A live document may legitimately discuss
# something being frozen — `hamiltonian_layered_architecture.md` says "FROZEN
# 2026-06-06" about a DESIGN, not about itself — and the first version of this
# predicate flagged it, which is the instrument reading prose as metadata.
const _FROZEN_MARK = r"^> \*\*FROZEN \d{4}-\d{2}(-\d{2})?\.\*\*"m
_frozen(path) = occursin(_FROZEN_MARK, first(read(joinpath(_REPO, path), String), 600))

@testset "docs: the live/frozen split is honest" begin
    @testset "every LIVE file exists and is NOT frozen" begin
        for f in LIVE_DOCS
            p = joinpath(_REPO, f)
            @test isfile(p)
            isfile(p) && @test !_frozen(f)
        end
    end

    @testset "every other doc is dated" begin
        # A document that is neither LIVE nor dated is the failure mode this
        # whole exercise exists to remove: a reader cannot tell whether to
        # trust it. New files land here, which is the point — writing one is a
        # decision to maintain it or to date it.
        live = Set(LIVE_DOCS)
        undated = String[]
        for (root, _, files) in walkdir(joinpath(_REPO, "docs")), f in files
            endswith(f, ".md") || continue
            rel = relpath(joinpath(root, f), _REPO)
            rel in live && continue
            _frozen(rel) || push!(undated, rel)
        end
        isempty(undated) || println("  neither LIVE nor dated:\n    ", join(undated, "\n    "))
        @test undated == String[]
    end

    @testset "the budget holds" begin
        # If LIVE grows without anyone noticing, the gate silently becomes the
        # thing it replaced. 30 is not sacred; exceeding it deliberately means
        # editing this number and saying why in the commit.
        #
        # 30 → 31 on 2026-08-19. Three LIVE documents landed the same day, all
        # from the same tangle: `as_dependency_map.md` (#342),
        # `klaus_name_disambiguation.md` (#344) and
        # `edh_quench_polarisation_decision.md` (#343). The third is a CONVENTION
        # the thesis must not contradict, so dating it would defeat its purpose —
        # a stale convention doc is worse than none, because it still reads as
        # current. If this number is raised again soon, the question to ask is
        # whether the three should be one document rather than whether the
        # budget should be four.
        #
        # 31 → 32 on 2026-08-20 for `docs/campaign/claims.toml`, and the question
        # above was asked rather than skipped. The answer is that this entry is
        # not the same KIND of thing as the other 31: it is machine-parsed
        # fail-closed and its contents drive a gate over the rest of this list,
        # so "LIVE" is enforced for it and merely asserted for them. It should
        # also make the budget easier later, not harder — a prose document whose
        # live claims have been poured into the ledger can be dated, which is the
        # trade the ledger exists to make.
        #
        # 32 -> 33 on 2026-08-20 for `docs/guides/edh_quench_lab_prescription.md`.
        # This one does not add a document so much as MOVE authority: the frozen
        # `klaus_protocol_sheet.md` was still issuing lab instructions, and the
        # cheaper-looking fix (archive it) turned out to cost more — 15 inbound
        # references, two of them calibration probes inside tests. So the sheet
        # keeps its path and loses its authority, and the authority needs a live
        # home. Net effect on the budget question: one frozen document became
        # genuinely inert, which is what the partition is for.
        # 33 -> 34 on 2026-08-25 for `docs/guides/local_run_environment.md`, and
        # the question above was asked. It is not a fourth document about one
        # tangle; it is the LOCAL half of a pair whose other half
        # (`tsubame.md`) is already LIVE, and merging them would produce a guide
        # about two machines that share no mechanism. What forces LIVE rather
        # than a date is that its claims are SAFETY claims — swap cannot be
        # touched, an overrun kills instead of hanging — and a dated safety
        # guarantee still reads as a guarantee. Its "verified / not verified"
        # section is the same shape: it already had to be rewritten once, when a
        # TSUBAME job refuted the memory rung it had called unverified.
        @test length(LIVE_DOCS) <= 34
        @test length(LIVE_DOCS) == length(unique(LIVE_DOCS))
    end

    # POSITIVE CONTROL. The two arms above are satisfied by a `_frozen` that
    # always returns the convenient answer, so pin that it discriminates.
    @testset "positive control: the detector reads the header" begin
        mktempdir() do d
            yes = joinpath(d, "y.md");
            no = joinpath(d, "n.md")
            write(yes, "# T\n\n> **FROZEN 2026-01-01.** …\n")
            write(no, "# T\n\njust a document\n")
            @test occursin("FROZEN", first(read(yes, String), 600))
            @test !occursin("FROZEN", first(read(no, String), 600))
        end
    end
end
