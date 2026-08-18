using Test
using SpinorBEC

# The snapshots route must not serve frame indices under a key the front end
# plots as time.
#
# When `dynamics/times` and the snapshot count could not be aligned, the route
# emitted `collect(1.0:n_snaps)` as `pop_times`. Those are frame INDICES.
# `dashboard/src/components/charts/DynamicsOverview.tsx` reads `s.pop_times` and
# uses it as the x-axis, so a reader saw an axis running 1, 2, 3… in whatever
# unit they assumed, for a run whose real times were unknown.
#
# Absence written out as a plausible value — the same shape as the rotating
# handler's literal `0.0` for transverse spin, fixed the same day.
#
# The front end was already correct: `if (!s?.pop_times) return []`. **Only the
# producer was inventing.** Omitting the key makes the chart empty, which is what
# "we do not know the times" should look like.

const _ROUTE = normpath(
    joinpath(@__DIR__, "..", "..", "src", "workflow", "io",
        "dashboard", "routes", "snapshots.jl"),
)
const _CHART = normpath(
    joinpath(@__DIR__, "..", "..", "dashboard", "src",
        "components", "charts", "DynamicsOverview.tsx"),
)

@testset "the dashboard does not invent a time axis" begin
    src = read(_ROUTE, String)
    code = [l for l in split(src, '\n') if !startswith(strip(l), "#")]

    # CALIBRATION. A scan of the wrong file, or one whose pattern matches
    # nothing, reports a clean route in the same words a clean route uses.
    @testset "the route is being read" begin
        @test isfile(_ROUTE)
        @test any(l -> occursin("pop_times", l), code)
        @test any(l -> occursin("dynamics/times", l), code)
    end

    @testset "no frame-index fallback is assigned to pop_times" begin
        # the exact shape that was there
        bad = [
            l for l in code if occursin(r"pop_times.*collect\(1\.0:", l) ||
            occursin(r"collect\(1\.0:n_snaps\)", l)
        ]
        isempty(bad) || println("\n  a frame-index range is still being served:\n    ",
            join(strip.(bad), "\n    "))
        @test isempty(bad)
    end

    @testset "the mismatch is reported instead" begin
        @test occursin("pop_times_unavailable", src)
        # and it says what did not line up, so the reason is not guesswork
        @test occursin("n_times", src)
        @test occursin("n_snapshots", src)
    end

    # The front end's contract, pinned here because the fix depends on it: it
    # must treat a missing `pop_times` as "no chart", not as an empty axis. If
    # this ever changes, omitting the key stops being the honest option.
    @testset "the front end treats a missing key as no data" begin
        @test isfile(_CHART)
        tsx = read(_CHART, String)
        @test occursin("pop_times", tsx)
        @test occursin(r"!s\??\.?\??pop_times|!s\?\.pop_times|!s\.pop_times", tsx)
    end
end
