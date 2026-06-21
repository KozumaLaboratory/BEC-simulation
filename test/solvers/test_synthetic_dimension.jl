using SpinorBEC, Test

@testset "synthetic dimension observables" begin
    grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
    F = 1
    D = 2F + 1
    n_pts = grid.config.n_points
    # Build a uniform polar spinor: only m=0 populated.
    psi = zeros(ComplexF64, n_pts..., D)
    psi[:, :, :, 2] .= 1.0  # m=0 component
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))

    # currents: zero on every bond (no off-diagonal phase coherence)
    j = synthetic_axis_current(psi, grid)
    @test length(j) == D - 1
    @test all(abs.(j) .< 1e-10)

    # IPR length: fully localised on m=0 → ξ = 1
    ξ = synthetic_localization_length(psi, grid)
    @test isapprox(ξ, 1.0; atol=1e-8)

    # Dispersion: shape and axis bookkeeping
    d = synthetic_dim_dispersion(psi, grid; axis=1)
    @test size(d.spectrum) == (n_pts[1], D)
    @test length(d.k_real) == n_pts[1]
    @test length(d.k_synth) == D

    # Now distribute equally → IPR should approach D
    psi_uniform = zeros(ComplexF64, n_pts..., D)
    psi_uniform .= 1.0
    psi_uniform ./= sqrt(sum(abs2, psi_uniform) * cell_volume(grid))
    ξu = synthetic_localization_length(psi_uniform, grid)
    @test isapprox(ξu, D; atol=1e-6)
end

@testset "synthetic_axis_current closed form" begin
    # J_c = -2 Im(ψ_{c+1}^* ψ_c) ∫dV. A uniform field fills every voxel, so
    # the integral is the per-voxel value × prod(box_size).
    grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
    V = prod(grid.config.box_size)
    a, b = 0.6, 0.5
    for χ in (0.0, π / 6, π / 2, π)
        psi = zeros(ComplexF64, 8, 8, 3)
        psi[:, :, 1] .= a
        psi[:, :, 2] .= b * cis(χ)
        J = synthetic_axis_current(psi, grid)
        @test isapprox(J[1], 2 * a * b * V * sin(χ); atol=1e-9)
        @test abs(J[2]) < 1e-9          # ψ_3 = 0 ⇒ J_2 = 0
    end
end

@testset "synthetic_dim_dispersion real-axis peak" begin
    # A single-component plane wave e^{ik₀x} is a delta at k₀ along the real
    # axis (flat along the synthetic axis). The dispersion's real-k peak,
    # collapsed over the synthetic axis, must land on k₀.
    N = 16
    L = 8.0
    grid = make_grid(GridConfig((N,), (L,)))
    k0 = (2π / L) * 3
    psi = zeros(ComplexF64, N, 3)
    for i in 1:N
        psi[i, 2] = cis(k0 * grid.x[1][i])
    end
    d = synthetic_dim_dispersion(psi, grid; axis=1)
    kpeak = d.k_real[argmax(vec(sum(d.spectrum; dims=2)))]
    @test isapprox(abs(kpeak), abs(k0); rtol=1e-6)
end
