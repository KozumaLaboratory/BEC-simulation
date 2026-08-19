using Test
using SpinorBEC
using SpinorBEC: COUPLING_TOL, ROTATION_TOL, DENOM_FLOOR, UNDERFLOW_FLOOR,
    is_active, safe_div

include(joinpath(@__DIR__, "..", "helpers", "calibrated_scan.jl"))

# `foundation/thresholds.jl` is the ONE place the numerical-zero thresholds are
# written. No production file may carry the bare literal.
#
# WHY THIS GATE EXISTS (CLAUDE.md commitment 11)
#
# `COUPLING_TOL = 1e-30` was introduced to delete the bare literal, and its own
# docstring then said "the bare values are kept available for legacy call
# sites". Measured 2026-08-19: `COUPLING_TOL` had 7 references and the bare
# `1e-30` had 121, in 60 files. The migration lost 17 : 1 because the old
# spelling stayed legal.
#
# The post-mortem is worth keeping, because "people were lazy" is the wrong
# reading. The literal was doing TWO jobs and the new name covered one:
#
#   is-it-active?    abs(c1) > 1e-30       → `is_active`, which DID win, 122:10
#   floor-a-divisor  num / max(den, 1e-30) → had no name at all, so all 17 of
#                                            these sites kept the literal
#
# An SSoT that covers part of a pattern leaves the rest looking like debt and
# reads, in the aggregate count, as a failed migration. Both jobs are named now
# (`COUPLING_TOL` / `DENOM_FLOOR`) and this gate keeps them named.
#
# DELIBERATE EXCLUSION: `src/validation/`.
#
# The dumb reference and the reference RHS must restate every constant they
# use — that is what makes them an independent statement rather than a second
# call into the code under test. Their bare literals are the oracle working as
# designed. Excluded BY NAME here so the exclusion is a decision, not a gap.

const _THR_ROOTS = [
    normpath(joinpath(@__DIR__, "..", "..", "src")),
    normpath(joinpath(@__DIR__, "..", "..", "ext")),
]

const _THR_EXCLUDED_PREFIXES = (
    "src/validation/",              # independent statement — see above
    "src/foundation/thresholds.jl", # the declaration site
)

"""Code lines (comments stripped) outside the excluded set."""
function _thr_code_lines()
    out = Tuple{String, Int, String}[]
    for root in _THR_ROOTS
        isdir(root) || continue
        parent = dirname(root)
        for (dir, dirs, files) in walkdir(root)
            filter!(d -> !(d in (".git", "node_modules", "worktrees")), dirs)
            for f in files
                endswith(f, ".jl") || continue
                p = joinpath(dir, f)
                rel = replace(relpath(p, parent), '\\' => '/')
                any(pre -> startswith(rel, pre), _THR_EXCLUDED_PREFIXES) && continue
                for (i, line) in enumerate(eachline(p))
                    j = findfirst('#', line)
                    code = j === nothing ? line : line[1:prevind(line, j)]
                    isempty(strip(code)) && continue
                    push!(out, (rel, i, code))
                end
            end
        end
    end
    out
end

# `\b` will not do: `1e-300` contains `1e-30`, and matching it here would
# report the underflow floor as an unmigrated coupling tolerance. The negative
# control below is exactly that string.
const _BARE_TOL = r"(?<![\w.])1e-30(?![\d])"

@testset "thresholds are declared once" begin
    lines = _thr_code_lines()

    @testset "corpus reaches both trees and excludes what it says it excludes" begin
        @test !isempty(lines)
        @test any(l -> startswith(l[1], "src/"), lines)
        @test any(l -> startswith(l[1], "ext/"), lines)
        @test !any(l -> startswith(l[1], "src/validation/"), lines)
    end

    @testset "no bare 1e-30 outside the declaration site" begin
        hits = calibrated_scan(
            lines;
            match=l -> occursin(_BARE_TOL, l[3]),
            present=("probe", 0, "    n < 1e-30 && return zero(n)"),
            # NOT a coupling tolerance. If the predicate matched this, every
            # adaptive-step denominator would read as an unmigrated site.
            absent=("probe", 0, "    rel > 1e-300 ? f : 2.0"),
            describe=l -> string(l[1], ":", l[2], "  ", strip(l[3])),
        )
        if !isempty(hits)
            for h in hits
                @info "bare threshold literal" file=h[1] line=h[2] code=strip(h[3])
            end
        end
        @test isempty(hits)
    end

    @testset "the two names are separate handles on the same number" begin
        # Equal today, and that is the point of naming them apart: retuning the
        # divisor floor must not silently retune every substep gate. If someone
        # changes one, this line is where the decision becomes visible.
        @test DENOM_FLOOR == COUPLING_TOL
        @test ROTATION_TOL > COUPLING_TOL
        @test UNDERFLOW_FLOOR < COUPLING_TOL
    end

    @testset "is_active and safe_div mean what their names say" begin
        @test !is_active(0.0)
        @test !is_active(COUPLING_TOL)          # boundary is EXCLUSIVE
        @test is_active(nextfloat(COUPLING_TOL))
        @test is_active(-1.0)                   # magnitude, not sign
        @test !is_active(1e-16, ROTATION_TOL)
        @test is_active(1e-14, ROTATION_TOL)

        @test safe_div(2.0, 4.0) == 0.5
        @test isfinite(safe_div(1.0, 0.0))      # the whole reason it exists
        @test safe_div(0.0, 0.0) == 0.0
    end
end
