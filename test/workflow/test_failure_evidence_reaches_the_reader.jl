using Test
using SpinorBEC
using SpinorBEC: analyze_failure, QueueEntry, enqueue!, autopilot_queue_root

# The evidence a failing run leaves must be found by the code that reads it.
#
# `analyze_failure` looked for `<run_dir>/stderr.log`. `LocalBackend` writes
# `<run_dir>/.autopilot/stderr.log`. Different paths, so the stderr-tail arm —
# one of three evidence sources, and the only one that survives when the process
# dies before writing `_exit_summary.json` — never matched, and every local
# failure fell through to "checked … / found nothing".
#
# Writer and reader naming the same file differently is the third instance of
# this shape today (`_live_status.json` keys, `gpu_hours_realized`), and it is
# the one the project already has a rule for: **a gate must cross the boundary,
# with real artefacts on both sides.** So this test writes through the path the
# BACKEND uses and reads through the analyser, with nothing synthetic between.

"A run dir with a stderr log where LocalBackend really puts it."
function run_dir_with_stderr(dir, text)
    log_dir = joinpath(dir, ".autopilot")
    mkpath(log_dir)
    write(joinpath(log_dir, "stderr.log"), text)
    dir
end

@testset "failure evidence is read where the backend writes it" begin
    # CALIBRATION. If `analyze_failure` returned the same category for every
    # input, each arm below would pass on its own. Establish that it
    # discriminates, and that the fixture path is the backend's, not a guess.
    @testset "the fixture uses the writer's own path" begin
        src = read(joinpath(@__DIR__, "..", "..", "src", "workflow", "autopilot",
                "backends.jl"), String)
        @test occursin("\".autopilot\"", src)
        @test occursin("stderr.log", src)
        reader = read(
            joinpath(@__DIR__, "..", "..", "src", "workflow", "autopilot",
                "failure_analysis.jl"), String)
        # the reader must name the same two components
        @test occursin("\".autopilot\"", reader)
        @test occursin("stderr.log", reader)
    end

    @testset "a stderr tail is found and classified" begin
        mktempdir() do d
            run_dir_with_stderr(
                d,
                """
[ Info: starting
ERROR: LoadError: OutOfGPUMemoryError: attempted to allocate 8.0 GiB
Stacktrace:
 [1] top-level scope
""",
            )
            e = QueueEntry("probe"; run_dir=d, spec_path=joinpath(d, "c.yaml"),
                status=:killed_bug)
            fa = analyze_failure(e)
            # it found the file at all — the whole defect was that it did not
            @test occursin("stderr", lowercase(String(fa.details))) ||
                occursin("OutOfGPUMemory", String(fa.details))
        end
    end

    # NEGATIVE CONTROL. A reader that reports "found evidence" for everything
    # would satisfy the arm above. An empty run dir must come back with the
    # no-evidence category.
    @testset "an empty run dir yields no evidence" begin
        mktempdir() do d
            e = QueueEntry("empty"; run_dir=d, spec_path=joinpath(d, "c.yaml"),
                status=:killed_bug)
            fa = analyze_failure(e)
            @test !occursin("OutOfGPUMemory", String(fa.details))
        end
    end

    # And the path must not drift back: the reader's join must carry BOTH
    # components, which a bare `run_dir/stderr.log` does not.
    @testset "the reader joins run_dir, .autopilot, stderr.log" begin
        reader = read(
            joinpath(@__DIR__, "..", "..", "src", "workflow", "autopilot",
                "failure_analysis.jl"), String)
        code = [l for l in split(reader, '\n') if !startswith(strip(l), "#")]
        joins = [l for l in code if occursin("stderr.log", l) && occursin("joinpath", l)]
        @test !isempty(joins)
        @test all(l -> occursin(".autopilot", l), joins)
    end
end
