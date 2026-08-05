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

    @testset "uniformly magnetised sphere — interior is EXACTLY zero" begin
        # Independent analytic oracle, no reference implementation involved.
        # Inside a uniformly magnetised sphere H = -M/3 exactly, and this
        # convention returns B = μ₀H + μ₀M/3 (the +δ/3 of Q_αβ), so the two
        # cancel and the interior field vanishes identically. Every nonzero
        # value inside is error.
        Ls, ns, Rs, Ms = 12.0, 48, 3.0, 1.0e5
        gs = make_grid(GridConfig((ns, ns, ns), (Ls, Ls, Ls)))
        xs, ys, zs = gs.x
        Ms_z = zeros(Float64, ns, ns, ns)
        for I in CartesianIndices(Ms_z)
            (xs[I[1]]^2 + ys[I[2]]^2 + zs[I[3]]^2 <= Rs^2) && (Ms_z[I] = Ms)
        end
        Zs = zeros(Float64, ns, ns, ns)
        scale = μ0 * Ms / 3           # the natural field scale of the problem
        # Sample well inside, away from the staircase surface.
        inner = [
            I for I in CartesianIndices(Ms_z)
                  if xs[I[1]]^2 + ys[I[2]]^2 + zs[I[3]]^2 <= (Rs / 2)^2
        ]
        resid(kw) =
            let (_, _, B) = dipole_magnetic_field(gs, Zs, Zs, Ms_z; kw...)
                maximum(I -> abs(B[I]), inner) / scale
            end

        r_pad_trunc = resid((padded=true, truncate=true))
        r_pad_only = resid((padded=true, truncate=false))
        r_bare = resid((padded=false, truncate=false))

        @test r_pad_trunc < 1e-2                 # the oracle holds at all
        @test r_pad_only < 0.5 * r_bare          # padding is the big win here
        @test r_pad_trunc <= r_pad_only          # and the cutoff does not hurt
        # This residual is dominated by the sphere's staircase surface (it falls
        # with resolution), so it gates the padding but cannot resolve the
        # cutoff's contribution. The smooth-source test below does that.
    end

    @testset "cutoff removes the residual a padded kernel still has" begin
        # Padding pushes the SOURCE images out but leaves the KERNEL periodic on
        # the doubled box, and the 1/r³ tail wraps. Reference: same dx, doubled
        # box, so the images are twice as far and the interior is converged.
        σr, nr, Lr = 1.2, 32, 12.0
        gauss(g) =
            let (gx, gy, gz) = g.x
                [
                    M0 * exp(-(gx[i]^2 + gy[j]^2 + gz[k]^2) / (2σr^2))
                    for i in eachindex(gx), j in eachindex(gy), k in eachindex(gz)
                ]
            end
        gref = make_grid(GridConfig((2nr, 2nr, 2nr), (2Lr, 2Lr, 2Lr)))
        Mref = gauss(gref)
        _, _, Bref = dipole_magnetic_field(gref, zero(Mref), zero(Mref), Mref;
            padded=true, truncate=true)

        gsm = make_grid(GridConfig((nr, nr, nr), (Lr, Lr, Lr)))
        Msm = gauss(gsm)
        off = nr ÷ 2                  # same dx ⇒ small box is the centre block
        err(kw) =
            let (_, _, B) = dipole_magnetic_field(gsm, zero(Msm), zero(Msm), Msm; kw...)
                num, den = 0.0, 0.0
                for k in 1:nr, j in 1:nr, i in 1:nr
                    r = Bref[i + off, j + off, k + off]
                    num = max(num, abs(B[i, j, k] - r))
                    den = max(den, abs(r))
                end
                num / den
            end

        e_trunc = err((padded=true, truncate=true))
        e_pad_only = err((padded=true, truncate=false))
        @test e_trunc < 0.1 * e_pad_only    # measured 5.5e-5 vs 2.6e-3, a 46x gap
        @test e_trunc < 1e-3
    end
end
