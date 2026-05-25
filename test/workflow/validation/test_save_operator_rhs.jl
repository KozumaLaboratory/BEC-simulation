# Phase 3 — save_operator_rhs round-trip tests.

using Test
using SpinorBEC
using JLD2

@testset "validation Phase-3 save_operator_rhs" begin
    function _fixture_with_hpsi(; out_path="/tmp/fixture.jld2")
        psi = zeros(ComplexF64, 8, 8, 3)
        psi[1, 1, 1] = 1.0
        hpsi = copy(psi) .* (-1.5 + 0im)
        atom = AtomSpecies("test_atom", 1.0e-26, 1, 0.0, 0.0, 0.0)
        ip = InteractionParams(Dict(0 => 5.0, 1 => -0.5, 4 => 0.1); c_lhy=0.0)
        grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
        RunResult(out_path, psi, grid, atom, ip;
            hpsi=hpsi,
            e_decomp=Dict("total" => -1.5, "kinetic" => 0.5, "trap" => -2.0),
            metadata=Dict{String, Any}("conventions" => ["test"]))
    end

    @testset "round-trip via open_result" begin
        r = _fixture_with_hpsi()
        out_dir = mktempdir()
        try
            art = save_operator_rhs(r, out_dir)
            @test isfile(art.jld2_path)
            @test isfile(art.manifest_path)
            @test length(art.sha256) == 64               # SHA-256 hex

            r2 = open_result(art.jld2_path)
            @test r2.atom.name == "test_atom"
            @test r2.atom.F == 1
            @test r2.psi == r.psi
            @test r2.hpsi == r.hpsi
            @test r2.interactions[0] == 5.0
            @test r2.interactions[1] == -0.5
            @test r2.interactions[4] == 0.1
            @test r2.e_decomp["total"] == -1.5
            @test r2.e_decomp["kinetic"] == 0.5
        finally
            rm(out_dir; recursive=true)
        end
    end

    @testset "MANIFEST contains expected fields" begin
        r = _fixture_with_hpsi()
        out_dir = mktempdir()
        try
            art = save_operator_rhs(r, out_dir)
            content = read(art.manifest_path, String)
            @test occursin("Operator-RHS export manifest", content)
            @test occursin("git commit", content)
            @test occursin("test_atom", content)
            @test occursin("Atom: test_atom (F=1)", content)
            @test occursin(art.sha256, content)
            @test occursin("OperatorRHSSpec", content)    # usage hint
        finally
            rm(out_dir; recursive=true)
        end
    end

    @testset "Missing Hψ → ArgumentError" begin
        psi = zeros(ComplexF64, 8, 8, 3);
        psi[1, 1, 1] = 1.0
        atom = AtomSpecies("test", 1e-26, 1, 0.0, 0.0, 0.0)
        ip = InteractionParams(Dict(0 => 1.0))
        grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
        r = RunResult("/tmp/x.jld2", psi, grid, atom, ip)
        @test r.hpsi === nothing
        out_dir = mktempdir()
        try
            @test_throws ArgumentError save_operator_rhs(r, out_dir)
        finally
            rm(out_dir; recursive=true)
        end
    end

    @testset "End-to-end: open → save → check via OperatorRHSSpec" begin
        # Build a synthetic exported jld2, open it twice (simulating
        # ours + theirs being identical), compare via check().
        r = _fixture_with_hpsi()
        out_a = mktempdir()
        out_b = mktempdir()
        try
            save_operator_rhs(r, out_a)
            save_operator_rhs(r, out_b)
            ra = open_result(joinpath(out_a, "operator_rhs.jld2"))
            rb = open_result(joinpath(out_b, "operator_rhs.jld2"))
            c = compare_runs(ra, rb; label_a="ours", label_b="theirs")
            spec = OperatorRHSSpec(; tol_hpsi=1e-14, tol_per_term_E=1e-14)
            res = check(spec, c)
            @test res.pass == true
            hp = first(p for p in res.details if p.first === :hpsi_rel_l2)
            @test hp.second.got == 0.0                  # bit-identical artefact
        finally
            rm(out_a; recursive=true)
            rm(out_b; recursive=true)
        end
    end
end
