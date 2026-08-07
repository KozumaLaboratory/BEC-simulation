using Test
using SpinorBEC
using SpinorBEC: SLACK_STATUSES, _slack_is_quiet

# An alert that was never sent must not look like one that was.
#
# `notify_slack` returned `nothing` on all three outcomes — no `SLACK_WEBHOOK_URL`,
# no HTTP extension loaded, and a successful POST — so no caller could tell
# delivered from dropped. And nothing in `src/` or `scripts/` does `using HTTP`,
# so in practice EVERY alert took the dropped branch: a tripped circuit breaker
# paused the autopilot queue and told nobody, and the fleet idled until someone
# happened to read the journal. On a paid scheduler that is money.
#
# Two more layers made it invisible:
#   * the three `tick.jl` call sites passed no `status`, so they defaulted to
#     `:info` — the severity that is *supposed* to be quiet. A breaker trip and a
#     chatter message were indistinguishable at the notifier.
#   * the extension's colour map knows `:warning`; a caller writing `:warn` got
#     the default blue with no complaint. Writer and reader holding different
#     vocabularies with no declaration between them — the same shape as the
#     divergence-kill keys and the `stderr.log` path, both fixed today.
#
# So this gate checks the whole chain: the verdict exists, it is `true` only on a
# real POST, an undelivered non-quiet alert is loud, the callers declare their
# real severity, and the two sides share one vocabulary.
#
# ORDERING IS LOAD-BEARING. The positive control installs the typed method the
# extension installs, and Julia has no clean way to take it back, so it runs
# LAST. Everything asserting `false` runs before it.

const _TICK = normpath(joinpath(@__DIR__, "..", "..", "src", "workflow",
    "autopilot", "tick.jl"))
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

    # The callers must declare their real severity. This is where the defect
    # actually bit: the notifier could have been perfect and a breaker trip sent
    # at `:info` would still have been silent.
    @testset "autopilot alerts carry their severity" begin
        code = codelines(_TICK)
        calls = findall(l -> occursin("notify_slack(", l), code)
        @test !isempty(calls)
        for i in calls
            window = join(code[i:min(length(code), i + 5)], " ")
            @test occursin("status=:error", window) ||
                occursin("status=:warning", window)
        end
        # the breaker trip specifically — the alert that pauses the whole queue
        bt = findall(l -> occursin("breaker", l) && occursin("tripped", l), code)
        @test !isempty(bt)
        @test any(
            i -> occursin("status=:error",
                join(code[i:min(length(code), i + 5)], " ")), bt)
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
