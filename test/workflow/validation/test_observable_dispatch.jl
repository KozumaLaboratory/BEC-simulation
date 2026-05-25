# Phase 1 — Base.getproperty observable dispatch tests.
#
# Build synthetic RunResults with known time series, exercise the
# `<x>` / `<x>_t` / `<x>_drift` / `<x>_rel_drift` dispatch table,
# and verify error messages for missing / unknown observables.

using Test
using SpinorBEC

function _make_fixture_with_dynamics(;
    Fz_series=[-6.0, -5.95, -5.9, -5.85],
    Lz_series=[0.0, -0.025, -0.05, -0.075],
    norm_series=[1.0, 1.0 + 1e-13, 1.0 + 2e-13, 1.0 + 3e-13],
    energy_series=[-10.0, -10.0 + 1e-4, -10.0 + 2e-4, -10.0 + 3e-4],
)
    n = length(Fz_series)
    times = collect(range(0.0; stop=Float64(n - 1) * 0.5, length=n))
    dyn = DynamicsTimeSeries(times, norm_series, energy_series, Fz_series;
        Lz=Lz_series)
    psi = zeros(ComplexF64, 8, 8, 3)
    psi[1, 1, 1] = 1.0 + 0im
    atom = AtomSpecies("test", 1e-26, 1, 0.0, 0.0, 0.0)
    ip = InteractionParams(Dict(0 => 1.0))
    RunResult("/tmp/fixture.jld2", psi,
        make_grid(GridConfig((8, 8), (4.0, 4.0))), atom, ip;
        dynamics=dyn)
end

@testset "validation Phase-1 observable dispatch" begin
    @testset "Struct-field passthrough" begin
        r = _make_fixture_with_dynamics()
        @test r.path == "/tmp/fixture.jld2"
        @test r.atom.F == 1
        @test r.dynamics isa DynamicsTimeSeries
        @test r.interactions isa InteractionParams
    end

    @testset "Terminal scalar via plain name" begin
        r = _make_fixture_with_dynamics()
        @test r.norm == 1.0 + 3e-13
        @test r.energy ≈ -10.0 + 3e-4
        @test r.Fz == -5.85
        @test r.Lz == -0.075
        @test r.Jz ≈ -5.85 + (-0.075)
    end

    @testset "Time series via `_t` suffix" begin
        r = _make_fixture_with_dynamics()
        @test r.norm_t == [1.0, 1.0 + 1e-13, 1.0 + 2e-13, 1.0 + 3e-13]
        @test r.energy_t[1] ≈ -10.0
        @test r.Fz_t == [-6.0, -5.95, -5.9, -5.85]
        @test r.Lz_t == [0.0, -0.025, -0.05, -0.075]
        @test r.Jz_t == r.Fz_t .+ r.Lz_t
    end

    @testset "Drift via `_drift` suffix" begin
        r = _make_fixture_with_dynamics()
        # Use explicit atol for the sub-eps norm fixture — `≈`'s default
        # rtol·|a|=rtol·3e-13 is well below F64 epsilon scale.
        @test r.norm_drift ≈ 3e-13 atol=1e-15
        @test r.energy_drift ≈ 3e-4
        @test r.Fz_drift ≈ 0.15
        @test r.Lz_drift ≈ 0.075
        @test r.Jz_drift ≈ 0.075                 # Jz = Fz + Lz drift = 0.15-0.075
    end

    @testset "Relative drift via `_rel_drift` suffix" begin
        r = _make_fixture_with_dynamics()
        @test r.energy_rel_drift ≈ 3e-4 / 10.0   # |ΔE|/|E(0)|
        @test r.Fz_rel_drift ≈ 0.15 / 6.0
    end

    @testset "Missing dynamics throws informative error" begin
        psi = zeros(ComplexF64, 8, 8, 3)
        psi[1, 1, 1] = 1.0
        atom = AtomSpecies("test", 1e-26, 1, 0.0, 0.0, 0.0)
        ip = InteractionParams(Dict(0 => 1.0))
        r_nodyn = RunResult("/tmp/x.jld2", psi,
            make_grid(GridConfig((8, 8), (4.0, 4.0))), atom, ip)
        @test_throws ArgumentError r_nodyn.norm
        @test_throws ArgumentError r_nodyn.Fz_drift
    end

    @testset "Missing Lz column throws (when dynamics has no Lz)" begin
        # Build dynamics without Lz
        dyn = DynamicsTimeSeries([0.0, 1.0], [1.0, 1.0], [-1.0, -1.0],
            [-6.0, -5.9])
        psi = zeros(ComplexF64, 8, 8, 3);
        psi[1, 1, 1] = 1.0
        atom = AtomSpecies("test", 1e-26, 1, 0.0, 0.0, 0.0)
        ip = InteractionParams(Dict(0 => 1.0))
        r = RunResult("/tmp/x.jld2", psi,
            make_grid(GridConfig((8, 8), (4.0, 4.0))), atom, ip;
            dynamics=dyn)
        @test_throws ArgumentError r.Lz
        @test_throws ArgumentError r.Lz_drift
        # Jz falls back to Fz when Lz is absent (zero-fill)
        @test r.Jz == r.Fz                       # = -5.9 since Lz treated as 0
    end

    @testset "Unknown observable gives helpful message" begin
        r = _make_fixture_with_dynamics()
        @test_throws ArgumentError r.totally_unknown_thing
        @test_throws ArgumentError r.unknown_drift
    end

    @testset "propertynames lists dispatch table" begin
        r = _make_fixture_with_dynamics()
        names = propertynames(r)
        @test :norm in names
        @test :Fz_drift in names
        @test :energy_rel_drift in names
        @test :psi in names                      # struct field
        @test :Jz_t in names
    end
end
