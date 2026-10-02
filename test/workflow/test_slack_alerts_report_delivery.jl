using Test
using SpinorBEC
using SpinorBEC: SLACK_STATUSES, _slack_is_quiet

# Delivery must be distinguishable from missing configuration or failed POST.
# A non-quiet alert that was not delivered must remain visible in the log.

# ORDERING IS LOAD-BEARING. The positive control installs the typed method the
# extension installs, and Julia has no clean way to take it back, so it runs
# LAST. Everything asserting `false` runs before it.

const _EXT = normpath(
    joinpath(@__DIR__, "..", "..", "ext", "SpinorBECHTTPExt",
        "SpinorBECHTTPExt.jl"),
)

codelines(path) = [l for l in eachline(path) if !startswith(strip(l), "#")]

@testset "Slack alerts report whether they were delivered" begin
    @testset "an undelivered alert returns false" begin
        # this suite runs without HTTP, which is the CI condition and — because
        # nothing in src/ loads HTTP — the production one too
        @test notify_slack("dropped"; url="https://example.invalid/hook",
            status=:error) === false
        @test notify_slack("no url"; url="", status=:error) === false
        @test notify_slack("no url"; url="", status=:info) === false
    end

    @testset "an undelivered non-quiet alert is loud" begin
        @test_logs (:warn,) match_mode = :any notify_slack(
            "breaker tripped"; url="", status=:error)
        # ...and a quiet one is not, or every tick would warn about chatter
        @test _slack_is_quiet(:info)
        @test _slack_is_quiet(:success)
        @test !_slack_is_quiet(:error)
        @test !_slack_is_quiet(:warning)
    end

    # The vocabulary must be shared. A status outside it reaches the extension's
    # `else` branch and is coloured as info regardless of what it meant.
    @testset "one status vocabulary, enforced at the call site" begin
        @test SLACK_STATUSES == (:info, :success, :warning, :error)
        @test_throws ArgumentError notify_slack("x"; url="", status=:warn)
        @test_throws ArgumentError notify_slack("x"; url="", status=:critical)

        ext = join(codelines(_EXT), "\n")
        for s in SLACK_STATUSES
            s === :info && continue   # :info IS the extension's default colour
            @test occursin("status == :$(s)", ext)
        end
    end

    # The extension's own arms, read as source because this environment has no
    # HTTP to load: exactly one success return and both failure paths explicit.
    @testset "the extension distinguishes its three outcomes" begin
        ext = join(codelines(_EXT), "\n")
        @test occursin("return true", ext)
        @test length(collect(eachmatch(r"return false", ext))) >= 2
        # the old shape: a bare `return nothing` after the try/catch
        @test !occursin(r"catch e\s*\n\s*@warn[^\n]*\n\s*end\s*\n\s*return nothing", ext)
    end

    # POSITIVE CONTROL, and the load-bearing one: every assertion above is about
    # `false`, and a `notify_slack` hard-wired to `false` would satisfy all of
    # them — the defect being fixed, mirrored. Install the typed method the
    # extension installs and show a `true` can travel out.
    @testset "a delivered alert returns true" begin
        @eval SpinorBEC.send_slack_notification(
            ::String, ::String, ::String, ::Symbol
        ) = true
        @test Base.invokelatest(
            notify_slack, "posted";
            url="https://example.invalid/hook", status=:error) === true
    end
end
