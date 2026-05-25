# Phase 0 — RunResult / RunSweep / RunComparison construction tests.
#
# Operations (`open_result`, `sweep_runs`, ...) land in Phase 1+. Here
# we only verify the type contracts:
#   * field layout
#   * spinor-dim invariant (ψ last-axis size = 2F+1)
#   * grid-ndim invariant (psi rank = grid.D + 1)
#   * DynamicsTimeSeries length consistency
#   * RunSweep size match between `runs` and `varying.second`

using Test
using SpinorBEC

# Tiny shared fixture: build a synthetic RunResult by hand so we can
# exercise constructors without running a full pipeline.
function _make_fixture_run(; F::Int=1, n_pts::NTuple{D, Int}=(8, 8),
    path::String="/tmp/fake.jld2") where {D}
    box = ntuple(_ -> 4.0, D)
    grid = make_grid(GridConfig(n_pts, box))
    atom = AtomSpecies("test", 1.0e-26, F, 0.0, 0.0, 0.0)
    psi = zeros(ComplexF64, n_pts..., 2F + 1)
    psi[1, 1, 1] = 1.0 + 0im
    ip = InteractionParams(Dict(0 => 1.0, 1 => -0.1))
    RunResult(path, psi, grid, atom, ip)
end

@testset "validation Phase-0 types" begin
    @testset "DynamicsTimeSeries length contract" begin
        times = [0.0, 0.5, 1.0]
        @test DynamicsTimeSeries(times, [1.0, 1.0, 1.0], [-1.0, -1.0, -1.0],
            [-6.0, -5.9, -5.8]) isa DynamicsTimeSeries
        # Lz optional
        d = DynamicsTimeSeries(times, [1.0, 1.0, 1.0], [-1.0, -1.0, -1.0],
            [-6.0, -5.9, -5.8]; Lz=[0.0, -0.1, -0.2])
        @test d.Lz == [0.0, -0.1, -0.2]
        # Length mismatch
        @test_throws ArgumentError DynamicsTimeSeries(
            times, [1.0, 1.0], [-1.0, -1.0, -1.0], [-6.0, -5.9, -5.8])
    end

    @testset "RunResult construction + invariants" begin
        r = _make_fixture_run(; F=1, n_pts=(8, 8))
        @test r isa RunResult{3, 2}                  # 2D grid + spinor axis ⇒ rank 3
        @test size(r.psi) == (8, 8, 3)               # F=1 ⇒ D=3
        @test r.atom.F == 1
        @test r.dynamics === nothing
        @test isempty(r.e_decomp)

        # Spinor-dim invariant: 2F+1 ≠ ψ last axis ⇒ error
        bad_psi = zeros(ComplexF64, 8, 8, 5)         # 5 ≠ 2·1 + 1
        atom = AtomSpecies("test", 1e-26, 1, 0.0, 0.0, 0.0)
        ip = InteractionParams(Dict(0 => 1.0))
        @test_throws ArgumentError RunResult(
            "/tmp/x.jld2", bad_psi,
            make_grid(GridConfig((8, 8), (4.0, 4.0))), atom, ip,
        )

        # Grid-ndim invariant: ψ rank ≠ D+1 ⇒ error
        ip2 = InteractionParams(Dict(0 => 1.0))
        @test_throws ArgumentError RunResult(
            "/tmp/x.jld2",
            zeros(ComplexF64, 8, 8, 8, 3),          # rank 4
            make_grid(GridConfig((8, 8), (4.0, 4.0))),  # D=2 ⇒ expects rank 3
            atom, ip2,
        )
    end

    @testset "RunResult with dynamics + metadata" begin
        d = DynamicsTimeSeries([0.0, 1.0], [1.0, 1.0], [-1.0, -0.999],
            [-6.0, -5.95])
        psi = zeros(ComplexF64, 8, 8, 3)
        atom = AtomSpecies("test", 1e-26, 1, 0.0, 0.0, 0.0)
        ip = InteractionParams(Dict(0 => 1.0))
        r = RunResult("/tmp/x.jld2", psi,
            make_grid(GridConfig((8, 8), (4.0, 4.0))), atom, ip;
            dynamics=d,
            e_decomp=Dict("total" => -1.0),
            metadata=Dict{String, Any}("git_hash" => "abc123"),
        )
        @test r.dynamics === d
        @test r.e_decomp["total"] == -1.0
        @test r.metadata["git_hash"] == "abc123"
    end

    @testset "RunSweep size match" begin
        runs = [_make_fixture_run(; F=1, n_pts=(8, 8)),
            _make_fixture_run(; F=1, n_pts=(16, 16))]
        sweep = RunSweep(runs, :grid => [8, 16])
        @test length(sweep.runs) == 2
        @test sweep.varying.first === :grid
        @test sweep.varying.second == [8, 16]

        @test_throws ArgumentError RunSweep(runs, :grid => [8, 16, 32])
    end

    @testset "RunComparison construction + labels" begin
        a = _make_fixture_run(; F=1, n_pts=(8, 8), path="/tmp/a.jld2")
        b = _make_fixture_run(; F=1, n_pts=(8, 8), path="/tmp/b.jld2")
        c = RunComparison(a, b)
        @test c.label_a == "A"
        @test c.label_b == "B"
        @test c.a.path == "/tmp/a.jld2"

        c2 = RunComparison(a, b; label_a="pre-fix", label_b="post-fix")
        @test c2.label_a == "pre-fix"
        @test c2.label_b == "post-fix"
    end
end
