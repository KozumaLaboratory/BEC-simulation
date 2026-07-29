using Test
using SpinorBEC
using SpinorBEC: Units

# Dipolar magnetic field radiated by a (spin-polarised) cloud.
#
# Physics oracle: far from a localised z-polarised source the field is that of
# a point dipole m_tot ẑ,
#     B_z(on axis)   = +(μ₀/4π)·2 m_tot / r³   (> 0)
#     B_z(equatorial)= -(μ₀/4π)·  m_tot / r³   (< 0)
# with m_tot = ∫ M_z dV. The kernel is scale-free, so we test directly on the
# internal grid (lengths in grid units, dV = prod(grid.dx)).

@testset "Dipolar magnetic field" begin
    μ0 = Units.MU_0

    # 48³ box, narrow Gaussian magnetisation along z at the centre.
    n = 48
    L = 24.0
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    x, y, z = grid.x
    σ = 1.2
    M0 = 3.5  # peak |M| [A/m]
    Mz = [M0 * exp(-(x[i]^2 + y[j]^2 + z[k]^2) / (2σ^2)) for i in 1:n, j in 1:n, k in 1:n]
    Mzero = zeros(n, n, n)

    Bx, By, Bz = dipole_magnetic_field(grid, Mzero, Mzero, Mz; padded=true)

    @test size(Bx) == (n, n, n)
    @test all(isfinite, Bz)

    m_tot = sum(Mz) * prod(grid.dx)
    ic = n ÷ 2 + 1  # central index (x[ic] ≈ y ≈ z ≈ 0, the grid is centred)

    # Pick a far-field index ~6σ from centre (still well inside the box).
    kfar = ic + round(Int, 6σ / grid.dx[3])
    r = z[kfar]
    @test r > 5σ

    # On-axis (x=y=0, large z): positive, matches point dipole within a few %.
    Bz_axis = Bz[ic, ic, kfar]
    Bz_axis_analytic = (μ0 / (4π)) * 2 * m_tot / r^3
    @test Bz_axis > 0
    @test isapprox(Bz_axis, Bz_axis_analytic; rtol=0.05)

    # Equatorial (large x, z=0): negative, half the on-axis magnitude, opposite sign.
    ifar = ic + round(Int, 6σ / grid.dx[1])
    rx = x[ifar]
    Bz_eq = Bz[ifar, ic, ic]
    Bz_eq_analytic = -(μ0 / (4π)) * m_tot / rx^3
    @test Bz_eq < 0
    @test isapprox(Bz_eq, Bz_eq_analytic; rtol=0.05)

    # Near the z-axis the transverse field is small vs the longitudinal one.
    # (Even-N grids have no point exactly on the axis — x[ic]=dx/2 — so the
    # residual is geometric, a few %, not zero.)
    @test abs(Bx[ic, ic, kfar]) < 0.1 * abs(Bz_axis)
    @test abs(By[ic, ic, kfar]) < 0.1 * abs(Bz_axis)

    @testset "density helper matches polarised magnetisation" begin
        atom = SpinorBEC.Eu151
        a_ho = 1.0e-6
        n_atoms = 1.0e4
        # Normalised density (∫ρ dV = 1) → M = mu_mag·n_atoms/a_ho³·ρ ẑ.
        ρ = [exp(-(x[i]^2 + y[j]^2 + z[k]^2) / (2σ^2)) for i in 1:n, j in 1:n, k in 1:n]
        ρ ./= sum(ρ) * prod(grid.dx)
        Bxd, Byd, Bzd = magnetic_field_from_density(grid, ρ; atom, a_ho, n_atoms, padded=true)

        Mz2 = (atom.mu_mag * n_atoms / a_ho^3) .* ρ
        Bx2, By2, Bz2 = dipole_magnetic_field(grid, Mzero, Mzero, Mz2; padded=true)
        @test Bzd ≈ Bz2
        @test Bxd ≈ Bx2
    end

    @testset "spinor helper reduces to stretched polarised density" begin
        F = 6
        sm = spin_matrices(F)
        atom = SpinorBEC.Eu151
        a_ho = 1.0e-6
        n_atoms = 1.0e4
        # Fully stretched |m=+F⟩ Gaussian → magnetisation purely along z.
        psi = zeros(ComplexF64, n, n, n, 2F + 1)
        amp = [exp(-(x[i]^2 + y[j]^2 + z[k]^2) / (4σ^2)) for i in 1:n, j in 1:n, k in 1:n]
        nrm = sqrt(sum(abs2, amp) * prod(grid.dx))
        psi[:, :, :, 1] .= amp ./ nrm  # c=1 ↔ m=+F

        Bxs, Bys, Bzs = magnetic_field_from_spinor(psi, grid, sm, atom; a_ho, n_atoms, padded=true)

        ρ = abs2.(psi[:, :, :, 1])
        Bxd, Byd, Bzd = magnetic_field_from_density(grid, ρ; atom, a_ho, n_atoms, padded=true)
        # Stretched |m=+F⟩ ≡ fully z-polarised: the spinor path must reproduce
        # the density path component-for-component.
        @test Bxs ≈ Bxd
        @test Bys ≈ Byd
        @test Bzs ≈ Bzd
    end

    @testset "periodic vs padded agree in the core" begin
        Bxp, Byp, Bzp = dipole_magnetic_field(grid, Mzero, Mzero, Mz; padded=false)
        # Near the dense centre the two convolutions agree to a few %.
        @test isapprox(Bzp[ic, ic, kfar], Bz_axis; rtol=0.1)
    end
end
