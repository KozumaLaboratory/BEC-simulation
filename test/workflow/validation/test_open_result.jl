# Phase 1 — open_result(path) tests.
#
# Writes synthetic jld2 files (mimicking the three canonical layouts:
# point_001.jld2, operator_rhs.jld2, save_state) and verifies
# open_result reconstructs RunResult correctly across schema variants.

using Test
using SpinorBEC
using JLD2

@testset "validation Phase-1 open_result" begin
    @testset "Missing file → ArgumentError" begin
        @test_throws ArgumentError open_result("/tmp/nonexistent_xyz_abc.jld2")
    end

    @testset "Minimal point_001.jld2 layout (no dynamics, no decomp)" begin
        path = tempname() * ".jld2"
        try
            psi = zeros(ComplexF64, 8, 8, 3)
            psi[1, 1, 1] = 1.0
            JLD2.jldopen(path, "w") do f
                f["psi"] = psi
                f["grid_n_points"] = [8, 8]
                f["grid_box_size"] = [4.0, 4.0]
                f["units/atom"] = "Rb87"
                f["units/N_atoms"] = 1000
                f["units/omega_ref_rad_s"] = 2π * 100.0
                f["converged"] = true
                f["energy"] = -1.5
            end
            r = open_result(path)
            @test r isa RunResult
            @test size(r.psi) == (8, 8, 3)
            # ATOM_REGISTRY uses lookup symbol :Rb87 but the stored
            # AtomSpecies.name field is "87Rb" (CODATA notation)
            @test r.atom.name == "87Rb"
            @test r.atom.F == 1
            @test r.dynamics === nothing
            @test isempty(r.e_decomp)
            @test r.metadata["energy"] == -1.5
            @test r.metadata["converged"] == true
        finally
            isfile(path) && rm(path)
        end
    end

    @testset "point_001.jld2 with dynamics" begin
        path = tempname() * ".jld2"
        try
            psi = zeros(ComplexF64, 8, 8, 3)
            psi[1, 1, 1] = 1.0
            JLD2.jldopen(path, "w") do f
                f["psi"] = psi
                f["grid_n_points"] = [8, 8]
                f["grid_box_size"] = [4.0, 4.0]
                f["units/atom"] = "Rb87"
                f["dynamics/times"] = [0.0, 0.5, 1.0]
                f["dynamics/norms"] = [1.0, 1.0, 1.0]
                f["dynamics/energies"] = [-1.5, -1.5, -1.5]
                f["dynamics/Fz"] = [1.0, 0.95, 0.9]
            end
            r = open_result(path)
            @test r.dynamics isa DynamicsTimeSeries
            @test r.dynamics.times == [0.0, 0.5, 1.0]
            @test r.dynamics.Fz == [1.0, 0.95, 0.9]
            @test r.dynamics.Lz === nothing
            @test r.Fz == 0.9
            @test r.Fz_drift ≈ 0.1
        finally
            isfile(path) && rm(path)
        end
    end

    @testset "Energy decomposition extracted" begin
        path = tempname() * ".jld2"
        try
            psi = zeros(ComplexF64, 8, 8, 3)
            psi[1, 1, 1] = 1.0
            JLD2.jldopen(path, "w") do f
                f["psi"] = psi
                f["grid_n_points"] = [8, 8]
                f["grid_box_size"] = [4.0, 4.0]
                f["units/atom"] = "Rb87"
                f["analyze/energy_decomposition/kinetic"] = 0.5
                f["analyze/energy_decomposition/trap"] = 1.0
                f["analyze/energy_decomposition/total"] = 1.5
            end
            r = open_result(path)
            @test r.e_decomp["kinetic"] == 0.5
            @test r.e_decomp["trap"] == 1.0
            @test r.e_decomp["total"] == 1.5
            @test length(r.e_decomp) == 3
        finally
            isfile(path) && rm(path)
        end
    end

    @testset "operator_rhs.jld2 layout (explicit interactions + Hpsi)" begin
        path = tempname() * ".jld2"
        try
            psi = zeros(ComplexF64, 8, 8, 3)
            psi[1, 1, 1] = 1.0
            Hpsi = copy(psi) .* (-1.5 + 0im)
            JLD2.jldopen(path, "w") do f
                f["psi"] = psi
                f["Hpsi"] = Hpsi
                f["grid_n_points"] = [8, 8]
                f["grid_box_size"] = [4.0, 4.0]
                f["units/atom"] = "Rb87"
                f["interactions_c0"] = 5.0
                f["interactions_c1"] = -0.5
                f["interactions_c_lhy"] = 0.0
                f["interactions_c_high_rank"] = Pair{Int, Float64}[]
                f["ddi_c_dd"] = 0.0
            end
            r = open_result(path)
            @test r.interactions[0] == 5.0
            @test r.interactions[1] == -0.5
            @test r.interactions.c_lhy == 0.0
        finally
            isfile(path) && rm(path)
        end
    end

    @testset "Unknown atom name → anonymous AtomSpecies fallback" begin
        path = tempname() * ".jld2"
        try
            psi = zeros(ComplexF64, 8, 8, 3)
            psi[1, 1, 1] = 1.0
            JLD2.jldopen(path, "w") do f
                f["psi"] = psi
                f["grid_n_points"] = [8, 8]
                f["grid_box_size"] = [4.0, 4.0]
                f["units/atom"] = "NotARealAtom123"
            end
            r = open_result(path)
            @test r.atom.name == "unknown"
            @test r.atom.F == 1
        finally
            isfile(path) && rm(path)
        end
    end
end
