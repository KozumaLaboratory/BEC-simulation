# Phase 5 — Base.show overload tests.
#
# Verify the multi-line text/plain forms render the load-bearing
# information (atom, grid, drift values, pass markers). We don't
# pin exact whitespace; we just check key tokens are present.

using Test
using SpinorBEC

function _fixture_for_show()
    times = [0.0, 0.5, 1.0]
    d = DynamicsTimeSeries(times, [1.0, 1.0, 1.0],
        [-967.0, -966.95, -966.92], [-6.0, -5.9, -5.85];
        Lz=[0.0, -0.05, -0.075])
    psi = zeros(ComplexF64, 8, 8, 3);
    psi[1, 1, 1] = 1.0
    atom = AtomSpecies("Test151", 2.5e-25, 1, 110e-10, 6.5e-23, 1.16)
    ip = InteractionParams(Dict(0 => 5.0, 1 => -0.1))
    RunResult("/tmp/foo.jld2", psi,
        make_grid(GridConfig((8, 8), (4.0, 4.0))), atom, ip;
        dynamics=d,
        e_decomp=Dict("total" => -966.92, "kinetic" => 0.5))
end

@testset "validation Phase-5 Base.show" begin
    @testset "RunResult plain show (one-line)" begin
        r = _fixture_for_show()
        s = sprint(show, r)
        @test occursin("RunResult", s)
        @test occursin("Test151", s)
        @test occursin("F=1", s)
    end

    @testset "RunResult MIME plain show (multi-line REPL)" begin
        r = _fixture_for_show()
        s = sprint((io, x) -> show(io, MIME"text/plain"(), x), r)
        @test occursin("RunResult", s)
        @test occursin("foo.jld2", s)
        @test occursin("Test151", s)
        @test occursin("dynamics", s)
        @test occursin("norm drift", s)
        @test occursin("energy drift", s)
        @test occursin("⟨F_z⟩ drift", s)
        @test occursin("E_total", s)
        # Number formatting
        @test occursin("8.00e-02", s) || occursin("8.0e-02", s)   # energy drift
    end

    @testset "RunResult without dynamics has 'no time series' hint" begin
        psi = zeros(ComplexF64, 8, 8, 3);
        psi[1, 1, 1] = 1.0
        atom = AtomSpecies("t", 1e-26, 1, 0.0, 0.0, 0.0)
        ip = InteractionParams(Dict(0 => 1.0))
        r = RunResult("/tmp/x.jld2", psi,
            make_grid(GridConfig((8, 8), (4.0, 4.0))), atom, ip)
        s = sprint((io, x) -> show(io, MIME"text/plain"(), x), r)
        @test occursin("no time series", s)
    end

    @testset "RunResult with Hψ shows Hψ L²" begin
        r0 = _fixture_for_show()
        hpsi = copy(r0.psi) .* (1.5 + 0im)
        r = RunResult(r0.path, r0.psi, r0.grid, r0.atom, r0.interactions;
            hpsi=hpsi, dynamics=r0.dynamics, e_decomp=r0.e_decomp)
        s = sprint((io, x) -> show(io, MIME"text/plain"(), x), r)
        @test occursin("Hψ |L²", s)
    end

    @testset "RunSweep plain show" begin
        rs = [_fixture_for_show() for _ in 1:3]
        sweep = RunSweep(rs, :grid => [24, 32, 48])
        s = sprint(show, sweep)
        @test occursin("RunSweep", s)
        @test occursin("3 runs", s)
        @test occursin("grid", s)
    end

    @testset "RunSweep MIME plain show" begin
        rs = [_fixture_for_show() for _ in 1:3]
        sweep = RunSweep(rs, :grid => [24, 32, 48])
        s = sprint((io, x) -> show(io, MIME"text/plain"(), x), sweep)
        @test occursin("vary grid", s)
        @test occursin("24 =>", s)
        @test occursin("48 =>", s)
    end

    @testset "RunComparison plain + MIME show" begin
        r = _fixture_for_show()
        c = compare_runs(r, r; label_a="pre", label_b="post")
        s1 = sprint(show, c)
        @test occursin("RunComparison", s1)
        @test occursin("pre", s1)
        @test occursin("post", s1)
        s2 = sprint((io, x) -> show(io, MIME"text/plain"(), x), c)
        @test occursin("pre :", s2)
        @test occursin("post :", s2)
    end

    @testset "CheckResult MIME show (PASS)" begin
        r = _fixture_for_show()
        spec = ConservationSpec(norm_drift=1e-12, Fz_drift=1.0)
        result = check(spec, r)
        s = sprint((io, x) -> show(io, MIME"text/plain"(), x), result)
        @test occursin("✓", s)
        @test occursin("PASS", s)
        @test occursin("norm_drift", s)
        @test occursin("Fz_drift", s)
    end

    @testset "CheckResult MIME show (FAIL)" begin
        r = _fixture_for_show()
        # Fixture has Fz_drift = 0.15, so impossibly tight bound fails
        spec = ConservationSpec(Fz_drift=1e-6)
        result = check(spec, r)
        s = sprint((io, x) -> show(io, MIME"text/plain"(), x), result)
        @test occursin("✗", s)
        @test occursin("FAIL", s)
    end
end
