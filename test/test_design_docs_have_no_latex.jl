using Test
using SpinorBEC

# The design documents must stay readable without a LaTeX renderer.
#
# A3:R-DOC-01 asked for a CHECK, not just compliance. Section 5 of
# `unified_spec_architecture.md` listed it under "the design cannot mechanise,
# or fails outright", reasoning that "the gate domain is over *code* properties,
# not prose". That reasoning is refuted by the gates written on 2026-08-04:
# `test_docs_live_set.jl`, `test_docs_yaml_against_schema.jl` and
# `test_doc_run_citations_resolve.jl` are all gates over prose. This is a
# fourth.
#
# SCOPE IS THE WHOLE POINT. This does NOT forbid LaTeX in the repository —
# `paper3/sign_pattern_lemma1_general_S.md` (242 expressions) is a paper draft
# and `guides/spgpe.md` (85) is a derivation; both need it. It governs the
# DESIGN documents, where the requirement was that a reader can follow the
# argument in a terminal.

const DESIGN_DOCS_NO_LATEX = [
    "docs/design/unified_spec_architecture.md",
    "docs/design/research_spec_and_provenance_architecture.md",
]

const _REPO = normpath(joinpath(@__DIR__, ".."))

# A `$…$` is LaTeX only if it contains a backslash command or a sub/superscript.
# Without that test this flags shell variables: `$T4_LOCAL`/`$` and `${CONFIGS[$`
# in `guides/tsubame.md` matched a naive `\$[^\$]*\$` and inflated a first count
# from 398 to 747. Calibrated below.
# A `$…$` is LaTeX only if it carries a backslash command or a BRACED
# sub/superscript. A bare `_` is not enough: `$T4_LOCAL` has one, and requiring
# only `[_^]` flagged it — caught here by the positive control below, which is
# why that control exists.
const _INLINE_MATH = r"(?<!\$)\$(?!\$)((?=[^$\n]*(?:\\[a-zA-Z]|[_^]\{))[^$\n]{1,120})\$(?!\$)"
const _MACRO = r"\\(begin|frac|sum|int|alpha|beta|gamma|delta|psi|phi|omega|nabla|partial)\b"

# Prose only: fenced blocks AND inline code spans are removed.
#
# A document that discusses the rule has to be able to NAME the thing it
# forbids — this file's own section in unified_spec_architecture.md writes the
# display-math delimiter inside backticks — and a mention inside a code span is
# a quotation, not a formula. Dropping code spans is what lets the gate govern
# a document that explains itself.
#
# The first version stripped only fences and flagged that sentence: it read the
# description of the rule as a violation of it.
_prose(text) = replace(replace(text, r"```.*?```"s => ""), r"`[^`\n]*`" => "")

@testset "design docs carry no LaTeX" begin
    @testset "the documents themselves" begin
        for rel in DESIGN_DOCS_NO_LATEX
            p = joinpath(_REPO, rel)
            @test isfile(p)
            isfile(p) || continue
            s = _prose(read(p, String))
            inline = collect(eachmatch(_INLINE_MATH, s))
            display = length(collect(eachmatch(r"\$\$", s)))
            macros = collect(eachmatch(_MACRO, s))
            isempty(inline) ||
                println("  $rel inline math: ", join((m.match for m in first(inline, 5)), " | "))
            isempty(macros) ||
                println("  $rel macros: ", join((m.match for m in first(macros, 5)), " | "))
            @test isempty(inline)
            @test display == 0
            @test isempty(macros)
        end
    end

    # POSITIVE CONTROL. Three arms of `isempty` are satisfied by a pattern that
    # matches nothing, which is exactly how the first version of this scan
    # failed in the other direction. Plant each shape and require a hit.
    @testset "positive control: the patterns fire" begin
        @test !isempty(collect(eachmatch(_INLINE_MATH, raw"the value $\alpha$ is set")))
        @test !isempty(collect(eachmatch(_INLINE_MATH, raw"at $n_{max}$ the table")))
        @test !isempty(collect(eachmatch(_MACRO, raw"\frac{a}{b}")))
        # …and do NOT fire on a shell variable, which is what made a first
        # count read 747 instead of 398
        @test isempty(collect(eachmatch(_INLINE_MATH, raw"use $T4_LOCAL and $HOME")))
        # …nor inside a fence
        @test isempty(collect(eachmatch(_INLINE_MATH, _prose("```\n\$\\alpha\$\n```"))))
    end
end
