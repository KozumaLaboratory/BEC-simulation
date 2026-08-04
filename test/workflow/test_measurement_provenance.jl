using Test
using SpinorBEC

# Measurement outputs must say what produced them, and the reader must refuse to
# aggregate files that disagree.
#
# `_assert_point_provenance` already does this for `run_yaml`, and the figure
# drivers bypassed it. The same bug class then appeared four times in one session:
# six jobs overwrote one log because the swept rate was absent from its name; a
# merge read CSVs stamped 10:49 as a 13:34 rerun's output and reported pre-fix
# numbers as post-fix; a run started 14 seconds after its source was synced and
# its version could not be established afterwards; and three "different" initial
# conditions agreed to 13 digits because they were the same code. Distinguishing
# filenames is a convention, and conventions get forgotten. A refusal does not.
@testset "measurement provenance" begin
    dir = mktempdir()
    write(joinpath(dir, "a.csv"),
        "# provenance: head=abc123 dirty=false spgpe.jl=111111111111\nx,y\n1,2\n")
    write(joinpath(dir, "b.csv"),
        "# provenance: head=abc123 dirty=false spgpe.jl=111111111111\nx,y\n3,4\n")
    write(joinpath(dir, "c.csv"),
        "# provenance: head=def456 dirty=false spgpe.jl=222222222222\nx,y\n5,6\n")
    write(joinpath(dir, "dirty.csv"),
        "# provenance: head=abc123 dirty=true spgpe.jl=111111111111\nx,y\n7,8\n")
    write(joinpath(dir, "bare.csv"), "x,y\n9,10\n")
    f(n) = joinpath(dir, n)

    @testset "agreeing files pass and return the record" begin
        p = assert_same_provenance([f("a.csv"), f("b.csv")])
        @test occursin("head=abc123", p)
    end

    @testset "disagreeing files are refused" begin
        # The 10:49-read-as-13:34 case. Averaging two code versions must not be
        # something a reader does quietly.
        @test_throws ArgumentError assert_same_provenance([f("a.csv"), f("c.csv")])
        err = try
            assert_same_provenance([f("a.csv"), f("c.csv")])
        catch e
            sprint(showerror, e)
        end
        @test occursin("a.csv", err)          # names the offenders
        @test occursin("c.csv", err)
    end

    @testset "a file with no provenance is an error, not a skip" begin
        # Treating an unstamped file as "probably fine" is how this happened.
        @test_throws ArgumentError assert_same_provenance([f("a.csv"), f("bare.csv")])
        @test_throws ArgumentError assert_same_provenance([f("bare.csv")])
    end

    @testset "require_clean rejects a dirty tree only when asked" begin
        @test assert_same_provenance([f("dirty.csv")]) isa String
        @test_throws ArgumentError assert_same_provenance([f("dirty.csv")];
            require_clean=true)
    end

    @testset "the header records HEAD, dirtiness and per-source hashes" begin
        h = provenance_header("src/solvers/spgpe.jl", "Project.toml")
        @test startswith(h, "# provenance:")
        @test occursin("head=", h)
        @test occursin("dirty=", h)
        @test occursin("spgpe.jl=", h)
        @test occursin("Project.toml=", h)
        # A missing source must be visible rather than silently omitted.
        @test occursin("missing", provenance_header("does/not/exist.jl"))
        # Two different files must not hash the same.
        @test provenance_header("src/solvers/spgpe.jl") !=
            provenance_header("Project.toml")
    end
end
