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

@testset "scalar_egpe free 3D-HO ground state (virial split)" begin
    # Non-interacting ground state of V=½r² in 3D: E=3ω/2=1.5 with the
    # virial split E_kin=E_trap=0.75. A missing 1/N_pts FFT-Parseval factor
    # would shift only E_kin (E_trap is computed in real space), so the
    # equality of the two halves is the discriminator.
    n = 40
    L = 16.0
    grid = SpinorBEC.make_grid(GridConfig((n, n, n), (L, L, L)))
    V = [
        0.5 * (grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2 + grid.x[3][I[3]]^2)
        for I in CartesianIndices((n, n, n))
    ]
    ws = SpinorBEC.make_scalar_ws(grid, V; g_contact=0.0, c_dd=0.0, F=6.0)
    for I in CartesianIndices(ws.psi)
        r2 = grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2 + grid.x[3][I[3]]^2
        ws.psi[I] = exp(-r2 / (2 * 1.7^2))
    end
    SpinorBEC.normalize_scalar!(ws)
    Bhat = SVector{3, Float64}(0.0, 0.0, 1.0)
    SpinorBEC.find_ground_state_scalar!(ws, 3000, 0.005; B_hat=Bhat)
    e = SpinorBEC.scalar_energies(ws, Bhat)
    @test isapprox(e[1], 0.75; atol=2e-2)    # E_kin
    @test isapprox(e[2], 0.75; atol=2e-2)    # E_trap
    @test isapprox(e[5], 1.5; atol=2e-2)     # total
end

@testset "scalar_egpe energy ↔ Hψ FD identity (contact + DDI)" begin
    # Sharp deterministic check: the central difference of E_total along a
    # fixed δ equals the GP directional derivative 2·Re⟨δ|Hψ⟩·dV, with Hψ
    # built from the SAME pieces the propagator uses. Exercises the contact
    # AND dipolar nonlinear terms (the ½'s in g|ψ|⁴/2 and ρV_dd/2 cancel the
    # modulus-derivative 2). g=c_dd≠0 so the interaction terms are live.
    n = 16
    L = 8.0
    grid = SpinorBEC.make_grid(GridConfig((n, n, n), (L, L, L)))
    V = [
        0.5 * (grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2 + grid.x[3][I[3]]^2)
        for I in CartesianIndices((n, n, n))
    ]
    ws = SpinorBEC.make_scalar_ws(grid, V; g_contact=5.0, c_dd=1.0, F=6.0)
    dV = prod(grid.dx)
    Bhat = SVector{3, Float64}(0.0, 0.0, 1.0)

    base = [
        cis(0.3i - 0.2j + 0.1k) * exp(-0.05 * ((i - 8)^2 + (j - 8)^2 + (k - 8)^2))
        for i in 1:n, j in 1:n, k in 1:n
    ]
    δ = [(0.7 + 0.3i - 0.2j + 0.4k) + im * (0.1i + 0.5j - 0.3k)
         for i in 1:n, j in 1:n, k in 1:n]
    δ ./= sqrt(sum(abs2, δ))

    Eval(ψ) = begin
        copyto!(ws.psi, ψ)
        SpinorBEC.compute_tilted_dipole_potential!(ws, Bhat)
        ws.rho .= abs2.(ws.psi)                 # scalar_energies reads ws.rho
        SpinorBEC.scalar_energies(ws, Bhat)[5]
    end

    copyto!(ws.psi, base)
    ws.rho .= abs2.(ws.psi)
    SpinorBEC.compute_tilted_dipole_potential!(ws, Bhat)
    kin = copy(ws.psi)
    ws.fft_fwd * kin
    kin .*= 0.5 .* ws.grid.k_squared
    ws.fft_inv * kin
    Hψ = kin .+ (ws.V_trap .+ ws.g_contact .* abs2.(ws.psi) .+ ws.V_dd) .* ws.psi
    inner = 2 * real(sum(conj.(δ) .* Hψ)) * dV

    ε = 1e-6
    fd = (Eval(base .+ ε .* δ) - Eval(base .- ε .* δ)) / (2ε)
    @test isapprox(fd, inner; rtol=1e-3)
end
