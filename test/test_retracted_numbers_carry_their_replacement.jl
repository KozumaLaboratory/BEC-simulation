# A retracted number may not appear in a document without its replacement.
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
# later in a table, and a reader who lands there by search or by scrolling to
# "what Omega should I use" never sees it. Documents are read by section, not
# from the top.
#
# So: wherever a retracted value appears, its replacement must appear in the SAME
# file. That is cheap, it is mechanical, and it does not require anyone to
# remember the retraction — the gate remembers.
#
# This is deliberately a REGISTRY and not a one-off. Adding a row is the act of
# retracting a number, and it costs one line.

using SpinorBEC
using Test

include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

const _REPO = normpath(joinpath(@__DIR__, ".."))

"""
    Retraction(pattern, replacement, why)

`pattern` — how the retracted value is written (a Regex, because "0.468" and
"0.468 ± 0.003" and "0.468±0.003" are the same claim).
`replacement` — a Regex that must ALSO match somewhere in the same file.
`why` — printed on failure, so the person who trips it does not have to go
digging for what changed.
"""
struct Retraction
    pattern::Regex
    replacement::Regex
    why::String
end

const RETRACTIONS = [
    Retraction(
        r"0\.468",
        r"0\.68",
        "|Omega*|/omega_perp = 0.468 ± 0.003 was re-derived 2026-08-19 to " *
        "0.68 ± 0.04 at the anti-aligned preparation, AND the mechanism changed: " *
        "the response is even in Omega (so chirality is irrelevant) and a static " *
        "weakened trap reproduces it (so rotation is not required). " *
        "Authority: docs/campaign/edh_quench_polarisation_decision.md §9.",
    ),
]

"""Every `.md` under `docs/`, excluding the dated audit dumps."""
function _docs()
    out = String[]
    root = joinpath(_REPO, "docs")
    for (dir, dirs, files) in walkdir(root)
        filter!(d -> !(d in (".git", "node_modules", "worktrees")), dirs)
        occursin(joinpath("docs", "audit"), dir) && continue
        for f in files
            endswith(f, ".md") && push!(out, relpath(joinpath(dir, f), _REPO))
        end
    end
    sort(out)
end

@testset "a retracted number never appears without its replacement" begin
    docs = _docs()
    @test !isempty(docs)

    mktempdir() do d
        for r in RETRACTIONS
            # Real probe FILES, because the predicate reads its argument. A
            # bare sentinel string would throw on `read`, and the throw would
            # look like a broken gate rather than a miswired control.
            bad = joinpath(d, "carries_retracted_only.md")
            good = joinpath(d, "carries_both.md")
            write(bad, "the value is 0.468 ± 0.003\n")
            write(good, "0.468 ± 0.003 was superseded by 0.68 ± 0.04\n")

            offend(f) =
                let body = read(isabspath(f) ? f : joinpath(_REPO, f), String)
                    occursin(r.pattern, body) && !occursin(r.replacement, body)
                end

            # Must SEE a file carrying only the retracted value, and must REJECT
            # one that also carries the replacement — otherwise "no offenders"
            # is the same string as "the pattern matches nothing".
            offenders = calibrated_scan(
                docs; match=offend, present=bad, absent=good,
                describe=f -> isabspath(f) ? basename(f) : f,
            )
            isempty(offenders) || println(
                "  quotes a retracted number with no " *
                "replacement in the same file:\n    ",
                join(offenders, "\n    "), "\n  → ", r.why)
            @test offenders == String[]
        end
    end
end
