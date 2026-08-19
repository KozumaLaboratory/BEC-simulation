# The ¹⁵¹Eu ↔ ¹⁵³Eu isotope map — #341 stage 1's load-bearing claim, as a gate.
#
# Campaign: docs/guides/eu_isotope_q_prediction.md.
#
# The claim is that the isotope enters the dimensionless Hamiltonian through EXACTLY
# three numbers — c_total (∝ √m), c_dd (∝ m^{3/2}) and q (∝ 1/Δ_hf) — and that the
# q ratio is exact, from measured hyperfine constants, with no scattering length in it.
# Every quantitative statement handed to the lab rests on that, so it is gated rather
# than restated: if a fourth channel for the isotope ever appears, this reddens.
#
# The structural half is a DIFFERENTIAL test with a negative control. "Two workspaces
# give the same energy" is only evidence if a workspace that SHOULD differ does — an
# energy comparison that cannot fail is the degenerate-knob trap, and this file would
# otherwise be the place to fall into it.

using Test
using SpinorBEC
using SpinorBEC: Units, Eu151, Eu153, eu_preset, eu151_preset, eu153_preset,
    quadratic_zeeman_si, quadratic_zeeman_dimless_si, compute_c_total,
    compute_c_dd_dimless, SpinSystem, init_psi, static_zeeman, make_workspace,
    SimParams, energy_decomposition, CPUBackend, bogoliubov_spectrum,
    InteractionParams, ZeemanParams

const OMEGA_REF = 2π * 110.0
const N_ATOMS = 50_000
const R_Q = Eu151.Delta_E_hf / Eu153.Delta_E_hf     # 2.278719…
const R_M = Eu153.mass / Eu151.mass

@testset "Eu isotope q map (#341)" begin
    @testset "q ratio is exact and field-independent" begin
        # q = (g_J μ_B B)² q_geom / Δ_hf, and the two isotopes share g_J and q_geom,
        # so the ratio is Δ₁₅₁/Δ₁₅₃ at EVERY field — not approximately, and with no
        # scattering length in it. This is the whole prediction.
        for B_tesla in (1e-10, 1e-8, 6.84e-9, 1e-5, 1e-4, 1e-2)
            @test quadratic_zeeman_si(Eu153, B_tesla) /
                  quadratic_zeeman_si(Eu151, B_tesla) ≈ R_Q rtol = 1e-14
        end
        @test R_Q ≈ 2.278719397363465 rtol = 1e-12

        # The collapse: ¹⁵³Eu sees ¹⁵¹Eu's q at 1/√R_Q of the field — a 34 % shift.
        collapse = sqrt(R_Q)
        @test collapse ≈ 1.5095427775864667 rtol = 1e-12
        for B in (1e-8, 1e-5, 1e-3)
            @test quadratic_zeeman_si(Eu153, B / collapse) ≈
                quadratic_zeeman_si(Eu151, B) rtol = 1e-14
        end

        # Sanity against the registry comment's SI figures (1.43 / ≈3.3 kHz/G²).
        q151_hz = quadratic_zeeman_si(Eu151, 1e-4) / (2π * Units.HBAR)
        q153_hz = quadratic_zeeman_si(Eu153, 1e-4) / (2π * Units.HBAR)
        @test q151_hz ≈ 1421.4758 rtol = 1e-6
        @test q153_hz ≈ 3239.1445 rtol = 1e-6
    end

    @testset "the other two numbers are the mass, and only the mass" begin
        c1 = compute_c_total(Eu151; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
        c3 = compute_c_total(Eu153; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
        d1 = compute_c_dd_dimless(Eu151; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
        d3 = compute_c_dd_dimless(Eu153; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
        @test c3 / c1 ≈ sqrt(R_M) rtol = 1e-12          # 1.00661
        @test d3 / d1 ≈ R_M^1.5 rtol = 1e-12            # 1.01996
        @test (d3 / c3) / (d1 / c1) ≈ R_M rtol = 1e-12  # ε_dd, 1.01326
        # Both corrections are ≤ 2 %, which is what makes the 128 % q difference the
        # signal and these the width of the prediction rather than a competitor.
        @test 1.006 < c3 / c1 < 1.007
        @test 1.019 < d3 / d1 < 1.021
    end

    @testset "eu_preset carries the isotope into the couplings" begin
        P1 = eu_preset(Eu151; n_atoms=N_ATOMS, omega_ref=OMEGA_REF)
        P3 = eu_preset(Eu153; n_atoms=N_ATOMS, omega_ref=OMEGA_REF)
        @test P3.interactions.c[0] / P1.interactions.c[0] ≈ sqrt(R_M) rtol = 1e-12
        @test P3.interactions.c[1] / P1.interactions.c[1] ≈ sqrt(R_M) rtol = 1e-12
        @test P3.c_dd / P1.c_dd ≈ R_M^1.5 rtol = 1e-12
        # The named wrappers are the general constructor, not a fork.
        @test eu151_preset().interactions.c == P1.interactions.c
        @test eu153_preset().c_dd == P3.c_dd
        # a_s override exists because a_s(¹⁵³Eu) is an unmeasured placeholder.
        @test eu_preset(Eu153; n_atoms=N_ATOMS, omega_ref=OMEGA_REF,
            a_s=1.1 * Eu153.a_s).interactions.c[0] ≈ 1.1 * P3.interactions.c[0] rtol = 1e-12
    end

    @testset "nothing else about the isotope reaches the energy" begin
        # Hand both isotopes the SAME (interactions, c_dd, zeeman, grid, potential).
        # If the atom is only those three numbers, the energy cannot tell them apart.
        #
        # The box is deliberately ANISOTROPIC. `init_psi` builds its Gaussian from
        # `box/8` per axis, so a cubic box gives a spherical cloud — and a uniformly
        # magnetized spherical cloud has exactly zero dipolar energy, which makes the
        # comparison below blind to c_dd. The negative control caught that on
        # 2026-08-19; without it this testset passed while measuring nothing.
        P = eu_preset(Eu151; n_pts=(8, 8, 8), box=(12.0, 12.0, 6.0), n_atoms=N_ATOMS,
            omega_ref=OMEGA_REF)
        sys = SpinSystem(6)
        psi = init_psi(P.grid, sys; state=:m_plus_F)
        sp = SimParams(; dt=1e-3, n_steps=1, imaginary_time=false)
        E(atom; c_dd=P.c_dd) = energy_decomposition(
            make_workspace(;
                grid=P.grid, atom=atom, interactions=P.interactions, potential=P.potential,
                zeeman=static_zeeman(; Bz=0.05, Bx=0.0, q=0.3), enable_ddi=true, c_dd=c_dd,
                secular_ddi=true, backend=CPUBackend(), psi_init=copy(psi), sim_params=sp,
            ),
        ).total
        @test E(Eu153) ≈ E(Eu151) rtol = 1e-14

        # NEGATIVE CONTROL. Without this, the equality above is satisfied by an energy
        # that ignores its arguments, and the test would pass with the whole DDI path
        # deleted. Move one of the three numbers and the same comparison must fail.
        @test !isapprox(E(Eu151; c_dd=1.02 * P.c_dd), E(Eu151); rtol=1e-6)
    end

    @testset "the quadratic Zeeman is along the FIELD axis, not ẑ" begin
        # q(b̂·F)², not q F_z². This is correct physics — second-order perturbation
        # theory quantises along B — and it is the trap that made a q-scan read as
        # "q does nothing" on 2026-08-19: with bz = 0 and a transverse pin, b̂ lies in
        # the plane, so the ground state relaxes to the nematic along x, which has
        # ⟨F_z²⟩ = F(F+1)/2 = 21 and Zeeman energy ≈ 0.
        P = eu_preset(Eu151; n_pts=(8, 8, 8), box=(12.0, 12.0, 12.0), n_atoms=N_ATOMS,
            omega_ref=OMEGA_REF)
        sys = SpinSystem(6)
        psi = init_psi(P.grid, sys; state=:m_plus_F)     # ⟨F_z²⟩ = 36 exactly
        sp = SimParams(; dt=1e-3, n_steps=1, imaginary_time=false)
        zee_E(; Bx, q) = energy_decomposition(
            make_workspace(;
                grid=P.grid, atom=Eu151, interactions=P.interactions, potential=P.potential,
                zeeman=static_zeeman(; Bz=0.0, Bx=Bx, q=q), enable_ddi=false,
                backend=CPUBackend(), psi_init=copy(psi), sim_params=sp,
            ),
        ).zeeman
        # b̂ = ẑ (no transverse): the diagonal branch, q·m² with m = F.
        @test zee_E(; Bx=0.0, q=2.0) ≈ 2.0 * 36 rtol = 1e-12
        # b̂ = x̂: the same q now multiplies ⟨F_x²⟩ = F/2 = 3 for the m = +F state.
        @test zee_E(; Bx=1e-6, q=2.0) ≈ 2.0 * 3 rtol = 1e-4
    end

    @testset "the |m| ≥ 2 magnons of the polar state are exactly q·m²" begin
        # This is why the isotope ratio is a_S-free rather than merely a_S-insensitive:
        # under the c₀/c₁ truncation, F·F connects m = 0 only to m = ±1, so every other
        # magnon is a bare Zeeman splitting that no interaction shifts — with the DDI
        # switched on, at c_dd = 211.
        P = eu_preset(Eu151; n_atoms=N_ATOMS, omega_ref=OMEGA_REF)
        z = zeros(ComplexF64, 13)
        z[7] = 1.0
        n0 = 0.005
        modes(q; ip=P.interactions) = sort(
            real.(
                bogoliubov_spectrum(; spinor=z, n0=n0,
                    F=6, interactions=ip, zeeman=ZeemanParams(0.0, q), c_dd=P.c_dd,
                    k_max=1.0, n_k=3).omega[
                    :, 1
                ],
            ),
        )
        for q in (0.05, 1.0)
            w = modes(q)
            for m in 2:6
                @test any(x -> isapprox(x, q * m^2; rtol=1e-9, atol=1e-12), w)
            end
        end

        # NEGATIVE CONTROL, and the caveat the campaign has to carry: a higher-rank
        # channel has no such selection rule. It adds an isotope-independent offset δ,
        # so the modes stay ∝ m² but with q → q + δ, and the same-field ratio is no
        # longer R_Q. Eu has seven unknown even channels; this is measured, not assumed.
        ip2 = InteractionParams(Dict(0 => P.interactions.c[0], 1 => P.interactions.c[1],
            2 => 6.5))
        w2 = modes(0.05; ip=ip2)
        @test !any(x -> isapprox(x, 0.05 * 36; rtol=1e-6), w2)
    end
end
