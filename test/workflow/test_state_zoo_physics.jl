# State-zoo physical properties cause-isolation probes.
#
# `test_state_zoo_macro_equivalence.jl` verifies wrappers route to
# `init_psi` correctly, but it does NOT verify the wave functions
# actually have the claimed physical properties. If `init_psi(:cyclic)`
# returns the wrong spinor, the equivalence test still passes (both
# the wrapper and the direct call return the same wrong thing). This
# file pins the EXPECTED PHYSICS at each named state:
#
#   :polar (F=1)        ⟨F⟩ = 0, |A_00|² = n²/3
#   :m_plus_F           ⟨F⟩ = F·ẑ, A_00 = 0
#   :m_minus_F          ⟨F⟩ = -F·ẑ, A_00 = 0
#   :cyclic (F=2)       ⟨F⟩ = 0, A_00 = 0
#   :uniform            ⟨F⟩ = 0 (equal-weight spin components)

using Test
using SpinorBEC

@testset "state zoo: physical properties of named states" begin
    @testset ":m_plus_F → fully magnetised at m=+F" begin
        for F in (1, 2, 3, 6)
            D = 2F + 1
            grid = make_grid(GridConfig((8,), (4.0,)))
            sys = SpinSystem(F)
            psi = init_psi(grid, sys; state=:m_plus_F)
            sm = spin_matrices(F)

            fz_total = magnetization(psi, grid, sm.system)
            norm = total_norm(psi, grid)
            @test isapprox(fz_total / norm, F; rtol=1e-12)

            A = singlet_pair_amplitude(psi, F, 1)
            @test maximum(abs, A) < 1e-12
        end
    end

    @testset ":m_minus_F → fully magnetised at m=-F" begin
        for F in (1, 2, 3, 6)
            grid = make_grid(GridConfig((8,), (4.0,)))
            sys = SpinSystem(F)
            psi = init_psi(grid, sys; state=:m_minus_F)
            sm = spin_matrices(F)

            fz_total = magnetization(psi, grid, sm.system)
            norm = total_norm(psi, grid)
            @test isapprox(fz_total / norm, -F; rtol=1e-12)

            A = singlet_pair_amplitude(psi, F, 1)
            @test maximum(abs, A) < 1e-12
        end
    end

    @testset ":polar (F=1) → ⟨F⟩=0 and |A_00|²=n²/3" begin
        F = 1
        grid = make_grid(GridConfig((8,), (4.0,)))
        sys = SpinSystem(F)
        psi = init_psi(grid, sys; state=:polar)
        sm = spin_matrices(F)

        # ⟨F_z⟩ = 0 (polar has only ψ_0 component)
        fz_total = magnetization(psi, grid, sm.system)
        norm = total_norm(psi, grid)
        @test abs(fz_total / norm) < 1e-12

        # |A_00|² / n² = 1/D = 1/3
        A = singlet_pair_amplitude(psi, F, 1)
        n = total_density(psi, 1)
        @test sum(abs2, A) ≈ sum(n .^ 2) / 3 rtol = 1e-12
    end

    @testset ":cyclic (F=2): ⟨F⟩=0 but |A_00|²=1/5 (equal-phase trio, NOT T_d)" begin
        # IMPORTANT physical-naming caveat discovered 2026-05-25:
        # The init_psi(:cyclic) impl is the equal-amplitude phase trio
        # `(1, 0, e^{2π/3 i}, 0, e^{4π/3 i})/sqrt(3)` (see state_dispatch.jl
        # `elseif state == :cyclic`). This has ⟨F⟩=0 ✓ but |A_00|²=1/5,
        # i.e. it is NOT the T_d-symmetric "cyclic" of paper3 §V.A which
        # has A_00=0 strictly (representative
        # `ζ_T = (1/2, 0, i/√2, 0, 1/2)`).
        #
        # The discrepancy is intentional in spirit (init_psi seeds with
        # a quick heuristic for ITP to converge from) but the NAMING
        # collides with the paper3 PhaseReference for :cyclic. For
        # paper3-anchored work, construct ζ_T manually (see
        # test/hamiltonian/test_singlet_pair.jl
        # "F=2 cyclic state: A_00 = 0").
        F = 2
        grid = make_grid(GridConfig((8,), (4.0,)))
        sys = SpinSystem(F)
        psi = init_psi(grid, sys; state=:cyclic)
        sm = spin_matrices(F)

        # ⟨F⟩=0 still holds (the trio is m=±F + m=0 with cyclic phases)
        fz_total = magnetization(psi, grid, sm.system)
        norm = total_norm(psi, grid)
        @test abs(fz_total / norm) < 1e-12

        # |A_00|² = 1/5 — the heuristic trio has S=0 weight 1/D.
        # If a future refactor switches :cyclic to the T_d representative,
        # update this expectation to 0 and rename the testset.
        A = singlet_pair_amplitude(psi, F, 1)
        n = total_density(psi, 1)
        @test sum(abs2, A) ≈ sum(n .^ 2) / 5 rtol = 1e-12
    end

    @testset ":uniform → ⟨F⟩=0 (equal-weight)" begin
        for F in (1, 2)
            grid = make_grid(GridConfig((8,), (4.0,)))
            sys = SpinSystem(F)
            psi = init_psi(grid, sys; state=:uniform)
            sm = spin_matrices(F)

            fz_total = magnetization(psi, grid, sm.system)
            norm = total_norm(psi, grid)
            @test abs(fz_total / norm) < 1e-12
        end
    end

    @testset ":antiferromagnetic (F=1) → all-components alt-sign, ⟨F_z⟩=0" begin
        # CAVEAT: init_psi(:antiferromagnetic) is the all-components
        # ψ = sign(c) · gauss/sqrt(D)  with sign = (-1)^{F-m}, NOT the
        # 2-state (|+F⟩+|-F⟩)/sqrt(2) often called "AFM" in literature.
        # Specifically for F=1 this gives (1, -1, 1)·gauss/sqrt(3),
        # which has ⟨F_z⟩=0 but ⟨F_x⟩ ≠ 0 (i.e. |⟨F⟩|² ≠ 0, NOT a
        # singlet-pair / polar state).
        #
        # Useful as an ITP seed (spreads weight across components) but
        # NOT a phase-classification reference. For paper3 work use
        # :biaxial_nematic (which is the (|+F⟩+|-F⟩)/sqrt(2) state).
        F = 1
        grid = make_grid(GridConfig((8,), (4.0,)))
        sys = SpinSystem(F)
        psi = init_psi(grid, sys; state=:antiferromagnetic)
        sm = spin_matrices(F)

        # Robust: ⟨F_z⟩ = 0 (equal weights at ±1, sign cancels in F_z)
        fz_total = magnetization(psi, grid, sm.system)
        norm = total_norm(psi, grid)
        @test abs(fz_total / norm) < 1e-12

        # A_00 = (1/√D) Σ_c sign_c · ψ_c · ψ_{D-c+1}
        # For F=1: signs=(+1,−1,+1), pairs c↔(D−c+1)=(1↔3,2↔2,3↔1)
        # ψ = (1,−1,1)·gauss/√3 → A_00 = (1/√3)·(gauss²/3 − gauss²/3 + gauss²/3)
        # = (1/√3)·gauss²/3 → |A_00|² = gauss^4 / 27
        # → sum(|A_00|²) / sum(n²) = 1/27 (with n = gauss²)
        A = singlet_pair_amplitude(psi, F, 1)
        n = total_density(psi, 1)
        @test isapprox(sum(abs2, A), sum(n .^ 2) / 27; rtol=1e-12)
    end

    @testset ":biaxial_nematic (F=2) → ⟨F⟩=0 and |A_00|²=n²/5" begin
        # Biaxial nematic at F=2: ψ = (1/√2)(|+2⟩ + |-2⟩). Properties:
        #   ⟨F_z⟩ = 2·1/2 + (-2)·1/2 = 0
        #   ⟨F_x⟩, ⟨F_y⟩ = 0 (no adjacent components)
        #   A_00 = (1/√5)(2 · sign_1 · 1/2) = (1/√5)·1 → |A_00|² = 1/5
        # Per paper3 §VII.A this is the D_4 axial state at F=2.
        F = 2
        grid = make_grid(GridConfig((8,), (4.0,)))
        sys = SpinSystem(F)
        psi = init_psi(grid, sys; state=:biaxial_nematic)
        sm = spin_matrices(F)

        fz_total = magnetization(psi, grid, sm.system)
        norm = total_norm(psi, grid)
        @test abs(fz_total / norm) < 1e-12

        A = singlet_pair_amplitude(psi, F, 1)
        n = total_density(psi, 1)
        @test sum(abs2, A) ≈ sum(n .^ 2) / 5 rtol = 1e-12
    end

    @testset "all named states: normalised ∫|ψ|² dV = 1" begin
        # Sanity: every named state is normalised. Catches bugs in
        # init_psi normalization that would leak into ITP / dynamics.
        grid = make_grid(GridConfig((8,), (4.0,)))
        sys = SpinSystem(1)
        for state in (:polar, :m_plus_F, :m_minus_F, :uniform, :antiferromagnetic)
            psi = init_psi(grid, sys; state=state)
            @test isapprox(total_norm(psi, grid), 1.0; rtol=1e-12)
        end
    end
end
