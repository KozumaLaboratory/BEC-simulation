using Test
using SpinorBEC
using JSON

# `summary.json` is the file every document, figure and claim in this repository
# actually cites. Until 2026-08-02 it recorded nothing about what produced it.
#
# Measured on the 226 stored run directories that hold a result:
#
#   * not one summary carried a commit, a config hash, or a Julia version —
#     the only meta keys were `_extracted_at`, `_extractor_version` and
#     `_source`, all written by the backfill script, not by the run;
#   * only 20 of the 226 had ANY file under version control. `runs/**/*.jld2`
#     and `runs/**/summary.json` are gitignored by design, which is fine — but
#     the `config.yaml` beside them is not ignored, and for 206 of them it was
#     simply never committed.
#
# So a cited number could be neither re-derived nor attributed: no input in
# git, no output in git, and no statement of which code produced it. The jld2
# has carried an `env/` block since the CAS reuse check needed one
# (`_assert_point_provenance` refuses a cached point from a different commit);
# the summary just never got it.
#
# This gate is the cheap half — it cannot make a run reproducible, only make it
# say what it was. The other half is committing the config, which is a decision
# about 206 directories and not something a test can assert.

@testset "summary.json records what produced it" begin
    payload = Dict{Symbol, Any}(:ground_state_energy => 1.25, :converged => true)

    mktempdir() do dir
        out = joinpath(dir, "summary.json")
        SpinorBEC._analyze_summary_json(
            nothing, nothing, nothing,
            Dict{String, Any}("path" => out, "extras" => Dict("note" => "gate")),
            nothing, payload,
        )
        s = JSON.parsefile(out)

        @testset "the provenance block is there" begin
            for k in ("_env_git_hash", "_env_git_dirty", "_env_julia_version",
                "_env_hostname", "_written_at")
                @test haskey(s, k)
            end
        end

        @testset "and it is not a stub" begin
            # Positive control. `_env_metadata` degrades to "unknown" when git
            # is unavailable, and a gate that only checks the KEY is satisfied
            # by that — which is the shape the summaries were already in.
            # The test suite runs inside the repository, so a real hash is
            # reachable and its absence means the wiring, not the environment.
            @test s["_env_git_hash"] != "unknown"
            @test length(s["_env_git_hash"]) >= 7
            @test s["_env_julia_version"] == string(VERSION)
        end

        @testset "results are not displaced by it" begin
            # The provenance keys are namespaced so a run observable called
            # `hostname` or `platform` cannot be silently overwritten.
            @test s["ground_state_energy"] == 1.25
            @test s["converged"] === true
            @test s["note"] == "gate"
            @test all(startswith(k, "_env_") for k in keys(s) if occursin("env", k))
        end
    end
end
