using Test
using SpinorBEC
using SpinorBEC: Units

# Exactly ONE expression in `src/` may turn a magnetic field into the
# dimensionless linear-Zeeman coupling `p`. Everything else delegates.
#
# This replaces a twenty-line list. `docs/STATE.md` used to enumerate every site
# touching `bfield_to_p`, which was derived and therefore could not rot — but a
# list is a description, and what a reader needs is the PROPERTY: the sign is
# declared once. A property stated in a document is not enforced; a second
# independent computation could appear and the document would happily list
# twenty-one sites. So the list is gone and the property is a gate.
#
# The history this protects: `linear_zeeman_p` in `coefficients.jl` computed
# `+g_F μ_B B` while `Units.bfield_to_p` computed `-g_F μ_B B` — opposite signs
# for the same physical quantity, measured 2026-08-04 as +0.3846836128860268 vs
# −0.3846836128860268 at 2.6 nT on Eu151. It survived two months because eight
# test files exercised the VALUE and none asserted UNIQUENESS.
#
# Convention (Kawaguchi-Ueda): the operator is `H = -p·F_z + q·F_z²` and the lab
# field enters as `p ≡ -g_F μ_B B`, because the atomic moment is `μ = -g_F μ_B F`.
# So +Bz on a g_F > 0 atom (Eu, Cr, He*) gives ground state m = −F. That sentence
# is judgement — why the convention is what it is — and stays hand-written in
# CLAUDE.md. This file only enforces that it is stated once.

const SRC = normpath(joinpath(@__DIR__, "..", "..", "src"))

"Lines in `src/` that build a magnetic moment from `g_F` and the Bohr magneton."
function sign_sites()
    hits = String[]
    for (root, _, files) in walkdir(SRC)
        for f in files
            endswith(f, ".jl") || continue
            path = joinpath(root, f)
            for (n, line) in enumerate(eachline(path))
                # `g_F` AND the magneton in one expression. `g_J` sites (the
                # electronic g-factor, used for the hyperfine quadratic shift and
                # for building each species' moment) are a different quantity and
                # must not be counted — atoms.jl has ten of them.
                occursin("BOHR_MAGNETON", line) || continue
                occursin(r"\bg_F\b", line) || continue
                startswith(strip(line), "#") && continue
                push!(hits, relpath(path, dirname(SRC)) * ":" * string(n))
            end
        end
    end
    hits
end

@testset "the B → p sign is declared exactly once" begin
    sites = sign_sites()

    # CALIBRATION. An extractor that matches nothing reports "declared once" in
    # the same breath as "declared zero times", and both look like success next
    # to `length(sites) <= 1`. Assert the real site is found before judging the
    # count, and assert the g_J sites are excluded rather than absent by luck.
    @testset "the instrument finds the known site" begin
        @test !isempty(sites)
        @test any(s -> occursin("io/units.jl", s), sites)
        # atoms.jl builds ten moments from g_J; none may be counted here
        @test !any(s -> occursin("initialization/atoms.jl", s), sites)
    end

    @testset "exactly one site" begin
        if length(sites) != 1
            println("\nMore than one expression computes the B → p sign:")
            foreach(s -> println("  ", s), sites)
            println("\nThe sign is declared ONCE, in `Units.bfield_to_p`. Every other")
            println("converter must delegate to it — see CLAUDE.md's Zeeman section for")
            println("why the convention is `p ≡ -g_F μ_B B`. A second independent")
            println("computation is how `linear_zeeman_p` carried the opposite sign for")
            println("two months.")
        end
        @test length(sites) == 1
        @test occursin("src/workflow/io/units.jl", only(sites))
    end

    # The value, with its sign, at a field where a wrong sign is unmistakable.
    # Pinning the NUMBER as well as the uniqueness means a "fix" that keeps one
    # site but flips it still fails.
    @testset "and it has the Kawaguchi-Ueda sign" begin
        p = Units.bfield_to_p(2.6e-5, 1.16, 1.0)   # 2.6 nT in Gauss, g_F > 0
        @test p < 0
        # +Bz on a g_F > 0 atom must lower m = −F, i.e. `-p·F_z` favours m = −F
        @test Units.bfield_to_p(1.0, 1.16, 1.0) < 0
        @test Units.bfield_to_p(-1.0, 1.16, 1.0) > 0
        # linear in B, so a factor-two field is a factor-two coupling
        @test Units.bfield_to_p(2.0, 1.16, 1.0) ≈ 2 * Units.bfield_to_p(1.0, 1.16, 1.0)
    end

    # Every caller must route through the one declaration rather than re-deriving
    # it. Checked as "the caller mentions `bfield_to_p`", which is weak on its own
    # — the uniqueness test above is what makes it strong: a caller that did NOT
    # delegate would have to compute the sign, and that would show up there.
    @testset "the known converters delegate" begin
        for f in ("src/hamiltonian/coefficients.jl",
            "src/workflow/experiments/runtime/b_block_builders.jl",
            "src/workflow/experiments/schema/parsing_units.jl",
            "src/foundation/types/preset.jl")
            path = joinpath(dirname(SRC), f)
            @test isfile(path)
            @test occursin("bfield_to_p", read(path, String))
        end
    end
end
