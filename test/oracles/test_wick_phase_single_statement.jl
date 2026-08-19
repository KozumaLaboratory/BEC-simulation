using Test
using SpinorBEC
using SpinorBEC: wick_phase

include(joinpath(@__DIR__, "..", "helpers", "calibrated_scan.jl"))

# `wick_phase` is the ONE statement of the imaginary-time ↔ real-time branch.
#
# WHY THIS GATE EXISTS (CLAUDE.md commitment 11)
#
# Before 2026-08-19 the branch `imaginary_time ? exp(arg) : cis(arg)` was
# written out by hand at 8 scalar sites, and a further 32 `if imaginary_time`
# blocks split the propagator — 14 of which carried a FULL COPY of their
# exponent in each arm. The worst was `apply_diagonal_potential_step!`, where
# the diagonal Hamiltonian (the most-executed expression in the simulator) was
# stated four times: {imaginary, real} × {LHY on, LHY off}. Nothing checked
# that the four agreed.
#
# The migration alone does not hold. `COUPLING_TOL` is the cautionary case in
# this same tree: it was introduced as the named form of `1e-30`, the old
# spelling was left legal "for legacy call sites", and it lost 7 : 121. So the
# rule is the gate, not the refactor: a new hand-written Wick branch is RED
# here on the day it lands.
#
# WHAT IS ALLOWED
#
# Two shapes are legitimate and are named individually below, not waved through
# by a loose predicate:
#
#   * a `Val{IT}` type-parameter branch inside a device kernel, where the
#     compiler resolves it and there is no runtime test at all;
#   * a dispatch to a separate `_imag!` routine, where the two paths are
#     genuinely different algorithms (Euler 5-stage under a hyperbolic rotation
#     is not the same code as under a circular one).
#
# Neither of those is a duplicated exponent, which is the thing being guarded.

const _WICK_SRC_ROOTS = [
    normpath(joinpath(@__DIR__, "..", "..", "src")),
    normpath(joinpath(@__DIR__, "..", "..", "ext")),
]

# The definition site states the branch on purpose, and its docstring quotes
# the retired spellings so the next reader knows what was removed.
const _WICK_DEFINITION_SITE = "foundation/wick.jl"

"""Source lines with comments stripped — a spelling QUOTED in a docstring is
documentation, not a second declaration."""
function _wick_code_lines()
    out = Tuple{String, Int, String}[]
    for root in _WICK_SRC_ROOTS
        isdir(root) || continue
        parent = dirname(root)
        for (dir, dirs, files) in walkdir(root)
            filter!(d -> !(d in (".git", "node_modules", "worktrees")), dirs)
            for f in files
                endswith(f, ".jl") || continue
                p = joinpath(dir, f)
                rel = relpath(p, parent)
                occursin(_WICK_DEFINITION_SITE, replace(rel, '\\' => '/')) && continue
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

# The retired scalar form: a runtime `Bool` selecting between exp and cis.
const _HAND_WICK = r"imaginary_time\s*\?[^:]*\b(exp|cis)\b"

@testset "wick_phase is the only statement of the Wick rotation" begin
    lines = _wick_code_lines()

    @testset "corpus is non-empty and reaches both trees" begin
        @test !isempty(lines)
        @test any(l -> startswith(l[1], "src/"), lines)
        @test any(l -> startswith(l[1], "ext/"), lines)
    end

    @testset "no hand-written scalar Wick ternary survives" begin
        # Calibrated: the predicate must match the shape that was removed, and
        # must NOT match the shape that replaced it. A gate that fired on the
        # replacement would be un-passable; one that fired on nothing would be
        # the "I could not look" failure this helper exists to prevent.
        hits = calibrated_scan(
            lines;
            match=l -> occursin(_HAND_WICK, l[3]),
            present=("probe", 0, "factor = imaginary_time ? exp(-c * dt) : cis(-c * dt)"),
            absent=("probe", 0, "factor = wick_phase(-c * dt, imaginary_time)"),
            describe=l -> string(l[1], ":", l[2], "  ", strip(l[3])),
        )
        if !isempty(hits)
            for h in hits
                @info "hand-written Wick ternary" file=h[1] line=h[2] code=strip(h[3])
            end
        end
        @test isempty(hits)
    end

    @testset "the two branch forms agree, exactly" begin
        # Bit-identity, not approximate agreement: the migration claimed to be
        # a rewrite of the same instructions, and this is what says so.
        for arg in (0.0, -1e-8, -0.3, -3.7, 12.5, -700.0)
            @test wick_phase(arg, true) === exp(arg)
            @test wick_phase(arg, false) === cis(arg)
            @test wick_phase(arg, Val(true)) === wick_phase(arg, true)
            @test wick_phase(arg, Val(false)) === wick_phase(arg, false)
        end
        @test wick_phase(-0.3f0, false) isa Complex{Float32}
        @test wick_phase(-0.3f0, true) isa Float32
        args = [-0.1, -0.2, -0.3]
        @test wick_phase(args, true) == exp.(args)
        @test wick_phase(args, false) == cis.(args)
    end

    @testset "the imaginary branch decays and the real branch does not" begin
        # Directional, so the gate is not satisfied by two copies of the same
        # wrong thing: ITP must SHRINK a positive-energy component and real time
        # must preserve its modulus. Swapping exp and cis fails this.
        @test wick_phase(-1.0, true) < 1.0
        @test wick_phase(-1.0, true) > 0.0
        @test abs(wick_phase(-1.0, false)) ≈ 1.0 atol = 1e-15
        # …and the sign convention: `arg` is the COMPLETE exponent, so a
        # POSITIVE arg must grow. A caller that negates twice trips here.
        @test wick_phase(+1.0, true) > 1.0
    end
end
