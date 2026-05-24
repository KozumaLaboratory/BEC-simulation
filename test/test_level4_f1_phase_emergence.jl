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
using SpinorBEC: classify_phase, spin_matrices

@testset "Level 4 — F=1 phase emergence from c₁ sign" begin
    grid = make_grid(GridConfig{1}((16,), (8.0,)))
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
end
