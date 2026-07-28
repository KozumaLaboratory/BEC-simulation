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

    @testset "f_s_leggett appears only for box-spanning states" begin
        # The default fixture puts all the weight in one voxel — a maximally
        # disconnected "cloud". f_s would be 0 by geometry, so the key must be
        # absent rather than a zero a scan could read as signal.
        s = run_scalar_summary(_summary_fixture())
        @test !haskey(s, "f_s_leggett")
        @test !any(startswith.(s["extraction_error"], "f_s_leggett"))  # absent ≠ error

        # A uniform state spans the box and is fully superfluid on every axis.
        grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
        atom = AtomSpecies("test", 1.0e-26, 1, 0.0, 0.0, 0.0)
        psi = zeros(ComplexF64, 8, 8, 3)
        psi[:, :, 1] .= 1.0 / 8
        r = RunResult("/tmp/fake.jld2", psi, grid, atom, InteractionParams(Dict(0 => 1.0)))
        s = run_scalar_summary(r)
        @test haskey(s, "f_s_leggett")
        @test length(s["f_s_leggett"]) == 2
        @test all(≈(1.0; atol=1e-12), s["f_s_leggett"])

        # Modulated along x only: axis 1 impeded by √(1−A²), axis 2 free.
        A = 0.6
        kx = 2π / 4.0
        psi_m = zeros(ComplexF64, 8, 8, 3)
        for (i, x) in enumerate(grid.x[1])
            psi_m[i, :, 1] .= sqrt(1.0 + A * cos(kx * x)) / 8
        end
        s = run_scalar_summary(
            RunResult("/tmp/fake.jld2", psi_m, grid, atom, InteractionParams(Dict(0 => 1.0)))
        )
        @test s["f_s_leggett"][1] ≈ sqrt(1 - A^2) rtol = 1e-2
        @test s["f_s_leggett"][2] ≈ 1.0 atol = 1e-12
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
    @testset "provenance stamp: commit, dirty flag, and honest absence" begin
        mktempdir() do dir
            jld = joinpath(dir, "point_001.jld2")
            jldopen(jld, "w") do f
                local p = zeros(ComplexF64, 8, 8, 3)
                p[1, 1, 1] = 1.0 + 0im
                f["psi"] = p
                f["grid_n_points"] = [8, 8]
                f["grid_box_size"] = [4.0, 4.0]
                f["energy"] = -6.0
            end
            write_run_summary(dir, jld; source="finish_hook")
            s = JSON.parsefile(joinpath(dir, SpinorBEC.RUN_SUMMARY_FILENAME))
            # The repo this test runs in is a git checkout, so the stamp is there.
            @test haskey(s, "_repo_commit")
            c = s["_repo_commit"]
            @test occursin(r"^[0-9a-f]{40}(-dirty)?$", c)

            pr = summary_provenance(dir)
            @test pr.stamped
            @test length(pr.commit) == 40
            @test pr.dirty == endswith(c, "-dirty")
            @test pr.extractor_version == SpinorBEC.RUN_SUMMARY_EXTRACTOR_VERSION
        end
    end

    @testset "provenance of an unstamped or missing summary is not 'current'" begin
        # A summary written before stamping cannot be retro-dated. The query must
        # say so rather than imply the run matches HEAD — that distinction is the
        # whole point of the field.
        mktempdir() do dir
            @test summary_provenance(dir).stamped == false        # no file at all
            @test summary_provenance(dir).commit === nothing

            open(joinpath(dir, SpinorBEC.RUN_SUMMARY_FILENAME), "w") do io
                JSON.print(io, Dict("energy" => -1.0, "_extractor_version" => "2"), 2)
            end
            pr = summary_provenance(dir)
            @test pr.stamped == false
            @test pr.commit === nothing
            @test pr.extractor_version == "2"                     # still readable
        end
        # Corrupt JSON must not throw out of a triage loop.
        mktempdir() do dir
            write(joinpath(dir, SpinorBEC.RUN_SUMMARY_FILENAME), "{not json")
            @test summary_provenance(dir).stamped == false
        end
    end
end
