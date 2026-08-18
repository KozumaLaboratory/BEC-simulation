# Tier-A spherically-truncated DDI kernel (Ronen cutoff).
#
# `_build_q_tensor!(...; trunc_radius=R)` multiplies every Q component by the
# radial modifier h(|k|R) = 1 + 3cos(x)/x² − 3sin(x)/x³ (x = |k|R), the Fourier
# transform of the dipolar tensor kernel truncated in real space at radius R
# (Ronen–Bortolotti–Bohn, PRA 74, 013623 (2006); spectral-accuracy analysis
# Vico–Greengard–Ferrando, JCP 323, 191 (2016)). `h(0)=0` preserves the existing
# spherical-cavity `Q(k=0)=0` convention (no contact / −δ term introduced);
# `h(x)→1` for `x ≫ 1` leaves the bulk physics intact.
#
# NOTE on "isotropy" testing: the bare grid kernel already respects every cubic
# point-group symmetry — including the 45° xy-diagonal mirror — because Q is a
# function of the lattice-invariant |k|² (e.g. grid points (i,j) and (j,i) carry
# identical Q). A *discrete* 45°-symmetry assertion is therefore auto-satisfied
# and proves nothing about truncation. The genuine artifact the cutoff removes is
# the periodic-image contamination of the un-padded convolution — a deviation
# from *continuous* rotational symmetry that is only visible against a free-space
# / large-box reference. That convergence diagnostic lives in
# `ddi_truncation_isotropy_probe.jl (archived: BEC-simulation-archive/scripts_2026_08_18/)` (B: physics-fidelity); the asserts
# below pin the kernel construction itself (A: code-correctness).

using Test
using SpinorBEC
using SpinorBEC: ddi_trunc_factor, make_ddi_params, make_ddi_buffers, Eu151

@testset "DDI truncated kernel (Ronen cutoff, Tier A)" begin
    @testset "ddi_trunc_factor radial modifier h(x)" begin
        h = ddi_trunc_factor

        # h(0)=0 limit (small-x series branch); finite near 0 (no 3/x² cancellation blowup).
        @test h(0.0) == 0.0
        @test isapprox(h(1.0e-6), (1.0e-6)^2 / 10; rtol=1e-3)
        @test isfinite(h(1.0e-12)) && abs(h(1.0e-12)) < 1e-20
        @test h(1.0e-300) == 0.0                      # underflow → 0, never NaN

        # series ↔ direct continuity across the x=1 crossover.
        direct1 = 1 + 3cos(1.0) / 1 - 3sin(1.0) / 1
        @test isapprox(h(1.0), direct1; rtol=1e-12)   # x=1 takes the direct branch
        @test isapprox(h(prevfloat(1.0)), h(1.0); rtol=1e-6)

        # matches the closed form on the direct branch.
        for x in (1.5, 2.7, 4.0, 6.283185307, 10.0, 31.4)
            @test isapprox(h(x), 1 + 3cos(x) / x^2 - 3sin(x) / x^3; rtol=1e-12)
        end

        # h→1 for x≫1 (bulk unchanged); globally bounded (peak ≈1.076 near x=2π).
        @test isapprox(h(1.0e3), 1.0; atol=1e-5)
        @test isapprox(h(1.0e6), 1.0; atol=1e-9)
        @test all(abs(h(x)) <= 1.1 for x in range(0.0, 60.0; length=4001))

        # Float32 path is finite and tracks Float64.
        @test isfinite(ddi_trunc_factor(3.0f0))
        @test ddi_trunc_factor(3.0f0) isa Float32
        @test isapprox(Float64(ddi_trunc_factor(3.0f0)), h(3.0); rtol=1e-5)
    end

    @testset "Q_trunc = h(|k|R)·Q_bare, traceless, k=0 → 0" begin
        n = 16
        L = 12.0
        grid = make_grid(GridConfig((n, n, n), (L, L, L)))
        R = L / 2
        ddi_bare = make_ddi_params(grid, Eu151)
        ddi_tr = make_ddi_params(grid, Eu151; trunc_radius=R)

        # The rfft axis-1 frequencies are (i-1)·dk (rfftfreq); the full axes are grid.k.
        kx = [(i - 1) * grid.dk[1] for i in 1:(n ÷ 2 + 1)]
        ky = grid.k[2]
        kz = grid.k[3]
        rk = size(ddi_bare.Q_zz)

        maxabs = 0.0
        for I in CartesianIndices(rk)
            k2 = kx[I[1]]^2 + ky[I[2]]^2 + kz[I[3]]^2
            if iszero(k2)
                # k=0 bin stays exactly zero — spherical-cavity convention preserved.
                @test ddi_tr.Q_xx[I] == 0.0
                @test ddi_tr.Q_yy[I] == 0.0
                @test ddi_tr.Q_zz[I] == 0.0
                continue
            end
            hx = ddi_trunc_factor(sqrt(k2) * R)
            for (Qt, Qb) in (
                (ddi_tr.Q_xx, ddi_bare.Q_xx), (ddi_tr.Q_yy, ddi_bare.Q_yy),
                (ddi_tr.Q_zz, ddi_bare.Q_zz), (ddi_tr.Q_xy, ddi_bare.Q_xy),
                (ddi_tr.Q_xz, ddi_bare.Q_xz), (ddi_tr.Q_yz, ddi_bare.Q_yz),
            )
                maxabs = max(maxabs, abs(Qt[I] - hx * Qb[I]))
            end
            # tracelessness preserved under the scalar radial factor.
            @test isapprox(ddi_tr.Q_xx[I] + ddi_tr.Q_yy[I] + ddi_tr.Q_zz[I], 0.0; atol=1e-12)
        end
        @test maxabs < 1e-12

        # Truncation genuinely changes the low-k kernel (h≪1 there) ...
        @test sum(abs, ddi_tr.Q_zz) < sum(abs, ddi_bare.Q_zz)
        # ... but leaves the high-|k| corner essentially untouched (h→1).
        corner = CartesianIndex(rk)
        @test isapprox(ddi_tr.Q_zz[corner], ddi_bare.Q_zz[corner]; rtol=2e-2)
    end

    @testset "Nyquist off-diagonal zeroing still holds with truncation" begin
        # The radial factor multiplies before the odd-axis Nyquist zeroing, so the
        # x↔y symmetry guard (test_ddi_nyquist_xy_symmetry.jl) must survive Tier A.
        n = 16
        grid = make_grid(GridConfig((n, n, n), (10.0, 10.0, 10.0)))
        ddi = make_ddi_params(grid, Eu151; trunc_radius=5.0)
        nyq = n ÷ 2 + 1
        @test all(==(0.0), @view ddi.Q_xy[nyq, :, :])
        @test all(==(0.0), @view ddi.Q_xy[:, nyq, :])
        @test all(==(0.0), @view ddi.Q_xz[nyq, :, :])
        @test all(==(0.0), @view ddi.Q_yz[:, :, nyq])
        @test maximum(abs, ddi.Q_xy) > 0.0   # interior off-diagonals still alive
    end

    @testset "convolution runs with a truncated kernel" begin
        n = 16
        npts = (n, n, n)
        grid = make_grid(GridConfig(npts, (12.0, 12.0, 12.0)))
        sm = spin_matrices(1)
        sys = SpinSystem(1)
        x = grid.x[1]
        psi = zeros(ComplexF64, n, n, n, sys.n_components)
        for I in CartesianIndices((n, n, n))
            r2 = x[I[1]]^2 + x[I[2]]^2 + x[I[3]]^2
            psi[I, 3] = exp(-r2 / (2 * 1.5^2))
        end
        ddi = make_ddi_params(grid, Eu151; trunc_radius=6.0)
        bufs = make_ddi_buffers(npts)
        SpinorBEC._compute_and_convolve_ddi!(psi, sm, ddi, bufs, Val(3), 3, npts)
        @test all(isfinite, bufs.Phi_z)
        @test maximum(abs, bufs.Phi_z) > 0.0
    end

    @testset "padded grid sizing (Tier B + anisotropic pad)" begin
        gs = SpinorBEC._padded_grid_size
        # factor 2 keeps the exact historical 2n (backward-compatible).
        @test gs(2, 32) == 64
        @test gs(2, 48) == 96
        # other factors round factor·n UP to an FFT-friendly size, ≥ n+1.
        @test gs(1.5, 32) >= 48 && gs(1.5, 32) == nextprod((2, 3, 5, 7), 48)
        @test gs(2.73, 64) >= ceil(Int, 2.73 * 64)
        @test gs(1.0, 32) >= 33                      # ≥ n+1 even at factor 1
        @test_throws ArgumentError gs(0.5, 32)       # factor < 1 rejected
    end

    @testset "make_ddi_padded honors pad_factor (scalar + anisotropic)" begin
        n = 8
        grid = make_grid(GridConfig((n, n, n), (10.0, 10.0, 10.0)))
        # default: 2n per axis.
        ctx2 = make_ddi_padded(grid, Eu151; trunc_radius=5.0)
        @test ctx2.padded_shape == (2n, 2n, 2n)
        # anisotropic: thin z padded less than xy ⇒ smaller z, fewer points overall.
        ctx_a = make_ddi_padded(grid, Eu151; trunc_radius=4.0, pad_factor=(2.0, 2.0, 1.5))
        @test ctx_a.padded_shape[1] == 2n
        @test ctx_a.padded_shape[3] < 2n
        @test prod(ctx_a.padded_shape) < prod(ctx2.padded_shape)
        # the truncated tensor is still traceless on the padded grid.
        @test all(isfinite, ctx_a.Q_zz)
    end
end
