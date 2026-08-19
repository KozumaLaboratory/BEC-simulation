using Test
using SpinorBEC
using StaticArrays
using LinearAlgebra
using Random

# Structural / property-based tests. Two goals:
#
#   1. Verify the SU(2) algebra of `spin_matrices(F)` across the full F range
#      we ship (F=1..8). Catches sign/normalization regressions in any future
#      refactor of Fx/Fy/Fz/Fp/Fm construction at the lowest layer.
#
#   2. Verify the Euler 5-stage rotation (`_apply_euler_spin_rotation`) is
#      operationally equal to the analytic `exp(-i dt (φx Fx + φy Fy + φz Fz))`
#      for random φ and random complex unit spinors. The randomization keeps
#      the test off the polar / ferromagnetic degenerate planes (⟨F⟩=0 or
#      |⟨F⟩|=F) where many sign-class bugs cancel — the same hole that hid
#      the GPU spin-mixing R_z sign bug fixed in 2026-04 from CPU tests.

@testset "Property-based: spinor algebra + rotation" begin
    @testset "Angular momentum algebra F=$F" for F in 1:8
        sm = spin_matrices(F)
        D = 2F + 1
        Fx, Fy, Fz = Matrix(sm.Fx), Matrix(sm.Fy), Matrix(sm.Fz)
        Fp, Fm = Matrix(sm.Fp), Matrix(sm.Fm)

        @test Fx^2 + Fy^2 + Fz^2 ≈ F * (F + 1) * I(D) atol = 1e-10

        @test Fx * Fy - Fy * Fx ≈ im * Fz atol = 1e-10
        @test Fy * Fz - Fz * Fy ≈ im * Fx atol = 1e-10
        @test Fz * Fx - Fx * Fz ≈ im * Fy atol = 1e-10

        @test Fp ≈ Fx + im * Fy atol = 1e-10
        @test Fm ≈ Fx - im * Fy atol = 1e-10
        @test Fp * Fm - Fm * Fp ≈ 2 * Fz atol = 1e-10

        @test Fx ≈ Fx' atol = 1e-12
        @test Fy ≈ Fy' atol = 1e-12
        @test Fz ≈ Fz' atol = 1e-12

        eigs = sort(real.(eigvals(Fz)))
        @test eigs ≈ collect(Float64, (-F):F) atol = 1e-10
    end

    @testset "Euler 5-stage = exp(-i dt H), F=$F" for F in 1:6
        sm = spin_matrices(F)
        D = 2F + 1
        m_vals = SVector{D, Float64}(ntuple(c -> F - (c - 1), Val(D)))
        rng = MersenneTwister(F)

        for trial in 1:10
            phi_x, phi_y, phi_z = randn(rng, 3)
            dt = 0.01 + 0.04 * rand(rng)

            H = phi_x * Matrix(sm.Fx) + phi_y * Matrix(sm.Fy) + phi_z * Matrix(sm.Fz)
            U_exact = exp(-im * dt * Hermitian(H))

            spinor_v = normalize(randn(rng, ComplexF64, D))
            spinor = SVector{D, ComplexF64}(spinor_v)
            expected = U_exact * spinor_v

            result = SpinorBEC._apply_euler_spin_rotation(
                spinor, phi_x, phi_y, phi_z,
                dt, F, m_vals,
                sm.Fy_eigvecs, sm.Fy_eigvecs_adj, sm.Fy_eigvals, sm, false,
            )

            @test Vector(result) ≈ expected atol = 1e-10
        end
    end
end

@testset "Property-based: physics structural invariants" begin

    # ── Test 5: DDI vanishes for ⟨F⟩=0 source ─────────────────────────
    # Polar state (m=0 only for F=1) has ⟨F_α⟩ = 0 everywhere. The DDI
    # potential is a linear functional of the spin density, so Φ must
    # also vanish. Direct check on FFT/Q-tensor wiring without going
    # through full workspace.
    @testset "DDI vanishes for ⟨F⟩=0 source (polar state)" begin
        F = 1
        n_pts = (16, 16, 16)
        grid = make_grid(GridConfig(n_pts, (10.0, 10.0, 10.0)))
        sm = spin_matrices(F)
        sys = SpinSystem(F)
        atom = ATOM_REGISTRY[:Eu151]

        psi = init_psi(grid, sys; state=:polar)
        bufs = make_ddi_buffers(n_pts)
        SpinorBEC._compute_spin_density!(
            bufs.Fx_r, bufs.Fy_r, bufs.Fz_r,
            psi, sm, Val(2F + 1), 3, n_pts,
        )

        @test maximum(abs, bufs.Fx_r) < 1e-12
        @test maximum(abs, bufs.Fy_r) < 1e-12
        @test maximum(abs, bufs.Fz_r) < 1e-12

        ddi = make_ddi_params(grid, atom; c_dd=10.0)
        compute_ddi_potential!(ddi, bufs)

        @test maximum(abs, bufs.Phi_x) < 1e-10
        @test maximum(abs, bufs.Phi_y) < 1e-10
        @test maximum(abs, bufs.Phi_z) < 1e-10
    end

    # ── Test 6: ⟨F⟩ transforms as a 3-vector under spin rotation ──────
    # rotate_quantization_axis applies U = exp(-i(θ_x F_x + θ_y F_y + θ_z F_z))
    # uniformly. Then U†F_α U should give the standard SO(3) rotation of
    # the (⟨F_x⟩, ⟨F_y⟩, ⟨F_z⟩) column vector. Random-axis trials check
    # rotation preserves |⟨F⟩|.
    @testset "Spinor rotation: ⟨F⟩ transforms as 3-vector, F=$F" for F in [1, 2, 6]
        grid = make_grid(GridConfig((12, 12, 12), (8.0, 8.0, 8.0)))
        sm = spin_matrices(F)
        sys = SpinSystem(F)

        psi = init_psi(grid, sys; state=:spin_coherent,
            init_theta=π / 3, init_phi=π / 4)
        dV = cell_volume(grid)

        Fx0, Fy0, Fz0 = spin_density_vector(psi, sm, 3)
        F_avg0 = [sum(Fx0), sum(Fy0), sum(Fz0)] .* dV
        @test norm(F_avg0) > 0.1   # sanity: ⟨F⟩ is non-trivial

        # R_z(α): U^†F_x U = cos α F_x − sin α F_y; U^†F_z U = F_z.
        for α in [0.3, -0.7, 1.5]
            psi_rot = rotate_quantization_axis(psi, F, 0.0, 0.0, α)
            Fx1, Fy1, Fz1 = spin_density_vector(psi_rot, sm, 3)
            F_avg1 = [sum(Fx1), sum(Fy1), sum(Fz1)] .* dV

            R_z = [cos(α) -sin(α) 0.0; sin(α) cos(α) 0.0; 0.0 0.0 1.0]
            @test F_avg1 ≈ R_z * F_avg0 atol = 1e-9
        end

        # R_y(β): U^†F_x U = cos β F_x + sin β F_z;
        #         U^†F_z U = −sin β F_x + cos β F_z; F_y unchanged.
        for β in [0.3, -1.1]
            psi_rot = rotate_quantization_axis(psi, F, 0.0, β, 0.0)
            Fx1, Fy1, Fz1 = spin_density_vector(psi_rot, sm, 3)
            F_avg1 = [sum(Fx1), sum(Fy1), sum(Fz1)] .* dV

            R_y = [cos(β) 0.0 sin(β); 0.0 1.0 0.0; -sin(β) 0.0 cos(β)]
            @test F_avg1 ≈ R_y * F_avg0 atol = 1e-9
        end

        # Random rotations preserve |⟨F⟩|.
        rng = MersenneTwister(F)
        for trial in 1:5
            tx, ty, tz = randn(rng, 3) .* π
            psi_rot = rotate_quantization_axis(psi, F, tx, ty, tz)
            Fx1, Fy1, Fz1 = spin_density_vector(psi_rot, sm, 3)
            F_avg1 = [sum(Fx1), sum(Fy1), sum(Fz1)] .* dV
            @test norm(F_avg1) ≈ norm(F_avg0) rtol = 1e-9
        end
    end

    # ── Test 7a: FFT round-trip ───────────────────────────────────────
    @testset "FFT round-trip" begin
        for n_pts in [(32,), (16, 16), (8, 8, 8)]
            plans = make_fft_plans(n_pts)
            rng = MersenneTwister(0)
            f_orig = randn(rng, ComplexF64, n_pts)
            f = copy(f_orig)
            plans.forward * f
            plans.inverse * f
            # plan_ifft! already includes the 1/N normalization
            @test f ≈ f_orig rtol = 1e-12
        end
    end

    # ── Test 7b: Quasi-2D scaling factor ──────────────────────────────
    # All four interaction channels (c0, c1, c_lhy, c_extra) must
    # receive the same 1/(√(2π)·l_z) factor (Gaussian transverse mode
    # integrated over z). Catches any future regression that scales
    # only c0/c1 and forgets the higher-rank channels.
    @testset "Quasi-2D scaling: 1/(√(2π)·l_z) factor uniform across channels" begin
        inter = InteractionParams(Dict(0 => 50.0, 1 => 5.0, 2 => 0.3); c_lhy=1.0)
        for l_z in [0.5, 1.0, 2.0]
            inter_q = SpinorBEC.scale_interactions_quasi_2d(inter, l_z)
            scale = 1.0 / (sqrt(2π) * l_z)
            @test inter_q[0] ≈ inter[0] * scale rtol = 1e-12
            @test inter_q[1] ≈ inter[1] * scale rtol = 1e-12
            @test inter_q.c_lhy ≈ inter.c_lhy * scale rtol = 1e-12
            @test inter_q[2] ≈ inter[2] * scale rtol = 1e-12
        end
    end

    # ── Test 12: phase classifier is rotation-invariant ───────────────
    # Phases (FM, polar, cyclic, ...) are gauge-equivalence classes
    # under O(3) spin rotations. classify_phase must return the same
    # label after a random global rotation — otherwise it is keying on
    # an orientation-dependent quantity (e.g. ⟨F_z⟩ sign) instead of
    # a true invariant.
    @testset "Phase classifier respects O(3) rotation, F=$F state=$state" for (F, state) in [
        (1, :m_plus_F), (1, :polar), (2, :m_plus_F)
    ]
        grid = make_grid(GridConfig((12, 12, 12), (8.0, 8.0, 8.0)))
        sm = spin_matrices(F)
        sys = SpinSystem(F)

        psi = init_psi(grid, sys; state=state)
        base = classify_phase(psi, F, grid, sm)

        rng = MersenneTwister(F * 100 + Int(state == :m_plus_F))
        for trial in 1:5
            tx, ty, tz = randn(rng, 3) .* π
            psi_rot = rotate_quantization_axis(psi, F, tx, ty, tz)
            got = classify_phase(psi_rot, F, grid, sm)
            @test got.phase == base.phase
        end
    end

    # ── Schema strict mode rejects silently-dropped YAML keys ─────────
    # Regression for the 2026-04-27 `trap:` incident — magnetostir YAMLs ran
    # in an isotropic trap because `trap:` was not a recognized key and
    # the @warn was easy to miss. Production runner now uses strict=true,
    # which converts the warning to an error.
    @testset "validate_pipeline! strict rejects unknown YAML keys" begin
        # `trap:` is not a known ground_state key — must error in strict.
        bad = Dict{String, Any}(
            "pipeline" => [
                Dict{String, Any}(
                    "ground_state" => Dict{String, Any}(
                        "atom" => "Rb87",
                        "grid" => Dict{String, Any}(
                            "n" => [16, 16, 16], "box" => [8.0, 8.0, 8.0]),
                        "trap" => [1.0, 1.0, 2.6],
                    ),
                ),
            ],
        )
        @test_throws ArgumentError validate_pipeline!(deepcopy(bad); strict=true)

        # Same payload with `potential:` instead of `trap:` validates.
        ok = Dict{String, Any}(
            "pipeline" => [
                Dict{String, Any}(
                    "ground_state" => Dict{String, Any}(
                        "atom" => "Rb87",
                        "grid" => Dict{String, Any}(
                            "n" => [16, 16, 16], "box" => [8.0, 8.0, 8.0]),
                        "potential" => Dict{String, Any}(
                            "type" => "harmonic", "omega" => [1.0, 1.0, 2.6]),
                    ),
                ),
            ],
        )
        validate_pipeline!(deepcopy(ok); strict=true)   # no throw

        # Top-level typo also errors in strict mode.
        bad_top = Dict{String, Any}(
            "pipline" => [],   # misspelt
            "pipeline" => [],
        )
        @test_throws ArgumentError validate_pipeline!(deepcopy(bad_top); strict=true)
    end
end
