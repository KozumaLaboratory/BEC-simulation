# Magnitude oracle for the dipolar kernel.
#
# `test/rotating_basis/test_scalar_egpe_dipole_kernel.jl` pins the kernel's
# SYMMETRY and DIRECTION — and a kernel multiplied by any constant passes every
# assertion in it. That blind spot matters here: a magnetostirring reproduction
# is a measurement of how much the cloud deforms, so the amplitude is the
# physics, not a detail.
#
# Two independent anchors, because they fail differently:
#
#   1. Against the repo's OTHER dipolar implementation (the gated spinor
#      6-FFT convolution). A shared-prefactor error would pass this one, which
#      is why it is not the only anchor.
#   2. Against the exact Thomas-Fermi solution of O'Dell/Giovanazzi/Eberlein,
#      which is outside this repository entirely and fixes the magnitude in
#      absolute terms.

using Test
using SpinorBEC
using SpinorBEC: make_scalar_ws, find_ground_state_scalar!, scalar_aspect_ratio,
    planar_aspect_ratio, normalize_scalar!, GridConfig, make_grid,
    compute_tilted_dipole_potential!, _update_density!,
    compute_c_dd_dimless, compute_a_dd, Units, ATOM_REGISTRY,
    make_ddi_params, make_ddi_buffers, compute_ddi_potential!
using StaticArrays: SVector

@testset "dipolar magnetostriction magnitude" begin
    @testset "closed form: limits and the branch it must not take" begin
        # ε_dd = 0 ⇒ the cloud takes the trap's shape.
        for λ in (0.5, 1.0, 2.6, 5.0)
            @test dipolar_tf_aspect_ratio(0.0, λ) == λ
        end
        # A dipole polarized along z stretches the cloud along z, so
        # κ = R_⊥/R_z must DECREASE with ε_dd — monotonically.
        λ = 2.6
        κ = [dipolar_tf_aspect_ratio(e, λ) for e in (0.0, 0.3, 0.6, 0.9, 1.172)]
        @test all(isfinite, κ)
        @test all(diff(κ) .< 0)
        @test κ[end] ≈ 1.635 atol = 0.01          # the value used in the doc

        # For ε_dd > 1 the residual has a SECOND root at small κ that is not
        # the trapped solution. Pin that the returned root is the physical one
        # and that the spurious one is genuinely there (so this is not a test
        # of an absent hazard).
        @test dipolar_tf_shape_residual(κ[end], 1.172, λ) ≈ 0 atol = 1e-6
        @test sign(dipolar_tf_shape_residual(0.2, 1.172, λ)) ==
            sign(dipolar_tf_shape_residual(3.0, 1.172, λ))   # both negative
        @test sign(dipolar_tf_shape_residual(1.2, 1.172, λ)) !=
            sign(dipolar_tf_shape_residual(3.0, 1.172, λ))   # bracketed above
    end

    @testset "scalar kernel == the gated spinor DDI, amplitude included" begin
        atom = ATOM_REGISTRY[:Dy162]
        N = 10000
        ω_ref = 2π * 50.0
        grid = make_grid(GridConfig((32, 32, 32), (12.0, 12.0, 12.0)))
        dV = prod(grid.dx)
        c_dd_spin = compute_c_dd_dimless(atom; N_atoms=N, omega_ref=ω_ref)

        ws = make_scalar_ws(grid, zeros(32, 32, 32);
            g_contact=1.0, c_dd=c_dd_spin * atom.F^2, F=1.0)
        # Anisotropic on purpose: a spherical density gives E_dd = 0 exactly,
        # a null that ANY wrong amplitude also passes.
        for I in CartesianIndices(ws.psi)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws.psi[I] = exp(-(x^2 / 8 + y^2 / 3.92 + z^2 / 2))
        end
        normalize_scalar!(ws)
        _update_density!(ws)
        n = copy(ws.rho)

        for b in (SVector(0.0, 0.0, 1.0), SVector(1.0, 0.0, 0.0),
            SVector(sin(deg2rad(35)), 0.0, cos(deg2rad(35))))
            compute_tilted_dipole_potential!(ws, b)
            E_scalar = 0.5 * sum(n .* ws.V_dd) * dV
            @test abs(E_scalar) > 1e-3            # calibration: not the null

            ddi = make_ddi_params(grid, atom; c_dd=c_dd_spin)
            bufs = make_ddi_buffers(grid.config.n_points)
            F = Float64(atom.F)
            bufs.Fx_r .= F .* n .* b[1]
            bufs.Fy_r .= F .* n .* b[2]
            bufs.Fz_r .= F .* n .* b[3]
            compute_ddi_potential!(ddi, bufs)
            E_spin =
                0.5 *
                sum(bufs.Phi_x .* bufs.Fx_r .+ bufs.Phi_y .* bufs.Fy_r .+
                    bufs.Phi_z .* bufs.Fz_r) * dV
            @test E_scalar ≈ E_spin rtol = 1e-10
        end
    end

    @testset "the solver reproduces the closed-form deformation" begin
        # Contact + DDI only, no LHY: the closed form has no LHY either.
        λ = 2.6
        grid = make_grid(GridConfig((64, 64, 32), (18.0, 18.0, 9.0)))
        V = [0.5 * (x^2 + y^2 + λ^2 * z^2)
             for x in grid.x[1], y in grid.x[2], z in grid.x[3]]

        function κ_of(g0, eps_dd)
            ws = make_scalar_ws(grid, V;
                g_contact=g0, c_dd=3 * eps_dd * g0, F=1.0)  # c_dd/c₀ = 3ε_dd
            for I in CartesianIndices(ws.psi)
                x = grid.x[1][I[1]];
                y = grid.x[2][I[2]];
                z = grid.x[3][I[3]]
                v = 15.0 - 0.5 * (x^2 + y^2 + λ^2 * z^2)
                ws.psi[I] = v > 0 ? sqrt(v) + 0im : 0im
            end
            normalize_scalar!(ws)
            find_ground_state_scalar!(ws, 4000, 0.004; B_hat=SVector(0.0, 0.0, 1.0))
            # scalar_aspect_ratio is σ_z/σ_⊥ = R_z/R_⊥ = 1/κ for a TF profile.
            (1 / scalar_aspect_ratio(ws), planar_aspect_ratio(ws).ratio)
        end

        # (a) With the DDI OFF the numerics still miss the TF closed form, by
        # the quantum pressure the TF limit drops — 6.7 % at g₀ = 700 here.
        # That is not an error to be tolerated silently: it must SHRINK toward
        # the TF limit, which is the statement that makes it a correction
        # rather than a discrepancy. Measured: −6.7 % → −2.8 % from g₀ = 700 to
        # 3000.
        κ0_700, ar_700 = κ_of(700.0, 0.0)
        κ0_3000, _ = κ_of(3000.0, 0.0)
        @test κ0_700 < κ0_3000 < λ
        @test abs(κ0_3000 / λ - 1) < abs(κ0_700 / λ - 1) / 2
        @test ar_700 < 1.002        # B̂ ∥ ẑ: no in-plane deformation, exactly

        # (b) The DDI-induced deformation, with that correction divided out.
        # This is the amplitude statement: how much the dipoles stretch the
        # cloud, against physics from outside this repository.
        κ6, ar6 = κ_of(700.0, 0.6)
        @test κ6 / κ0_700 ≈ dipolar_tf_aspect_ratio(0.6, λ) / λ rtol = 0.05
        @test ar6 < 1.002            # still B̂ ∥ ẑ

        # Calibration: the ratio being compared must actually move. A DDI that
        # did nothing would give κ6/κ0 = 1 and could pass a loose rtol against
        # a closed form that happened to sit near 1.
        @test κ6 / κ0_700 < 0.85
    end
end
