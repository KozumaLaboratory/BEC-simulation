# Regression gate: the DDI off-diagonal kernel must be x↔y(↔z) symmetric.
#
# Root cause it guards (2026-06-09): production builds Q on the rfft
# half-grid — axis 1 stores +k_Nyquist (rfftfreq) while the full-fft axes
# store −k_Nyquist (fftfreq). The off-diagonals Q_xy/Q_xz/Q_yz are odd in
# their two axes, so the raw signed Nyquist representative gives an
# axis-asymmetric kernel and a z-polarized cloud relaxes into a spuriously
# y-squished shape despite a fully xy-symmetric trap/field/dipole axis.
# The continuum value of an odd kernel at a folded Nyquist mode is 0, so
# `_build_q_tensor!` zeros the off-diagonals on every odd-axis Nyquist
# plane. See ddi_nyquist_xy_asymmetry_probe.jl (archived: BEC-simulation-archive/scripts_2026_08_18/).

using Test
using SpinorBEC

@testset "DDI Nyquist x↔y symmetry" begin
    swap_xy(A) = permutedims(A, (2, 1, 3))

    @testset "production Q off-diagonals zeroed on Nyquist planes" begin
        n = 16
        grid = make_grid(GridConfig((n, n, n), (10.0, 10.0, 10.0)))
        ddi = make_ddi_params(grid, Eu151)
        nyq = n ÷ 2 + 1                  # rfft axis-1 last index AND fft axes Nyquist

        @test all(==(0.0), @view ddi.Q_xy[nyq, :, :])   # odd in kx
        @test all(==(0.0), @view ddi.Q_xy[:, nyq, :])   # odd in ky
        @test all(==(0.0), @view ddi.Q_xz[nyq, :, :])   # odd in kx
        @test all(==(0.0), @view ddi.Q_xz[:, :, nyq])   # odd in kz
        @test all(==(0.0), @view ddi.Q_yz[:, nyq, :])   # odd in ky
        @test all(==(0.0), @view ddi.Q_yz[:, :, nyq])   # odd in kz

        # Sanity: off-diagonals are NOT globally zero (interior modes alive).
        @test maximum(abs, ddi.Q_xy) > 0.1
        @test maximum(abs, ddi.Q_xz) > 0.1
    end

    # z-polarized, x↔y-symmetric, BROADBAND (incl. Nyquist) state. f_x=f_y=0,
    # f_z(r) carries the asymmetry-exposing high-k content. Φ_x=Q_xz⊛f_z and
    # Φ_y=Q_yz⊛f_z must then be x↔y mirrors; Φ_z must be self-symmetric.
    function symmetric_zpol_state(n)
        sys = SpinSystem(1)                                # spin-1, D=3
        psi = zeros(ComplexF64, n, n, n, sys.n_components)
        g = randn(n, n, n)
        amp = g .+ swap_xy(g)                              # x↔y symmetric, broadband
        psi[:, :, :, 3] .= amp                            # m = −1 (z-polarized)
        psi
    end

    @testset "reference DDI potentials are x↔y symmetric" begin
        n = 16
        grid = make_grid(GridConfig((n, n, n), (10.0, 10.0, 10.0)))
        sm = spin_matrices(1)
        psi = symmetric_zpol_state(n)

        Φx, Φy, Φz = reference_ddi_potentials(psi, sm, grid)
        @test maximum(abs, Φx) > 0                        # non-trivial
        @test isapprox(Φx, swap_xy(Φy); rtol=1e-10, atol=1e-12)
        @test isapprox(Φz, swap_xy(Φz); rtol=1e-10, atol=1e-12)
    end

    @testset "production DDI potentials are x↔y symmetric" begin
        n = 16
        npts = (n, n, n)
        grid = make_grid(GridConfig(npts, (10.0, 10.0, 10.0)))
        sm = spin_matrices(1)
        ddi = make_ddi_params(grid, Eu151)
        bufs = make_ddi_buffers(npts)
        psi = symmetric_zpol_state(n)

        SpinorBEC._compute_and_convolve_ddi!(psi, sm, ddi, bufs, Val(3), 3, npts)
        @test maximum(abs, bufs.Phi_x) > 0
        @test isapprox(bufs.Phi_x, swap_xy(bufs.Phi_y); rtol=1e-10, atol=1e-12)
        @test isapprox(bufs.Phi_z, swap_xy(bufs.Phi_z); rtol=1e-10, atol=1e-12)
    end
end
