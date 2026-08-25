# What the retraction rules DO and DO NOT catch, replayed against the shapes
# that actually happened here.
#
# WHY NOT THE MUTATION HARNESS. Issue #465 asked for the eight mis-retractions to
# be injected as mutants and the kill count measured. They cannot be: `test/mutation/run.jl`
# "edits files under `src/` and restores them" and "refuses to start on a dirty
# `src/`" — that clean-and-restore invariant is what makes its report trustworthy,
# and its `severity` ranks a PHYSICS error (wrong sign, wrong ground state, wrong
# order of accuracy). A mis-retraction is a defect in `docs/campaign/claims.toml`
# and causes no physics error at all. Widening the harness to reach `docs/` would
# trade a verified invariant for a category it was not built to rank.
#
# So the same question, asked where the ledger gates live. Each shape below is
# built as a synthetic row and run through the real rules, and the useful output
# is NOT a single number — it is the three-way split:
#
#   :rejected     the gates refuse it. It cannot land.
#   :visible      the gates force the fact onto the page but cannot judge it. A
#                 human reading the row can see the defect; CI cannot.
#   :out_of_reach nothing here can see it, and saying so is the point. A gate
#                 that implies more than it verifies is worse than no gate.
#
# THE COUNT "EIGHT" IS NOT ASSERTED. `pr_mistake_census_2026_08_22.md:142` lists
# `#197 #215 #295 #358 #411 #436 #442/#446` — seven items, one of them a pair —
# under prose that says eight, and #295 retracted claims in TWO documents. Rather
# than pick a number and restate it in a third place, this file enumerates SHAPES,
# which are distinguishable, and pins the split rather than the total.

using SpinorBEC
using Test
using TOML

const _SHAPE_BASE = Dict{String, Any}(
    "id" => "probe", "claim" => "c", "type" => "B", "scope" => "s",
    "uncertainty" => "unbounded: probe", "uncertainty_basis" => "none",
    "evidence" => String[], "evidence_status" => "absent",
    "commit" => "unknown", "doc" => "CLAUDE.md", "section" => "1",
)

"""Write a one-row ledger and return `:throws` or the parsed row."""
function _parse_row(dir, name, row)
    path = joinpath(dir, name * ".toml")
    open(path, "w") do io
        println(io, "schema_version = 1")
        println(io, "")
        println(io, "[[claim]]")
        TOML.print(io, row)
    end
    try
        only(claim_ledger(; path=path))
    catch e
        e isa ArgumentError ? :throws : rethrow()
    end
end

_row(; kw...) = merge(_SHAPE_BASE, Dict{String, Any}(String(k) => v for (k, v) in kw))

@testset "the retraction rules against the shapes that happened" begin
    verdicts = Dict{Symbol, Symbol}()

    mktempdir() do d
        # ── REJECTED ─────────────────────────────────────────────────────────
        # #295: a replacement made out of nothing. The killing row is believed,
        # supersedes another, and points at evidence that does not resolve.
        r = _parse_row(d, "prose_replacement",
            _row(status="live", supersedes=["other"], evidence_status="absent",
                uncertainty_basis="none"))
        verdicts[:prose_grounded_replacement] =
            (r === :throws || !retraction_is_grounded(r)) ? :rejected : :visible

        # #295 again, the other half: refuted, no successor, and no grounds of
        # its own. Nothing in the tree would say why this died.
        r = _parse_row(d, "bare_retirement",
            _row(status="refuted", retired_literal="1.234",
                retraction_evidence="grid, 32^3 -> 64^3: the ordering inverts"))
        verdicts[:bare_retirement_no_grounds] =
            (r === :throws || !retraction_is_self_grounded(r)) ? :rejected : :visible

        # A retirement that declares no `retraction_evidence` at all.
        r = _parse_row(d, "no_evidence_field",
            _row(status="refuted", retired_literal="1.234", note="n", pr=1))
        verdicts[:retraction_evidence_absent] =
            r === :throws ? :rejected : :visible

        # #442's shape at the point where it is catchable: the field is present
        # and says nothing checkable. Caught by the arm in
        # `test_retracted_numbers_carry_their_replacement.jl`, which is where the
        # text predicate lives.
        r = _parse_row(d, "prose_evidence",
            _row(status="refuted", retired_literal="1.234", note="n", pr=1,
                retraction_evidence="later work disagreed with this"))
        verdicts[:retraction_states_no_axis] =
            if (
                r !== :throws && !occursin(r"\d", r.retraction_evidence) &&
                !occursin(CLAIM_RETRACTION_PREMISE_ESCAPE, r.retraction_evidence)
            )
                :rejected
            else
                :visible
            end

        # A reduction quoted with no window. #436's precondition.
        r = _parse_row(d, "reduction_no_window",
            _row(status="live", quantity="peak P_adj @ probe"))
        verdicts[:reduction_without_window] = r === :throws ? :rejected : :visible

        # ── VISIBLE, NOT REJECTED ───────────────────────────────────────────
        # #442 as it actually was: the axis IS named and the numbers ARE there,
        # and the comparison is one seed against one seed. The field makes the
        # power visible on the page. No rule here can decide it is too low —
        # that is a judgement about the physics, and a gate that guessed would
        # be the too-strict kind this project has measured getting deleted.
        r = _parse_row(d, "underpowered",
            _row(status="refuted", retired_literal="1.234", note="n", pr=1,
                retraction_evidence="seed count, 1 -> 1: 27.8 against 39.7"))
        verdicts[:underpowered_comparison] =
            (r !== :throws && retraction_is_self_grounded(r)) ? :visible : :rejected

        # #436: one window-dependent number replaced by another. Both rows now
        # have to declare their window, so the two windows are side by side and
        # a reader can see they differ. Nothing can rule that the second window
        # is no better than the first.
        r = _parse_row(d, "window_for_window",
            _row(status="live", quantity="peak P_adj @ probe",
                window="hold, frames 34-42", reduction="max", boundary="accept"))
        verdicts[:window_swapped_for_window] =
            (r !== :throws && r.window !== nothing) ? :visible : :rejected

        # #411: measured with one switch off and generalised to production. The
        # axis must be named, so `noise off -> on` appears — but a row that names
        # the axis and generalises anyway still parses.
        r = _parse_row(d, "generalised",
            _row(status="refuted", retired_literal="1.234", note="n", pr=1,
                retraction_evidence="noise, off -> off: the loss is 1 event"))
        verdicts[:generalised_from_a_switch] =
            (r !== :throws && retraction_is_self_grounded(r)) ? :visible : :rejected

        # ── OUT OF REACH ────────────────────────────────────────────────────
        # #358: the correction said the paper "does not exist", eight lines above
        # a citation to the same arXiv number. That is a prose self-contradiction
        # inside one document. The ledger has no view of it, and pretending
        # otherwise would be the worst outcome here.
        verdicts[:prose_self_contradiction] = :out_of_reach

        # #197: two factorial claims were both called refuted and one of them
        # survived. A row can be perfectly formed, grounded, and FACTUALLY WRONG.
        # No schema rule reaches that; only re-running the arm does.
        verdicts[:retracted_a_claim_that_survived] = :out_of_reach
    end

    @testset "each shape lands where this file says it lands" begin
        expected = Dict(
            :prose_grounded_replacement => :rejected,
            :bare_retirement_no_grounds => :rejected,
            :retraction_evidence_absent => :rejected,
            :retraction_states_no_axis => :rejected,
            :reduction_without_window => :rejected,
            :underpowered_comparison => :visible,
            :window_swapped_for_window => :visible,
            :generalised_from_a_switch => :visible,
            :prose_self_contradiction => :out_of_reach,
            :retracted_a_claim_that_survived => :out_of_reach,
        )
        @test keys(verdicts) == keys(expected)
        for (k, v) in expected
            verdicts[k] == v || println("  shape `", k, "` is now `", verdicts[k],
                "`, this file expected `", v, "`")
            @test verdicts[k] == v
        end
    end

    @testset "the split is real in all three directions" begin
        # If every shape landed in one bucket the table above would be a list,
        # not a measurement. Each class must be occupied.
        for cls in (:rejected, :visible, :out_of_reach)
            @test count(==(cls), values(verdicts)) >= 1
        end
        # And the honest headline, printed rather than asserted as a total:
        for cls in (:rejected, :visible, :out_of_reach)
            println("  ", cls, ": ", count(==(cls), values(verdicts)),
                " of ", length(verdicts), " shapes")
        end
    end
end
