using Test
using SpinorBEC

@testset "extract_spin_snapshot" begin
    # Tiny F=1 setup to keep JIT cheap.
    grid = make_grid(GridConfig((8, 8, 8), (10.0, 10.0, 10.0)))
    atom = SpinorBEC.Na23  # F=1 species
    interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
    sim_params = SimParams(; dt=0.001, n_steps=0)

    sys = SpinSystem(atom.F)

    @testset "polar state: m_dist concentrated on m=0" begin
        psi = init_psi(grid, sys; state=:polar)
        ws = make_workspace(;
            grid=grid, atom=atom, interactions=interactions,
            sim_params=sim_params, psi_init=psi,
        )

        snap = extract_spin_snapshot(ws)
        @test length(snap.m_dist) == 3
        @test isapprox(snap.m_dist[2], 1.0; atol=1e-10)   # m=0 (mid)
        @test isapprox(snap.m_dist[1], 0.0; atol=1e-10)
        @test isapprox(snap.m_dist[3], 0.0; atol=1e-10)
        # Polar state has zero spin density everywhere.
        @test isapprox(snap.fx_total, 0.0; atol=1e-10)
        @test isapprox(snap.fy_total, 0.0; atol=1e-10)
        @test isapprox(snap.fz_total, 0.0; atol=1e-10)
        # No vorticity ⇒ Lz = 0.
        @test isapprox(snap.Lz, 0.0; atol=1e-8)
    end

    @testset "m=+F state: ⟨F_z⟩ = +F, m_dist[1] ≈ 1" begin
        psi = init_psi(grid, sys; state=:m_plus_F)
        ws = make_workspace(;
            grid=grid, atom=atom, interactions=interactions,
            sim_params=sim_params, psi_init=psi,
        )

        snap = extract_spin_snapshot(ws)
        @test isapprox(snap.m_dist[1], 1.0; atol=1e-10)   # m=+1 (F=1)
        @test isapprox(snap.fz_total, 1.0; atol=1e-10)     # ⟨F_z⟩ = +F = +1
        @test isapprox(snap.fx_total, 0.0; atol=1e-10)
        @test isapprox(snap.fy_total, 0.0; atol=1e-10)
    end
end
