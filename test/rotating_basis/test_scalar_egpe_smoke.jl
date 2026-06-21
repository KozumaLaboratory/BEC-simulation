using Test
using SpinorBEC
using StaticArrays: SVector

@testset "scalar_egpe skeleton smoke" begin
    # 16³ Gaussian, static B̂ = ẑ, no DDI/LHY → free expansion of harmonic GS
    config = GridConfig((16, 16, 16), (10.0, 10.0, 10.0))
    grid = SpinorBEC.make_grid(config)

    # Harmonic trap V = (x²+y²+z²)/2
    V_trap = zeros(Float64, 16, 16, 16)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x*x + y*y + z*z)
    end

    ws = SpinorBEC.make_scalar_ws(
        grid, V_trap;
        g_contact=100.0, c_dd=0.0, F=6.0, gamma_lhy=0.0,
    )

    # Initial Gaussian centered at origin, normalized to 1
    σ = 1.0
    @inbounds for I in CartesianIndices(ws.psi)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        ws.psi[I] = exp(-(x*x + y*y + z*z) / (2*σ*σ))
    end
    n0 = SpinorBEC.scalar_norm(ws)
    ws.psi ./= sqrt(n0)
    @test SpinorBEC.scalar_norm(ws) ≈ 1.0 atol=1e-10

    # Constant B̂ = ẑ
    B_hat_z(t) = SVector{3, Float64}(0.0, 0.0, 1.0)

    # 10 RTP steps — norm preserved (T and V_diag are both unitary)
    SpinorBEC.evolve_scalar!(ws, 10, 0.01; B_hat_func=B_hat_z)
    @test SpinorBEC.scalar_norm(ws) ≈ 1.0 atol=1e-8

    # Centre stays near origin (symmetric initial state, symmetric trap)
    com = SpinorBEC.scalar_com(ws)
    @test all(abs(com[d]) < 1e-6 for d in 1:3)

    # Lz of a real Gaussian is zero
    Lz = SpinorBEC.scalar_Lz(ws)
    @test abs(Lz) < 1e-6

    # With DDI on, V_dd should be nonzero in interior
    ws2 = SpinorBEC.make_scalar_ws(
        grid, V_trap;
        g_contact=100.0, c_dd=50.0, F=6.0, gamma_lhy=0.0,
    )
    @inbounds for I in CartesianIndices(ws2.psi)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        ws2.psi[I] = exp(-(x*x + y*y + z*z) / (2*σ*σ))
    end
    ws2.psi ./= sqrt(SpinorBEC.scalar_norm(ws2))
    SpinorBEC._update_density!(ws2)
    SpinorBEC.compute_tilted_dipole_potential!(ws2, SVector{3, Float64}(0.0, 0.0, 1.0))
    @test maximum(abs, ws2.V_dd) > 1e-6   # nonzero somewhere
    @test ws2.V_dd[end ÷ 2 + 1, end ÷ 2 + 1, end ÷ 2 + 1] != ws2.V_dd[1, 1, 1]
end
