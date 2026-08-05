using Test
using SpinorBEC
using SpinorBEC: _code_rev_or_nothing, code_tree_hash

# A code revision that names bytes the process is not running is worse than none.
#
# `code_tree_hash` reads the DISK. Under `-J <custom sysimage>` the process runs
# code baked at build time, so the two can differ — limit 1 of that function's
# own docstring, and reachable in production: `backends_uge.jl:191` adds `-J`
# whenever `SPINORBEC_TSUBAME_SYSIMAGE` is set (`tick.jl:95`). A record carrying
# a wrong revision is indistinguishable from a correct one, which is the exact
# shape the provenance design exists to remove.
#
# BOTH DIRECTIONS MATTER, and the first version of the check failed the second.
# Testing for `-J` alone refuses everything: every julia process carries
# `-J <juliaup>/lib/julia/sys.so`, so an ordinary REPL recorded `nothing`. A
# writer that always declines is not safe, it is silent.

@testset "code_rev refuses under a custom sysimage" begin
    @testset "an ordinary process DOES record a revision" begin
        # The negative half. Without it, "refuses under sysimage" is satisfied
        # by a function that refuses always.
        @test _code_rev_or_nothing() !== nothing
        @test _code_rev_or_nothing() == code_tree_hash()
    end

    @testset "the env var alone is enough to refuse" begin
        withenv("SPINORBEC_TSUBAME_SYSIMAGE" => "/gs/fs/whatever/spinorbec.so") do
            @test _code_rev_or_nothing() === nothing
        end
        # …and clearing it restores recording, so the refusal is not sticky
        withenv("SPINORBEC_TSUBAME_SYSIMAGE" => "") do
            @test _code_rev_or_nothing() !== nothing
        end
    end

    @testset "the stock sysimage is not a custom one" begin
        # This is the discrimination the first version got wrong. Julia's own
        # sys.so must not trip it; anything outside the installation must.
        stock = [a for a in Base.julia_cmd().exec if startswith(a, "-J")]
        @test !isempty(stock)                       # or the premise is untested
        @test any(a -> occursin(joinpath("lib", "julia", "sys."), a), stock)
        # the live process is running exactly that, and records
        @test _code_rev_or_nothing() !== nothing
    end
end
