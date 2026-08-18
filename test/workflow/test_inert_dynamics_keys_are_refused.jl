using Test
using SpinorBEC
using SpinorBEC: _reject_inert_dynamics_keys, _parse_step, DYNAMICS_SCHEMA,
    ADAPTIVE_DT_SCHEMA

# A `dynamics:` knob the schema validates and no step reads.
#
# `adaptive_dt` declared five numeric fields with ranges, so
#
#     dynamics:
#       adaptive_dt: {dt_init: 1e-4, dt_min: 1e-6, dt_max: 1e-2, tol: 1e-8}
#
# validated cleanly and then ran at fixed dt. Nothing under `src/workflow`
# constructs `AdaptiveDtParams` or calls `run_simulation_yoshida!`; the adaptive
# runners are a Julia-API path. An accuracy knob accepted and discarded is worse
# than one that does not exist — the same defect as the rotating handler sizing
# `dt` for an integrator it would not run, fixed the same day.
#
# Unknown keys are only a `:warn`, which is right for a typo and too quiet here:
# the user spelled it correctly and did not get it.

@testset "inert dynamics keys are refused, not silently dropped" begin
    # CALIBRATION. A guard that threw on everything would satisfy the arm below
    # and break every run. Show it passes an ordinary dynamics block first.
    @testset "an ordinary block is accepted" begin
        @test _reject_inert_dynamics_keys(
            Dict("duration" => 1.0, "dt" => 1e-3, "save_every" => 10)) === nothing
        @test _reject_inert_dynamics_keys(Dict{String, Any}()) === nothing
    end

    @testset "adaptive_dt is refused with the real entry point named" begin
        err = try
            _reject_inert_dynamics_keys(Dict("adaptive_dt" => Dict("tol" => 1e-8)))
            nothing
        catch e
            e
        end
        @test err isa ArgumentError
        msg = sprint(showerror, err)
        # the message must say what to do instead, not only "no"
        @test occursin("run_simulation_yoshida!", msg)
        @test occursin("AdaptiveDtParams", msg)
        @test occursin("fixed dt", msg)
    end

    # THROUGH THE REAL CONSTRUCTION PATH. The arms above call the guard
    # directly, so deleting its call site in `_parse_step` left them green — a
    # canary said so. A guard that is defined and never invoked is the shape
    # this session keeps finding, so drive it from where a YAML step is built.
    @testset "the pipeline's own step builder refuses it" begin
        @test_throws ArgumentError _parse_step(
            Dict(:dynamics => Dict("duration" => 1.0,
                "adaptive_dt" => Dict("tol" => 1.0e-8))))
        # NEGATIVE CONTROL: the same builder must accept the block without it,
        # or the arm above would pass on a builder that rejects everything.
        @test _parse_step(Dict(:dynamics => Dict("duration" => 1.0))) !== nothing
        # and the sibling step kinds still build
        @test _parse_step(
            Dict(:dynamics => Dict("duration" => 1.0, "kind" => "binary"))) !== nothing
    end

    # The premise, checked rather than assumed: if some pipeline step ever DOES
    # read the block, this whole gate becomes wrong and must be deleted. Assert
    # the absence that justifies it.
    @testset "no pipeline step consumes the block" begin
        # CODE ONLY. A first version searched raw text and matched the guard's
        # own docstring, which names both symbols to explain why they are absent
        # — a scan hitting the prose that describes the thing rather than the
        # thing, for the fifth time this session. Strip `#` lines AND `\"\"\"`
        # blocks.
        function codeonly(txt)
            out, indoc = String[], false
            for l in split(txt, '\n')
                n = count(i -> true, findall("\"\"\"", l))
                if indoc
                    isodd(n) && (indoc = false)
                    continue
                end
                isodd(n) && (indoc=true; continue)
                startswith(strip(l), "#") || push!(out, l)
            end
            join(out, "\n")
        end

        root = normpath(joinpath(@__DIR__, "..", "..", "src", "workflow"))
        hits = String[]
        for (dir, _, files) in walkdir(root), f in files
            endswith(f, ".jl") || continue
            code = codeonly(read(joinpath(dir, f), String))
            (occursin("AdaptiveDtParams(", code) ||
             occursin("run_simulation_yoshida!(", code)) &&
                push!(hits, relpath(joinpath(dir, f), root))
        end
        # ONE expected hit: the guard's own ArgumentError names both symbols in
        # a string literal, which is real code, not prose. Stripping string
        # literals too would be re-implementing Julia's grammar in a regex — the
        # thing that already produced a wrong tier count in this session — so the
        # exclusion is named instead, and pinned at exactly one. A second file
        # appearing turns this red, which is the property that matters.
        expected = ["experiments/pipeline/runner.jl"]
        surprises = setdiff(hits, expected)
        isempty(surprises) || println("\n  a workflow file now reaches an adaptive runner: ",
            join(surprises, ", "), "\n  — wire `adaptive_dt` and delete this gate.")
        @test isempty(surprises)
        # and the known one must still be there: if the guard's message stops
        # naming the entry point, the user loses the remedy
        @test hits == expected

        # POSITIVE CONTROL for the scan: the same search must FIND the adaptive
        # runner where it does live, or an empty result means the walk is broken
        # rather than that nothing consumes the block.
        solvers = normpath(joinpath(@__DIR__, "..", "..", "src", "solvers"))
        found = String[]
        for (dir, _, files) in walkdir(solvers), f in files
            endswith(f, ".jl") || continue
            code = codeonly(read(joinpath(dir, f), String))
            occursin("AdaptiveDtParams", code) &&
                push!(found, relpath(joinpath(dir, f), solvers))
        end
        @test !isempty(found)
    end

    # And the schema still describes it, so `inspect_config` calls it refused
    # rather than guessing it is a misspelling of something else.
    @testset "the schema still knows the key" begin
        @test haskey(DYNAMICS_SCHEMA, "adaptive_dt")
        @test haskey(ADAPTIVE_DT_SCHEMA, "tol")
    end
end
