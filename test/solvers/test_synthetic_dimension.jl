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
