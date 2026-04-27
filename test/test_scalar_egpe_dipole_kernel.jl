using Test
using SpinorBEC
using StaticArrays: SVector

@testset "tilted dipole kernel correctness" begin
    config = GridConfig((32, 32, 32), (12.0, 12.0, 12.0))
    grid = SpinorBEC.make_grid(config)

    V_trap = zeros(Float64, 32, 32, 32)
    ws = SpinorBEC.make_scalar_ws(
        grid, V_trap;
        g_contact = 1.0, c_dd = 100.0, F = 1.0, gamma_lhy = 0.0, dt = 0.0,
    )

    # Spherically symmetric Gaussian density
    σ = 1.5
    @inbounds for I in CartesianIndices(ws.psi)
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        ws.psi[I] = exp(-(x*x + y*y + z*z) / (2σ*σ))
    end
    SpinorBEC.normalize_scalar!(ws)
    SpinorBEC._update_density!(ws)

    # B̂ = ẑ → V_dd should be axisymmetric around z, with extremum on z-axis
    SpinorBEC.compute_tilted_dipole_potential!(ws, SVector{3,Float64}(0.0, 0.0, 1.0))
    Vdd_z = copy(ws.V_dd)

    # B̂ = x̂ → V_dd should be axisymmetric around x (90° rotation of above)
    SpinorBEC.compute_tilted_dipole_potential!(ws, SVector{3,Float64}(1.0, 0.0, 0.0))
    Vdd_x = copy(ws.V_dd)

    # Reference index near origin (grid is offset, no exact origin cell)
    cx, cy, cz = 17, 17, 17

    # The dipolar potential carries nontrivial structure (not all zero)
    @test maximum(abs, Vdd_z) > 1e-3
    @test maximum(abs, Vdd_x) > 1e-3
    @test maximum(abs, Vdd_z) ≈ maximum(abs, Vdd_x) atol=1e-10  # |V_dd| invariant under B̂ rotation

    # Rotation symmetry: rotating B̂ by 90° (ẑ → x̂) rotates V_dd by 90° too.
    # Pick a point along the z-axis at index +6 from center: (cx, cy, cz+6).
    # Under B̂=ẑ, this is "along the polarization axis".
    # Under B̂=x̂, the equivalent point is at (cx+6, cy, cz) — "along x-axis = along new polarization axis".
    edge_along_z_under_z = Vdd_z[cx, cy, cz + 6]
    edge_along_x_under_x = Vdd_x[cx + 6, cy, cz]
    @test edge_along_z_under_z ≈ edge_along_x_under_x atol=1e-8

    # Same: perpendicular point under each B̂
    edge_perp_under_z = Vdd_z[cx + 6, cy, cz]      # along x (perp to ẑ)
    edge_perp_under_x = Vdd_x[cx, cy, cz + 6]      # along z (perp to x̂)
    @test edge_perp_under_z ≈ edge_perp_under_x atol=1e-8

    # Head-to-tail attraction along B̂ vs perpendicular: V_dd(along B̂) < V_dd(perp)
    @test edge_along_z_under_z < edge_perp_under_z

    # B̂=(1,1,1)/√3 (diagonal) — V_dd extends along (1,1,1) direction
    invsqrt3 = 1.0 / sqrt(3)
    SpinorBEC.compute_tilted_dipole_potential!(
        ws, SVector{3,Float64}(invsqrt3, invsqrt3, invsqrt3)
    )
    Vdd_diag = ws.V_dd
    edge_diag = Vdd_diag[cx + 4, cy + 4, cz + 4]   # along (1,1,1)
    edge_anti = Vdd_diag[cx + 6, cy, cz]           # along x only
    @test edge_diag != edge_anti                     # asymmetric for off-axis B̂
end
