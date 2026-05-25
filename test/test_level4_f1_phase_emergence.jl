# Level 4 — F=1 phase emergence from ITP under c₁ sign.
#
# Textbook spin-1 BEC physics (Kawaguchi-Ueda 2012 §3, Ohmi-Machida 1998,
# Ho 1998): for the energy functional
#
#   E_int = (c₀/2) n² + (c₁/2) |⟨F⟩|²
#
# the spin-mixing coefficient c₁ alone determines the magnetic ground
# state in the absence of Zeeman energy:
#
#   c₁ > 0  (antiferromagnetic interaction) → polar / nematic
#                                              |⟨F⟩|/n = 0
#                                              |A₀₀|²/n² = 1/3
#   c₁ < 0  (ferromagnetic interaction)     → ferromagnetic
#                                              |⟨F⟩|/n = 1
#                                              |A₀₀|²/n² ≈ 0
#
# Existing tests cover the initial-state algebra (test_singlet_pair.jl)
# and the SMA dynamics (test_spin_mixing.jl) but do NOT pin the
# emergence of the right phase from a generic initial state under ITP.
# A sign flip in the c₁ term or a missing factor in spin_mixing would
# silently move the GS to the wrong phase without tripping the existing
# regression suite.
#
# Cost: ~3-5 s per ITP at n=16 1D. Fast tier.

using Test
using SpinorBEC
using SpinorBEC: classify_phase, spin_matrices, bogoliubov_spectrum, BdGResult

@testset "Level 4 — F=1 phase emergence from c₁ sign" begin
    grid = make_grid(GridConfig{1}((16,), (8.0,)))
    sys = SpinSystem(1)
    sm = spin_matrices(1)

    # ITP from a seeded initial state at given c₁. Both find_ground_state
    # split_step ITP variants preserve N and Mz, so the seed selects
    # which symmetry sector we explore. The textbook claim "polar wins
    # at c₁>0, FM wins at c₁<0" is exactly the ENERGY ORDERING between
    # the polar-seed and m_plus_F-seed ITP results.
    function _itp_seeded(c1::Float64, seed_state::Symbol; q::Float64=0.0)
        find_ground_state(;
            grid, atom=Rb87,
            interactions=InteractionParams(5.0, c1),
            zeeman=ZeemanParams(0.0, q),
            potential=HarmonicTrap((1.0,)),
            n_steps=1000, dt=0.005, tol=1e-9,
            initial_state=seed_state,
        )
    end

    @testset "c₁ > 0: polar-seed energy < FM-seed energy" begin
        # Textbook: c₁>0 means polar is the GS. ITP from :polar stays
        # in the polar basin (Mz=0 sector dominated by m=0); ITP from
        # :m_plus_F stays in the FM basin (Mz=+F=+1 sector). The
        # textbook claim is that the polar energy is lower.
        r_polar = _itp_seeded(0.5, :polar)
        r_fm = _itp_seeded(0.5, :m_plus_F)
        @test r_polar.energy < r_fm.energy

        # The polar-seed result must keep small spin order (it's polar).
        psi_p = Array(r_polar.workspace.state.psi)
        info_p = classify_phase(psi_p, 1, grid, sm)
        @test info_p.spin_order < 0.05
    end

    @testset "c₁ < 0: FM-seed energy < polar-seed energy" begin
        # Textbook: c₁<0 → FM wins. Reverse ordering of c₁>0 test.
        r_polar = _itp_seeded(-0.5, :polar)
        r_fm = _itp_seeded(-0.5, :m_plus_F)
        @test r_fm.energy < r_polar.energy

        # The FM-seed result must keep saturated spin order.
        psi_f = Array(r_fm.workspace.state.psi)
        info_f = classify_phase(psi_f, 1, grid, sm)
        @test info_f.spin_order > 0.95
    end

    @testset "Energy gap scales with |c₁| (spin-mixing strength)" begin
        # Difference ΔE = E_FM_seed - E_polar_seed should be POSITIVE
        # and approximately proportional to |c₁| at c₁>0 (deeper c₁
        # makes polar more energetically favourable).
        gaps = Float64[]
        for c1 in (0.3, 0.6, 1.2)
            r_polar = _itp_seeded(c1, :polar)
            r_fm = _itp_seeded(c1, :m_plus_F)
            push!(gaps, r_fm.energy - r_polar.energy)
        end
        # All positive (polar wins).
        @test all(g -> g > 0, gaps)
        # Monotonically growing with c₁.
        @test gaps[1] < gaps[2] < gaps[3]
    end

    @testset "c₁ = 0 limit: degenerate (polar-seed ≈ FM-seed energy)" begin
        # With c₁=0, the spin term vanishes and polar/FM are
        # energetically degenerate (only c₀·n² density energy remains).
        # Both seeds should converge to the same density profile + E.
        r_polar = _itp_seeded(0.0, :polar)
        r_fm = _itp_seeded(0.0, :m_plus_F)
        @test isapprox(r_polar.energy, r_fm.energy; rtol=1e-4)
    end

    @testset "Zeeman q > 0 large: polar is forced even at c₁<0" begin
        # Large positive q penalises |m|=F components → polar wins
        # against FM regardless of c₁ sign.
        r_polar = _itp_seeded(-0.5, :polar; q=5.0)
        r_fm = _itp_seeded(-0.5, :m_plus_F; q=5.0)
        # q=5 dominates c₁=−0.5 → polar-seed (m=0) is the GS.
        @test r_polar.energy < r_fm.energy
        psi_p = Array(r_polar.workspace.state.psi)
        info_p = classify_phase(psi_p, 1, grid, sm)
        @test info_p.spin_order < 0.1
    end

    # ────────────────────────────────────────────────────────────────────
    # Stronger physics tests added 2026-05-25 in response to "are you
    # sure this is actually testing the physics?" audit. The weaker
    # energy-ordering tests above compare different Mz sectors; below
    # we test the actual Mz=0 sector minimum (polar saddle vs FM-x
    # broken-symmetry true GS) via LBFGS with target_Mz=0.
    # ────────────────────────────────────────────────────────────────────

    @testset "(a) Mz=0 sector: c₁<0 → FM-x beats polar saddle" begin
        # The Mz=0 polar state (ψ=(0,1,0)) is a SADDLE point at c₁<0:
        # ITP from it stays there because ⟨F⟩=0 makes the c₁ gradient
        # vanish. The true Mz=0 GS at c₁<0 is FM-x = (1,0,1)/√2, which
        # has ⟨F_x⟩=n and E_spin = (c₁/2)·n² < 0.
        #
        # To find it, we seed a polar state perturbed with a small
        # transverse component, then let LBFGS (which uses gradient
        # descent on the energy directly, not ITP) find the minimum.
        n_pt = 16
        L = 8.0
        atom = Rb87
        sys = SpinSystem(1)
        c1 = -0.5
        c0 = 5.0

        # Build a symmetry-broken seed: ψ ≈ ε·(1, √(1-2ε²), 1) with
        # equal real amplitudes on m=±1 → ⟨F_x⟩ > 0, Mz=0.
        psi_seed = zeros(ComplexF64, n_pt, 3)
        ε = 0.1
        for i in 1:n_pt
            x = grid.x[1][i]
            g = exp(-x^2 / (2 * 1.0^2))
            psi_seed[i, 1] = ε * g
            psi_seed[i, 2] = sqrt(1 - 2 * ε^2) * g
            psi_seed[i, 3] = ε * g
        end
        psi_seed ./= sqrt(sum(abs2, psi_seed) * cell_volume(grid))

        # LBFGS minimisation with Mz=0 enforced.
        r_fmx = find_ground_state_lbfgs(;
            grid, atom,
            interactions=InteractionParams(c0, c1),
            potential=HarmonicTrap((1.0,)),
            n_steps=400, tol=1e-9,
            target_magnetization=0.0,
            psi_init=psi_seed,
            verbose=false,
        )

        # The polar-saddle reference: pure ψ=(0,1,0).
        r_polar_saddle = _itp_seeded(c1, :polar)

        # FM-x must be LOWER than the polar saddle (true GS of Mz=0
        # sector at c₁<0).
        @test r_fmx.energy < r_polar_saddle.energy

        # The FM-x state must have high spin order.
        psi_fmx = Array(r_fmx.workspace.state.psi)
        info_fmx = classify_phase(psi_fmx, 1, grid, sm)
        @test info_fmx.spin_order > 0.95
        # And the magnetization (Mz=0 by constraint) but |⟨F_x⟩|/n ≈ 1.
        @test abs(info_fmx.magnetization_density) < 1e-6
    end

    @testset "(b) Energy gap matches analytic (c₁/2)·∫n²·dV" begin
        # Analytical: for polar (⟨F⟩=0) vs FM-up (|⟨F⟩|=n):
        #   E_FM - E_polar = (c₁/2)·∫n²·dV
        # Compute the predicted gap from the polar-seed density and
        # compare to the ITP gap from polar-seed vs m_plus_F-seed.
        n_pt = 16
        L = 8.0
        atom = Rb87
        c0 = 5.0
        for c1 in (0.3, 0.6, -0.5)
            r_polar = _itp_seeded(c1, :polar)
            r_fm = _itp_seeded(c1, :m_plus_F)

            # Density profile from polar-seed (Mz=0 → ψ=(0,√n,0))
            psi_polar = Array(r_polar.workspace.state.psi)
            n_dens = dropdims(sum(abs2, psi_polar; dims=2); dims=2)
            n_sq_integral = sum(n_dens .^ 2) * cell_volume(grid)

            gap_predicted = (c1 / 2) * n_sq_integral
            gap_measured = r_fm.energy - r_polar.energy

            # FM-seed density may differ slightly from polar-seed
            # density (different effective μ since spin energy enters
            # ITP termination criterion), so allow a few percent
            # tolerance. The DIRECTION (sign) must match exactly.
            @test sign(gap_predicted) == sign(gap_measured)
            # Magnitude within 5%.
            @test isapprox(gap_predicted, gap_measured;
                rtol=0.05, atol=1e-4)
        end
    end

    @testset "(c) Bogoliubov spectrum: polar stable at c₁>0, unstable at c₁<0" begin
        # Uniform polar spinor ζ=(0,1,0). At a given (c₀,c₁,n₀):
        #   density branch: ω² = ε_k(ε_k + 2c₀n₀)         (always stable)
        #   spin branch   : ω² = ε_k(ε_k + 2c₁n₀)         (unstable if c₁<0)
        # The spectrum analyzer must reflect this — c₁<0 should
        # produce max_growth_rate > 0 (instability).
        n0 = 1.0
        F = 1
        zeta_polar = ComplexF64[0.0, 1.0, 0.0]

        # c₁ > 0: polar stable. The BdGResult.unstable flag uses the
        # tight 1e-10 numerical threshold which fires on diagonalization
        # noise (~1e-8 for 6×6 eigensolve in F=1). Use 1e-5 here, which
        # is 100× below the c₁<0 instability rate measured below.
        bdg_stable = bogoliubov_spectrum(;
            spinor=zeta_polar, n0=n0, F=F,
            interactions=InteractionParams(2.0, 0.3),
            k_max=2.0, n_k=40,
        )
        @test bdg_stable.max_growth_rate < 1e-5

        # c₁ < 0: polar dynamically unstable. Max growth rate should
        # be ~ √(|c₁|·n₀) ≈ √0.3 ≈ 0.55 at long wavelengths. We
        # require growth > 1e-3 which is many orders above numerical noise.
        bdg_unstable = bogoliubov_spectrum(;
            spinor=zeta_polar, n0=n0, F=F,
            interactions=InteractionParams(2.0, -0.3),
            k_max=2.0, n_k=40,
        )
        @test bdg_unstable.unstable
        @test bdg_unstable.max_growth_rate > 1e-3
        # Stability separation: unstable max_growth is ≫ stable
        # max_growth, regardless of absolute tolerance.
        @test bdg_unstable.max_growth_rate > 100 * bdg_stable.max_growth_rate

        # Sound speed at long wavelength: c_s² ≈ c₀·n₀ for density
        # branch. Verify the lowest non-zero k mode has |ω| ~ √(2 c₀ n₀)·k
        # for small k.
        # (Skip detailed sound-speed extraction here — the unstable /
        #  stable distinction is the load-bearing assertion.)
    end

    @testset "(c') Bogoliubov spectrum: FM-up stable at c₁<0" begin
        # Uniform FM-up spinor ζ=(1,0,0). FM is the GS at c₁<0 so its
        # Bogoliubov spectrum must be real (no instability) — only the
        # numerical-noise floor. Cross-check by comparing against the
        # known-unstable polar at the same c₁<0.
        zeta_fm = ComplexF64[1.0, 0.0, 0.0]
        bdg_fm = bogoliubov_spectrum(;
            spinor=zeta_fm, n0=1.0, F=1,
            interactions=InteractionParams(2.0, -0.3),
            k_max=2.0, n_k=40,
        )
        zeta_polar = ComplexF64[0.0, 1.0, 0.0]
        bdg_polar = bogoliubov_spectrum(;
            spinor=zeta_polar, n0=1.0, F=1,
            interactions=InteractionParams(2.0, -0.3),
            k_max=2.0, n_k=40,
        )
        # FM growth rate at machine-noise floor; polar growth rate is
        # the macroscopic instability. They must be separated by orders.
        @test bdg_fm.max_growth_rate < 1e-5
        @test bdg_fm.max_growth_rate < bdg_polar.max_growth_rate / 1000
    end

    @testset "(d) target_Mz sweep: c₁<0 prefers extremal Mz, c₁>0 prefers Mz=0" begin
        # Sweep target_Mz = (0.0, 0.5, 1.0) at c₁<0 and at c₁>0.
        # At c₁<0 (FM): E should DECREASE as |Mz| → 1 (FM-up is GS).
        # At c₁>0 (polar): E should INCREASE as |Mz| → 1 (polar Mz=0 is GS).
        n_pt = 16
        atom = Rb87
        c0 = 5.0
        Mz_targets = (0.0, 0.5, 1.0)

        function _energy_at_Mz(c1, Mz)
            # Seed: uniform on m=+F + small population on m=0 to give
            # the constrained solver a starting point with the right Mz.
            psi_seed = zeros(ComplexF64, n_pt, 3)
            for i in 1:n_pt
                x = grid.x[1][i]
                g = exp(-x^2 / (2 * 1.0^2))
                # population on m=+1 = (1+Mz)/2, on m=-1 = (1-Mz)/2,
                # nothing on m=0 → ⟨F_z⟩/n = Mz.
                psi_seed[i, 1] = sqrt((1 + Mz) / 2) * g
                psi_seed[i, 3] = sqrt((1 - Mz) / 2) * g
            end
            psi_seed ./= sqrt(sum(abs2, psi_seed) * cell_volume(grid))
            r = find_ground_state_lbfgs(;
                grid, atom,
                interactions=InteractionParams(c0, c1),
                potential=HarmonicTrap((1.0,)),
                n_steps=300, tol=1e-8,
                target_magnetization=Mz,
                psi_init=psi_seed,
                verbose=false,
            )
            r.energy
        end

        # c₁ < 0 (FM-favored): energy monotonically decreases with |Mz|.
        E_neg = [_energy_at_Mz(-0.5, Mz) for Mz in Mz_targets]
        @test E_neg[1] > E_neg[2] > E_neg[3]

        # c₁ > 0 (polar-favored): energy monotonically increases with |Mz|.
        E_pos = [_energy_at_Mz(+0.5, Mz) for Mz in Mz_targets]
        @test E_pos[1] < E_pos[2] < E_pos[3]
    end

    @testset "(e) :antiferromagnetic naming caveat (not polar, has ⟨F_x⟩≠0)" begin
        # CAVEAT (state_zoo_yaml_integration_wip memory):
        # init_psi(F=1, :antiferromagnetic) produces ψ = (+1, -1, +1)/√3
        # which has ⟨F_x⟩ ∝ -√2/3 ≠ 0. Despite the name, this is NOT
        # the polar/antiferromagnetic phase but a finite-magnetization
        # state. Pin the actual physics so the misleading name doesn't
        # propagate into validation conclusions.
        psi_afm = init_psi(grid, sys; state=:antiferromagnetic)
        info = classify_phase(psi_afm, 1, grid, sm)
        # ⟨F_z⟩ = 0 (symmetric m=±1 populations) but |⟨F⟩| ≠ 0.
        @test abs(info.magnetization_density) < 1e-6
        @test info.spin_order > 0.1  # NOT a polar (which has spin_order=0)
    end
end
