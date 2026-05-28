using Test
using SpinorBEC
using JLD2
using JSON

# Synthetic RunResult by hand — same approach as test_run_result.jl.
function _summary_fixture(; F::Int=1, n_pts::NTuple{D, Int}=(8, 8),
    dynamics=nothing, metadata=Dict{String, Any}()) where {D}
    box = ntuple(_ -> 4.0, D)
    grid = make_grid(GridConfig(n_pts, box))
    atom = AtomSpecies("test", 1.0e-26, F, 0.0, 0.0, 0.0)
    psi = zeros(ComplexF64, n_pts..., 2F + 1)
    psi[1, 1, 1] = 1.0 + 0im   # all weight in the m=+F component
    ip = InteractionParams(Dict(0 => 1.0))
    RunResult("/tmp/fake.jld2", psi, grid, atom, ip; dynamics, metadata)
end

@testset "run_scalar_summary" begin
    @testset "ground-state (no dynamics) happy path" begin
        r = _summary_fixture(;
            metadata=Dict{String, Any}("energy" => -6.0, "converged" => true))
        s = run_scalar_summary(r)
        @test s["ndim"] == 2
        @test s["F"] == 1
        @test s["n_points"] == [8, 8]
        @test s["energy"] == -6.0
        @test s["converged"] === true
        @test s["norm"] ≈ 1.0
        @test haskey(s, "Mz")
        @test haskey(s, "populations") && length(s["populations"]) == 3
        @test isapprox(sum(s["populations"]), 1.0; atol=1e-9)
        # No dynamics → no drift keys, clean extraction.
        @test !haskey(s, "norm_rel_drift")
        @test isempty(s["extraction_error"])
    end

    @testset "missing metadata → field absent, not silent — never throws" begin
        r = _summary_fixture()  # no energy/converged, no dynamics
        s = run_scalar_summary(r)
        @test !haskey(s, "converged")   # absent (nothing) = not an error
        @test !haskey(s, "energy")      # no metadata/e_decomp/dynamics
        @test any(startswith.(s["extraction_error"], "energy"))  # but recorded
        # psi-derived core still present despite the gap.
        @test haskey(s, "norm") && haskey(s, "Mz") && haskey(s, "populations")
    end

    @testset "with dynamics → drift keys present" begin
        dyn = DynamicsTimeSeries([0.0, 0.5, 1.0], [1.0, 1.0, 0.99],
            [-6.0, -5.9, -5.8], [-6.0, -5.95, -5.9])
        r = _summary_fixture(; dynamics=dyn,
            metadata=Dict{String, Any}("energy" => -5.8, "converged" => true))
        s = run_scalar_summary(r)
        @test haskey(s, "norm_rel_drift")
        @test haskey(s, "energy_rel_drift")
        @test haskey(s, "Fz_drift")
        @test s["norm_rel_drift"] >= 0
        @test isempty(s["extraction_error"])
    end

    @testset "write_run_summary: real jld2 round-trip" begin
        mktempdir() do dir
            jld = joinpath(dir, "point_001.jld2")
            jldopen(jld, "w") do f
                local p = zeros(ComplexF64, 8, 8, 3)
                p[1, 1, 1] = 1.0 + 0im
                f["psi"] = p
                f["grid_n_points"] = [8, 8]
                f["grid_box_size"] = [4.0, 4.0]
                f["energy"] = -6.0
                f["converged"] = true
            end
            p = write_run_summary(dir, jld; source="finish_hook")
            @test isfile(p)
            s = JSON.parsefile(p)
            @test s["_source"] == "finish_hook"
            @test s["_extractor_version"] == SpinorBEC.RUN_SUMMARY_EXTRACTOR_VERSION
            @test s["energy"] == -6.0
            @test haskey(s, "Mz")
            @test isempty(s["extraction_error"])
        end
    end

    @testset "write_run_summary: missing/corrupt jld2 is non-fatal" begin
        mktempdir() do dir
            p = write_run_summary(dir, joinpath(dir, "nope.jld2"))
            @test isfile(p)   # partial summary still written
            s = JSON.parsefile(p)
            @test any(startswith.(String.(s["extraction_error"]), "open_result"))
        end
    end
end
