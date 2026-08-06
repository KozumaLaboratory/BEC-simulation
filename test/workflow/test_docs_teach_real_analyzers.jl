using Test
using SpinorBEC

# Every analyzer name a LIVE document teaches must be a real `_run_analyzer`
# branch.
#
# `docs/reference/yaml_schema_reference.md` listed `larmor_phase`,
# `berry_connection` and `population_history` under "`analyze` step … Names
# include:". None has ever been a branch — zero hits across `src/` — and
# `population_history` occurs nowhere else in the repository.
#
# The cost is not confusion. Analyzer names are never pre-validated: the runner
# maps them with a bare `Symbol(ak)` and `inspect_config` reports only
# `n_analyzers`, so the `ArgumentError` at `pipeline_analyzers.jl:128` fires
# **after ground_state and dynamics have already run**. A user who copies one of
# these three from the reference pays for the whole simulation and gets no
# `point_*.jld2`. On TSUBAME that is queue time bought and thrown away.
#
# This is the exact shape anko named at the start: a feature that was never
# there, left in the prose, and it breaks when you put it in a config.

const _ANALYZERS_SRC = normpath(
    joinpath(@__DIR__, "..", "..", "src", "workflow",
        "experiments", "pipeline", "pipeline_analyzers.jl"),
)
const _DOCS = normpath(joinpath(@__DIR__, "..", "..", "docs"))

"Every `name == :x` branch of `_run_analyzer`."
function analyzer_branches()
    src = read(_ANALYZERS_SRC, String)
    sort(unique(String[m.captures[1] for m in eachmatch(r"name ==+ :([a-z_0-9]+)", src)]))
end

is_frozen(p) = any(l -> occursin("FROZEN", l), Iterators.take(eachline(p), 6))

"""
Analyzer names taught by LIVE docs.

Only the bullet form under an `analyze`-step section, because prose elsewhere
legitimately names an analyzer while discussing it, and a `runs/` YAML example
is checked by a different gate. Narrow on purpose: the failure being prevented
is a reader copying a NAME from a list of names.
"""
function taught_names()
    out = Dict{String, Vector{String}}()
    for (root, _, files) in walkdir(_DOCS)
        occursin(joinpath("docs", "audit"), root) && continue
        for f in files
            endswith(f, ".md") || continue
            p = joinpath(root, f)
            is_frozen(p) && continue
            in_section = false
            for (n, l) in enumerate(eachline(p))
                if occursin(r"`analyze`|analyze step|analyze:", l)
                    in_section = true
                elseif startswith(l, "#") || startswith(l, "|")
                    in_section = false
                end
                in_section || continue
                startswith(strip(l), "- ") || continue
                # Only the NAMES, which lead the bullet before any "(params)" or
                # an em-dash prose tail. A first version took every backticked
                # word in the bullet and flagged `n_frames`, `frame_keys`,
                # `archive`, `leggett`, `both` — parameter names and enum values
                # discussing a REAL analyzer. Widening a prose-exclusion list to
                # absorb those would have been fixing the threshold; the
                # EXTRACTION was what was wrong.
                body = strip(l)[3:end]
                head = first(split(first(split(body, " (")), " —"))
                for m in eachmatch(r"`([a-z][a-z_0-9]{3,})`", head)
                    push!(get!(out, m.captures[1], String[]),
                        relpath(p, dirname(_DOCS)) * ":" * string(n))
                end
            end
        end
    end
    out
end

@testset "LIVE docs teach only real analyzer names" begin
    branches = analyzer_branches()
    taught = taught_names()

    # CALIBRATION. An extractor that finds no branches makes every taught name a
    # violation; one that finds no taught names makes the file vacuously green.
    # Both print like success. Assert each population, and assert a known-real
    # name is on both sides.
    @testset "the instrument sees both sides" begin
        @test length(branches) >= 20
        @test "tomography" in branches
        @test "energy_decomposition" in branches
        @test !isempty(taught)
        @test haskey(taught, "bogoliubov")
        @test "bogoliubov" in branches
    end

    @testset "every taught name is a branch" begin
        # Words that appear in these bullets as prose, not as analyzer names.
        prose = Set(["axis", "multi_step", "center", "radius", "n_k", "k_max",
            "name", "step", "true", "false", "none", "null"])
        bad = String[]
        for (name, where) in sort(collect(taught); by=first)
            (name in branches || name in prose) && continue
            push!(bad, "$name  (taught at $(join(where, ", ")))")
        end
        if !isempty(bad)
            println("\nLIVE docs teach analyzer names that are not `_run_analyzer` branches.")
            println("An unknown name throws at pipeline_analyzers.jl AFTER ground_state and")
            println("dynamics have run, so a reader who copies one pays for the whole run:")
            foreach(b -> println("  ", b), bad)
        end
        @test isempty(bad)
    end

    # The three that were there, by name, so a revert is loud rather than a
    # count going quietly from 0 to 3.
    @testset "the three removed 2026-08-06 stay gone" begin
        for dead in ("larmor_phase", "berry_connection", "population_history")
            @test !(dead in branches)
            @test !haskey(taught, dead)
        end
    end
end
