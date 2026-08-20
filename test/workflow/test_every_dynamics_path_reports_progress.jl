using Test
using SpinorBEC

include(joinpath(@__DIR__, "..", "helpers", "calibrated_scan.jl"))

# A long dynamics run must say how far along it is — on every path.
#
# On 2026-08-20 three 128³ jobs were killed by `execd enforced h_rt limit` after
# 7195 s, each having printed exactly one line: `Step 2/2:
# ScalarEGPEDynamicsStep`. Nothing in the log distinguished "90 % done" from
# "stuck at 10 %", so the runs could not be abandoned early and the `h_rt`
# mistake cost its full two hours three times over.
#
# TWO GATES, because the unit test alone would have passed while three of the
# four paths stayed silent:
#
#   1. TOTALITY — every `XDynamicsStep` branch in `_step_dispatch!` maps to a
#      progress label, and every label is actually constructed in the pipeline
#      source. Both directions, so neither a new unreported path nor a stale
#      label survives.
#
#   2. BEHAVIOUR — the reporter throttles on wall-clock, reports an ETA as a
#      CLOCK TIME, and goes quiet when asked. Asserted on `_progress_line`,
#      which is a pure function of (state, clock) precisely so this does not
#      need a minute of real time or a captured stdout.
#
# The liveness gate next door (`test_every_dynamics_path_reports_liveness.jl`)
# is the model, and the lesson taken from it is in its own comments: `_NO_LIVENESS`
# was introduced to DECLARE a gap and the gap was closed the next day, which is
# the argument for making the totality assertion first and the wiring second.

const _PIPELINE_DIR = normpath(
    joinpath(@__DIR__, "..", "..", "src", "workflow", "experiments", "pipeline"))
const _RUNNER_SRC = joinpath(_PIPELINE_DIR, "runner.jl")

# Step kind → the `label` its progress lines carry. This is the declaration; the
# gates below check it against the dispatcher on one side and the source on the
# other, so it cannot quietly become a description of only what is wired.
const _PROGRESS_LABELS = Dict{String, String}(
    "DynamicsStep" => "dynamics",
    "BinaryDynamicsStep" => "binary",
    "RotatingBasisDynamicsStep" => "rotating_basis",
    "ScalarEGPEDynamicsStep" => "scalar_egpe",
)

"Every `step isa XDynamicsStep` dispatch branch in `_step_dispatch!`."
function _dispatch_dynamics_kinds()
    src = read(_RUNNER_SRC, String)
    i = findfirst("function _step_dispatch!", src)
    i === nothing && return String[]
    tail = src[first(i):end]
    j = findfirst("\nend\n", tail)
    body = j === nothing ? tail : tail[1:first(j)]
    out = String[]
    for p in split(body, r"elseif step isa ")
        m = match(r"^([A-Za-z]*DynamicsStep)\b", p)
        m === nothing && continue
        branch = first(split(p, r"\n\s*elseif|\n\s*else\b"))
        # Same discriminator the liveness gate uses: a DISPATCH branch calls
        # `_run_step`. `_step_dispatch!` carries a second if-chain over the same
        # step types for results collection, and counting it once made a wired
        # path report as unwired.
        occursin("_run_step(", branch) || continue
        push!(out, m.captures[1])
    end
    unique(out)
end

"Every `_build_progress_reporter(\"label\", …)` call under `pipeline/`."
function _constructed_progress_labels()
    labels = String[]
    for (dir, _, files) in walkdir(_PIPELINE_DIR), f in files
        endswith(f, ".jl") || continue
        for m in eachmatch(r"_build_progress_reporter\(\s*\"([a-z_]+)\"",
            read(joinpath(dir, f), String))
            push!(labels, m.captures[1])
        end
    end
    labels
end

@testset "every dynamics path reports progress" begin
    @testset "the dispatcher and the source are both being read" begin
        # CALIBRATION. Two extractors, and an empty result from either would
        # make every assertion below vacuously true — the exact shape
        # `calibrated_scan` exists to refuse.
        kinds = _dispatch_dynamics_kinds()
        @test length(kinds) >= 4
        @test "DynamicsStep" in kinds
        @test "ScalarEGPEDynamicsStep" in kinds

        # And the label extractor must be able to say "none". Prove it on
        # synthetic text rather than on the tree, so the control does not die the
        # moment the tree is correct.
        probe(src) = [m.captures[1] for m in
                           eachmatch(r"_build_progress_reporter\(\s*\"([a-z_]+)\"", src)]
        @test probe("cb = _build_progress_reporter(\"fake_path\", n, d)") == ["fake_path"]
        @test isempty(probe("cb = _build_live_callback(node, path)"))
    end

    @testset "totality: dispatcher ⊆ labels ⊆ constructed" begin
        kinds = _dispatch_dynamics_kinds()
        constructed = _constructed_progress_labels()

        undeclared = [k for k in kinds if !haskey(_PROGRESS_LABELS, k)]
        if !isempty(undeclared)
            println("\nDynamics step kinds with no progress label declared:")
            foreach(k -> println("  ", k), undeclared)
            println("\nA long run on that path prints nothing between its opening")
            println("line and its exit. Add the kind to `_PROGRESS_LABELS` and")
            println("build a `ProgressReporter` in its handler.")
        end
        @test isempty(undeclared)

        # Stale entries are the other direction: a label for a kind the
        # dispatcher no longer has would make this file assert coverage of
        # something that does not run.
        @test all(k -> k in kinds, keys(_PROGRESS_LABELS))

        missing_ctor = [l for l in values(_PROGRESS_LABELS) if !(l in constructed)]
        if !isempty(missing_ctor)
            println("\nDeclared progress labels never constructed in `pipeline/`:")
            foreach(l -> println("  ", l), missing_ctor)
        end
        @test isempty(missing_ctor)

        # No orphans: every constructed label belongs to a declared kind. A
        # reporter built for a path nobody dispatches is a line nobody sees.
        @test all(l -> l in values(_PROGRESS_LABELS), constructed)
    end
end

@testset "a composed on_step hook is accepted where it is installed" begin
    # `_run_dynamics_with_optional_streaming!` declares
    # `extra_on_step::Union{Nothing, Function}`, so anything `_compose_callbacks`
    # can return must be `<: Function`. `ComposedCallbacks` was NOT, and the
    # defect stayed latent because two simultaneously-active callbacks needed
    # `live_monitor` on (a `run_yaml` with a run directory) AND an `sgpe:` /
    # `projected_gp:` / `photon_scattering:` block. Default-on progress makes two
    # callbacks the ordinary case, so this is pinned rather than rediscovered.
    f = (ws, step, times, energies) -> nothing
    g = (ws, step, times, energies) -> nothing
    @test SpinorBEC._compose_callbacks(nothing, nothing) === nothing
    @test SpinorBEC._compose_callbacks(f, nothing) isa Function
    @test SpinorBEC._compose_callbacks(f, g) isa Function
    @test SpinorBEC._compose_callbacks(f, g, ProgressReporter("p", 10, 1.0)) isa Function
    # The reporter alone is what `_compose_callbacks` returns when it is the only
    # live callback — the batch case, i.e. `live_monitor: false`.
    @test ProgressReporter("p", 10, 1.0) isa Function
    @test SpinorBEC._compose_callbacks(nothing, ProgressReporter("p", 10, 1.0)) isa Function
end

@testset "ProgressReporter behaviour" begin
    io = IOBuffer()

    @testset "throttles on wall-clock, not on step count" begin
        pr = ProgressReporter("dyn", 1000, 10.0; interval_s=1e6, io=io)
        # A million-second throttle: no step count may open it.
        @test !SpinorBEC._progress!(pr, 1, 0.01)
        @test !SpinorBEC._progress!(pr, 999, 9.99)
        @test isempty(String(take!(io)))

        open_now = ProgressReporter("dyn", 1000, 10.0; interval_s=0.0, io=io)
        @test SpinorBEC._progress!(open_now, 500, 5.0)
        @test occursin("[dyn]", String(take!(io)))
    end

    @testset "the line carries a fraction, a step count and a CLOCK ETA" begin
        pr = ProgressReporter("dyn", 1000, 10.0; interval_s=60.0, io=io)
        # 40 s of wall clock have passed at 40 % of the physical duration, so
        # the run has ~60 s left. Drive the clock explicitly rather than sleeping.
        now = pr.started[] + 40.0
        line = SpinorBEC._progress_line(pr, 400, 4.0, now)
        @test occursin("40.0 %", line)
        @test occursin("step 400/1000", line)
        @test occursin("elapsed 40s", line)
        @test occursin("left 1m00s", line)
        # ETA is a clock time — HH:MM:SS — because `h_rt` is compared against a
        # clock and "60 s left" has to be added to now() by hand first.
        @test occursin(r"ETA \d\d:\d\d:\d\d", line)
    end

    @testset "an unmeasurable ETA prints `--` rather than a fiction" begin
        pr = ProgressReporter("dyn", 10^6, 100.0; interval_s=60.0, io=io)
        line = SpinorBEC._progress_line(pr, 1, 1e-9, pr.started[] + 5.0)
        @test occursin("left --", line)
        @test occursin("ETA --", line)
    end

    @testset "progress is ON by default and silenced only by the env var" begin
        # The default matters more than the knob: #408 is about a run that was
        # silent, and an opt-in fix would have been opted out of by the same
        # person who set the wrong h_rt.
        withenv("SPINORBEC_PROGRESS" => nothing) do
            @test progress_enabled()
            @test SpinorBEC._build_progress_reporter("dyn", 10, 1.0) !== nothing
        end
        for off in PROGRESS_OFF_VALUES
            withenv("SPINORBEC_PROGRESS" => off) do
                @test !progress_enabled()
                @test SpinorBEC._build_progress_reporter("dyn", 10, 1.0) === nothing
            end
        end
        withenv("SPINORBEC_PROGRESS" => "QUIET") do
            @test !progress_enabled()   # case-insensitive
        end
        # A value that is not a recognised "off" leaves progress on rather than
        # silently disabling it — the failure this file exists to prevent is
        # silence, so an unparseable knob must fall to the loud side.
        withenv("SPINORBEC_PROGRESS" => "yes-please") do
            @test progress_enabled()
        end
    end

    @testset "a malformed interval falls back instead of throwing" begin
        # A job that has already started must not die because an env var was
        # mistyped; that trades a silent run for no run at all.
        for bad in ("", "abc", "-5", "0")
            withenv("SPINORBEC_PROGRESS_INTERVAL" => bad) do
                @test SpinorBEC._progress_interval() == 60.0
            end
        end
        withenv("SPINORBEC_PROGRESS_INTERVAL" => "5") do
            @test SpinorBEC._progress_interval() == 5.0
        end
    end

    @testset "durations are human, never a bare float of seconds" begin
        @test SpinorBEC._fmt_duration(42) == "42s"
        @test SpinorBEC._fmt_duration(90) == "1m30s"
        @test SpinorBEC._fmt_duration(3960) == "1h06m"
        @test SpinorBEC._fmt_duration(97200) == "1d03h"
        @test SpinorBEC._fmt_duration(NaN) == "--"
    end
end
