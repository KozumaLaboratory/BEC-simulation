using Test
using SpinorBEC
using JLD2

# A write that did not survive must fail the RUN, not be discovered by a storage
# sweep six months later.
#
# On 2026-07-29 the group quota hit 1000.04 GB and two runs wrote truncated point
# files — EOFError on reopen — then reported `"completed": true, "oom_killed":
# false, "exception_type": null`, with `_exit_summary.json` stamped one second
# apart. The volume filled; the write returned; the move succeeded; the run
# declared success over a file nobody could open.
@testset "a file that cannot be read back fails the write" begin
    f = SpinorBEC._assert_readable_jld2

    mktempdir() do d
        good = joinpath(d, "good.jld2")
        jldopen(h -> (h["x"] = 1), good, "w")
        @test f(good) === nothing              # a real file passes

        bad = joinpath(d, "truncated.jld2")
        write(bad, "HDF5-bas")                 # plausible head, no body — what a
        @test_throws ErrorException f(bad)     # quota-killed write leaves behind

        # not a jld2 at all: not this function's business, and silently rejecting
        # every non-jld2 path would make the guard fire on things it cannot judge
        other = joinpath(d, "notes.txt")
        write(other, "x")
        @test f(other) === nothing
    end

    # and the error must SAY what to check — a full quota reports EDQUOT/SIGBUS
    # and `df` shows the raw 304T Lustre mount, so "disk full" never appears
    mktempdir() do d
        bad = joinpath(d, "t.jld2")
        write(bad, "nope")
        msg = try
            f(bad)
            ""
        catch e
            sprint(showerror, e)
        end
        @test occursin("cannot read it back", msg)
        @test occursin("quota", msg)
    end
end
