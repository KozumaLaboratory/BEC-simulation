# Phase 2 — ConservationSpec / OperatorRHSSpec + check() dispatch tests.

using Test
using SpinorBEC

function _fixture_run(; norm_drift_factor=1e-13, fz_final=-5.85)
    times = [0.0, 0.5, 1.0]
    norms = [1.0, 1.0 + norm_drift_factor, 1.0 + 2norm_drift_factor]
    energies = [-10.0, -10.0 + 1e-4, -10.0 + 2e-4]
    Fz = [-6.0, (fz_final + -6.0) / 2, fz_final]
    Lz = [0.0, -(fz_final + 6) / 4, -(fz_final + 6) / 2]
    dyn = DynamicsTimeSeries(times, norms, energies, Fz; Lz=Lz)
    psi = zeros(ComplexF64, 8, 8, 3);
    psi[1, 1, 1] = 1.0
    atom = AtomSpecies("test", 1e-26, 1, 0.0, 0.0, 0.0)
    ip = InteractionParams(Dict(0 => 1.0))
    RunResult("/tmp/fixture.jld2", psi,
        make_grid(GridConfig((8, 8), (4.0, 4.0))), atom, ip;
        dynamics=dyn)
end

@testset "validation Phase-2 specs + check" begin
    @testset "ConservationSpec construction" begin
        spec = ConservationSpec(norm_drift=1e-12, Jz_drift=5e-2)
        @test spec.bounds[:norm_drift] == 1e-12
        @test spec.bounds[:Jz_drift] == 5e-2
        @test length(spec.bounds) == 2
    end

    @testset "OperatorRHSSpec defaults" begin
        spec = OperatorRHSSpec()
        @test spec.tol_hpsi == 1.0e-10
        @test spec.tol_per_term_E == 1.0e-10
        spec2 = OperatorRHSSpec(; tol_hpsi=1e-8)
        @test spec2.tol_hpsi == 1e-8
    end

    @testset "check(ConservationSpec, RunResult) — PASS" begin
        r = _fixture_run(; norm_drift_factor=1e-14)
        spec = ConservationSpec(norm_drift=1e-12, Fz_drift=1.0)
        result = check(spec, r)
        @test result isa CheckResult
        @test passed(result)
        @test length(result.details) == 2
        @test all(p.second.pass for p in result.details)
    end

    @testset "check(ConservationSpec, RunResult) — FAIL" begin
        r = _fixture_run(; norm_drift_factor=1e-3)   # large drift
        spec = ConservationSpec(norm_drift=1e-12)
        result = check(spec, r)
        @test !passed(result)
        d = result.details[1]
        @test d.first === :norm_drift
        @test d.second.pass == false
        @test d.second.got > d.second.bound
    end

    @testset "check(ConservationSpec, RunSweep)" begin
        r1 = _fixture_run(; norm_drift_factor=1e-14, fz_final=-5.95)
        r2 = _fixture_run(; norm_drift_factor=1e-14, fz_final=-5.85)
        r3 = _fixture_run(; norm_drift_factor=1e-3, fz_final=-5.85)  # fails
        sweep = RunSweep([r1, r2, r3], :case => [:a, :b, :c])
        spec = ConservationSpec(norm_drift=1e-12)
        results = check(spec, sweep)
        @test length(results) == 3
        @test passed(results[1])
        @test passed(results[2])
        @test !passed(results[3])
    end

    @testset "check(OperatorRHSSpec, RunComparison) — both have Hpsi" begin
        psi = zeros(ComplexF64, 8, 8, 3);
        psi[1, 1, 1] = 1.0
        hpsi_a = copy(psi) .* (-1.5 + 0im)
        hpsi_b = copy(psi) .* (-1.5 + 1.0e-12im)             # tiny diff
        atom = AtomSpecies("test", 1e-26, 1, 0.0, 0.0, 0.0)
        ip = InteractionParams(Dict(0 => 1.0))
        grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
        a = RunResult("/tmp/a.jld2", psi, grid, atom, ip;
            hpsi=hpsi_a,
            e_decomp=Dict("total" => -1.5, "kinetic" => 0.5))
        b = RunResult("/tmp/b.jld2", psi, grid, atom, ip;
            hpsi=hpsi_b,
            e_decomp=Dict("total" => -1.5, "kinetic" => 0.500000000001))
        c = compare_runs(a, b; label_a="ours", label_b="theirs")
        spec = OperatorRHSSpec(; tol_hpsi=1e-6, tol_per_term_E=1e-6)
        result = check(spec, c)
        @test passed(result)
        hp = first(p for p in result.details if p.first === :hpsi_rel_l2)
        @test hp.second.pass == true
        @test hp.second.got < 1e-6
    end

    @testset "check(OperatorRHSSpec, RunComparison) — Hpsi missing" begin
        psi = zeros(ComplexF64, 8, 8, 3);
        psi[1, 1, 1] = 1.0
        atom = AtomSpecies("test", 1e-26, 1, 0.0, 0.0, 0.0)
        ip = InteractionParams(Dict(0 => 1.0))
        grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
        a = RunResult("/tmp/a.jld2", psi, grid, atom, ip)
        b = RunResult("/tmp/b.jld2", psi, grid, atom, ip)
        c = compare_runs(a, b)
        result = check(OperatorRHSSpec(), c)
        @test !passed(result)
        @test any(p.first === :hpsi_missing for p in result.details)
    end

    @testset "sweep_runs(paths) constructs RunSweep from disk" begin
        # Use the in-memory fixture trick: save a few minimal jld2s, then sweep.
        using JLD2: jldopen
        paths = String[]
        try
            for i in 1:3
                path = tempname() * ".jld2"
                psi = zeros(ComplexF64, 8, 8, 3);
                psi[1, 1, 1] = 1.0
                jldopen(path, "w") do f
                    f["psi"] = psi
                    f["grid_n_points"] = [8, 8]
                    f["grid_box_size"] = [4.0, 4.0]
                    f["units/atom"] = "Rb87"
                end
                push!(paths, path)
            end
            sweep = sweep_runs(paths; vary=:grid => [24, 32, 48])
            @test length(sweep.runs) == 3
            @test sweep.varying.first === :grid
            @test sweep.varying.second == [24, 32, 48]
        finally
            for p in paths
                isfile(p) && rm(p)
            end
        end
    end

    @testset "sweep_runs length mismatch → ArgumentError" begin
        @test_throws ArgumentError sweep_runs(["/tmp/a", "/tmp/b"];
            vary=:grid => [1, 2, 3])
    end

    @testset "compare_runs is a trivial constructor" begin
        psi = zeros(ComplexF64, 8, 8, 3);
        psi[1, 1, 1] = 1.0
        atom = AtomSpecies("test", 1e-26, 1, 0.0, 0.0, 0.0)
        ip = InteractionParams(Dict(0 => 1.0))
        grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
        a = RunResult("/tmp/a.jld2", psi, grid, atom, ip)
        b = RunResult("/tmp/b.jld2", psi, grid, atom, ip)
        c = compare_runs(a, b; label_a="pre", label_b="post")
        @test c isa RunComparison
        @test c.label_a == "pre"
        @test c.label_b == "post"
    end
end
