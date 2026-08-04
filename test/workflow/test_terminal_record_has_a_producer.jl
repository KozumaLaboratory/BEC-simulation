using Test
using SpinorBEC
using SpinorBEC: EXIT_SUMMARY_FILENAME, _read_exit_summary

# Every file the autopilot READS must be a file something WRITES.
#
# `outcome.toml` had five readers and no producer. The only writer in `src/` was
# a dry-run synthetic whose own comment — "Real runs overwrite this file at
# process exit" — was false: `run_pipeline` writes `_exit_summary.json`.
#
# It was not inert. `run_dir` is content-addressed, the dry run wrote
# `terminal = "done"` into it, `collect!` does not write the file and the rsync
# collect carries no `--delete`. So a LIVE run of the same spec whose job left
# `qstat` for any reason found the stale file and was reported `:done` — a
# crashed job read as successfully completed, then credited to its recipe's
# trust store.
#
# This gate is at the level of the NAME, not of any one call site, because the
# defect was a name outliving its writer.

const _AUTOPILOT_SRC =
    let root = normpath(joinpath(@__DIR__, "..", "..")),
        dir = joinpath(root, "src", "workflow", "autopilot")

        [joinpath(dir, f) for f in readdir(dir) if endswith(f, ".jl")]
    end

@testset "the terminal record has a producer" begin
    @testset "the phantom name is gone from code" begin
        # Comments may narrate the history — that is how the reason survives —
        # but no CODE may name it. Strip comments before looking.
        # Strip BOTH `#` comments and `"""` docstrings. The first version of
        # this arm stripped only `#` and then flagged the docstring that
        # explains the removal — the gate's own instrument reading prose as
        # code.
        function code_lines(path)
            out = Tuple{Int, String}[]
            in_doc = false
            for (i, line) in enumerate(eachline(path))
                n = count(!isnothing, eachmatch(r"\"\"\"", line))
                if in_doc
                    isodd(n) && (in_doc = false)
                    continue
                elseif n > 0
                    in_doc = isodd(n)
                    continue
                end
                push!(out, (i, split(line, '#')[1]))
            end
            out
        end
        offenders = String[]
        for f in _AUTOPILOT_SRC, (i, code) in code_lines(f)
            (occursin("outcome.toml", code) || occursin("OUTCOME_FILENAME", code)) &&
                push!(offenders, "$(basename(f)):$i  $(strip(code))")
        end
        isempty(offenders) || println("  still naming the phantom in CODE:\n    ",
            join(offenders, "\n    "))
        @test offenders == String[]

        # POSITIVE CONTROL on the scanner: it must still SEE a real occurrence,
        # or "no offenders" means "the scanner is blind".
        mktempdir() do d
            probe = joinpath(d, "probe.jl")
            write(probe, "x = 1\np = joinpath(dir, OUTCOME_FILENAME)\n")
            @test any(occursin("OUTCOME_FILENAME", c) for (_, c) in code_lines(probe))
        end
    end

    @testset "the name it was replaced by IS written by the pipeline" begin
        # The whole point: this one has a producer. Assert it at the writer.
        runner = normpath(
            joinpath(@__DIR__, "..", "..",
                "src", "workflow", "experiments", "pipeline", "runner.jl"),
        )
        src = read(runner, String)
        @test EXIT_SUMMARY_FILENAME == "_exit_summary.json"
        @test occursin(EXIT_SUMMARY_FILENAME, src)
        # …and the two Booleans the classifiers now depend on are set there from
        # the real exception, not defaulted.
        @test occursin("nan_encountered=_is_nan_error", replace(src, " " => ""))
        @test occursin("oom_killed=_is_oom_error", replace(src, " " => ""))
    end

    @testset "absence returns nothing, never an empty verdict" begin
        # An empty Dict is how a missing record becomes a healthy answer at the
        # call site. `_read_exit_summary` must distinguish absent from empty.
        mktempdir() do d
            e = (run_dir=d,)
            @test _read_exit_summary(e) === nothing
            write(joinpath(d, EXIT_SUMMARY_FILENAME), "{ not json")
            @test _read_exit_summary(e) === nothing        # unreadable is absent
            write(joinpath(d, EXIT_SUMMARY_FILENAME),
                """{"completed": true, "oom_killed": false, "nan_encountered": false}""")
            got = _read_exit_summary(e)
            @test got isa AbstractDict
            @test got["completed"] === true
        end
    end

    @testset "the OOM route needs no string matching" begin
        # This is what made the escalation reachable. `classify_failure` had only
        # a free-text arm matching SLURM's vocabulary, while
        # `backend_failure_reason(::UGEBackend)` emits qacct's — two sets that do
        # not intersect, with nothing normalising between them, so an OOM'd
        # TSUBAME job re-queued at the same memory class until its retry budget
        # ran out.
        @test classify_failure(Dict{String, Any}("oom_killed" => true), "") ===
            SpinorBEC.RESOURCE_PERMANENT
        # POSITIVE CONTROL: the Boolean must be what decides it, not the empty
        # backend string, which on its own means UNKNOWN.
        @test classify_failure(Dict{String, Any}("oom_killed" => false), "") ===
            SpinorBEC.UNKNOWN_CLASS
        # …and a REAL UGE reason string still classifies, through the Boolean,
        # where the regex alone never could.
        uge = "failed=37 : qmaster enforced h_rt, h_cpu, or h_vmem limit exit_status=137"
        @test classify_failure(Dict{String, Any}(), uge) === SpinorBEC.UNKNOWN_CLASS
        @test classify_failure(Dict{String, Any}("oom_killed" => true), uge) ===
            SpinorBEC.RESOURCE_PERMANENT
    end
end
