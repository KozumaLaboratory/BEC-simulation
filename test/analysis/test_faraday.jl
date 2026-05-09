# --- Faraday image regression (n_total double-count fix, 2026-05-02) ---
#
# `spin_density_vector` returns the local spin density f_α(r) = ⟨ψ|F_α|ψ⟩
# = ⟨F_α⟩_local · n(r) — already n-weighted. The earlier `faraday_image`
# multiplied f_z by `n_total` again, computing ∫⟨F_z⟩·n² dz (off by one
# factor of n). Visible cleanly with a fully polarized m = +F state:
# col_Fz must equal F · col_n exactly.

using SpinorBEC
using Test

@testset "Faraday image — fully polarized m=+F (n_total double-count regression)" begin
    @testset "F=6, 3D" begin
        F = 6
        grid = make_grid(GridConfig((24, 24, 12), (10.0, 10.0, 5.0)))
        psi = init_psi(grid, SpinSystem(F); state=:m_plus_F)

        img = faraday_image(psi, grid, F; params=FaradayParams(probe_axis=3))

        # For fully polarized m = +F: f_z(r) = F · n(r), so col_Fz = F · col_n.
        # If the bug is back, col_Fz = F · ∫n² dz which is ≠ F · col_n at all
        # but the very peak of n.
        rel =
            abs.(img.column_Fz .- F .* img.column_density) ./
            max.(abs.(F .* img.column_density), 1e-30)
        # Check on the support of the cloud only — the fringe of the box
        # has both numerator and denominator at noise level.
        mask = img.column_density .> 0.05 * maximum(img.column_density)
        @test maximum(rel[mask]) < 1e-10
    end

    @testset "Probe ⊥ polarization → vanishing col_Fz (F=1, 3D)" begin
        # Faraday rotation reads the spin component along the probe axis.
        # m = +F is z-polarized, so probe_axis=1 (x-propagating beam) sees
        # no rotation. Pre-fix this would have given a finite (but
        # incorrectly n²-weighted) signal of zero — this test wouldn't
        # have caught the bug. Post-fix it remains zero, as a sanity
        # check on the projection direction.
        F = 1
        grid = make_grid(GridConfig((16, 16, 8), (10.0, 10.0, 5.0)))
        psi = init_psi(grid, SpinSystem(F); state=:m_plus_F)
        img = faraday_image(psi, grid, F; params=FaradayParams(probe_axis=1))
        @test maximum(abs, img.column_Fz) < 1e-12
    end

    @testset "Polar |m=0⟩ → col_Fz vanishes" begin
        # F=1 polar (|m=0⟩) state: ⟨F_z⟩ = 0 everywhere.
        F = 1
        grid = make_grid(GridConfig((24, 24, 12), (10.0, 10.0, 5.0)))
        psi = init_psi(grid, SpinSystem(F); state=:polar)

        img = faraday_image(psi, grid, F; params=FaradayParams(probe_axis=3))
        @test maximum(abs, img.column_Fz) < 1e-12
    end
end
