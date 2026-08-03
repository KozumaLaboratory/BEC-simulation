using Test
using LinearAlgebra
using SpinorBEC
using SpinorBEC: OpticalPumpingParams, build_sigma_eff_table, polarization_q

@testset "Optical pumping rate equation" begin
    @testset "polarization_q dispatch" begin
        @test polarization_q(:sigma_plus) == +1
        @test polarization_q(:sigma_minus) == -1
        @test polarization_q(:pi) == 0
        @test_throws ArgumentError polarization_q(:bogus)
    end

    @testset "F=1 σ⁺ stretched state cycles indefinitely (closed cycling)" begin
        # m=+1 atom under σ⁺ stays in m=+1, photon count = (s/2)·L·τ
        p = OpticalPumpingParams(F_ground=1, polarization=:sigma_plus,
            saturation=0.5, detuning_over_gamma=0.0, t_pulse_gamma=10.0)
        sigma_eff = build_sigma_eff_table(p)
        @test sigma_eff[3] ≈ 0.5 * 0.5 * 1.0 * 10.0 atol = 1e-10
    end

    @testset "F=1 σ⁺ short-pulse linear limit recovers CG² ratios" begin
        # Linear regime: σ_eff[m] = (s/2)·|C(F,m,+1)|²·τ
        # F=1, q=+1: |C|² = {1/6, 1/2, 1} for m = {-1, 0, +1}
        p = OpticalPumpingParams(F_ground=1, polarization=:sigma_plus,
            saturation=0.001, detuning_over_gamma=0.0, t_pulse_gamma=0.001)
        sigma_eff = build_sigma_eff_table(p)
        @test sigma_eff[3] / sigma_eff[2] ≈ 2.0 atol = 1e-4
        @test sigma_eff[3] / sigma_eff[1] ≈ 6.0 atol = 1e-4
    end

    @testset "Lorentzian detuning suppression" begin
        # L(Δ=Γ/2) / L(0) = 1 / (1 + 4·0.25) = 1/2
        p_res = OpticalPumpingParams(F_ground=1, polarization=:sigma_plus,
            saturation=0.001, detuning_over_gamma=0.0, t_pulse_gamma=0.001)
        p_off = OpticalPumpingParams(F_ground=1, polarization=:sigma_plus,
            saturation=0.001, detuning_over_gamma=0.5, t_pulse_gamma=0.001)
        @test build_sigma_eff_table(p_off)[3] /
              build_sigma_eff_table(p_res)[3] ≈ 0.5 atol = 1e-4
    end

    @testset "F=6 σ⁺ stretched state (m=+6) cycles" begin
        p = OpticalPumpingParams(F_ground=6, polarization=:sigma_plus,
            saturation=0.3, detuning_over_gamma=0.0, t_pulse_gamma=20.0)
        sigma_eff = build_sigma_eff_table(p)
        @test sigma_eff[13] ≈ 0.5 * 0.3 * 1.0 * 20.0 atol = 1e-10
    end

    @testset "F=6 σ⁺ short-pulse linear ratio = 91" begin
        # |C(6,+6,+1)|² = 13·14/(13·14) = 1
        # |C(6,-6,+1)|² = 1·2/(13·14) = 1/91
        p = OpticalPumpingParams(F_ground=6, polarization=:sigma_plus,
            saturation=0.001, detuning_over_gamma=0.0, t_pulse_gamma=0.001)
        sigma_eff = build_sigma_eff_table(p)
        @test sigma_eff[13] / sigma_eff[1] ≈ 91.0 rtol = 1e-3
    end

    @testset "σ⁺/σ⁻ reflection symmetry under m → -m" begin
        # σ⁺ pumps toward m=+F, σ⁻ toward m=-F.
        # σ_eff under σ⁺ at m must equal σ_eff under σ⁻ at -m.
        p_plus = OpticalPumpingParams(F_ground=6, polarization=:sigma_plus,
            saturation=0.3, detuning_over_gamma=0.0, t_pulse_gamma=5.0)
        p_minus = OpticalPumpingParams(F_ground=6, polarization=:sigma_minus,
            saturation=0.3, detuning_over_gamma=0.0, t_pulse_gamma=5.0)
        @test build_sigma_eff_table(p_plus) ≈
            reverse(build_sigma_eff_table(p_minus)) atol = 1e-10
    end

    @testset "Population conservation (table is non-negative & finite)" begin
        # No m_init should yield negative σ_eff or NaN under any reasonable params
        for F in (1, 2, 3, 6), pol in (:sigma_plus, :sigma_minus, :pi),
            s in (0.05, 0.5), tpg in (0.5, 50.0)

            p = OpticalPumpingParams(F_ground=F, polarization=pol,
                saturation=s, detuning_over_gamma=0.0, t_pulse_gamma=tpg)
            tab = build_sigma_eff_table(p)
            @test all(isfinite, tab)
            @test all(>=(0.0), tab)
            @test length(tab) == 2F + 1
        end
    end

    @testset "σ⁺ pumping: σ_eff strictly monotonic in m" begin
        # Closer to stretched (m=+F) ⇒ less pumping required ⇒ more photons.
        p = OpticalPumpingParams(F_ground=6, polarization=:sigma_plus,
            saturation=0.3, detuning_over_gamma=0.0, t_pulse_gamma=20.0)
        tab = build_sigma_eff_table(p)
        for i in 1:12
            @test tab[i + 1] > tab[i]
        end
    end

    @testset "Long-pulse: ratio σ_eff[m_init]/σ_eff[stretched] approaches 1" begin
        # Pumping bottleneck for F=6 σ⁺ from m=-F: |C(-F,+1)|² = 1/91, so the
        # m=-6 atom waits ~ 91/(s/2 · L) in dimensionless time before each
        # forward step. Full cascade convergence to within a few percent of
        # stretched requires τ ≳ 2·10⁴.
        ratios = Float64[]
        for tau in (200.0, 2000.0, 20000.0)
            p = OpticalPumpingParams(F_ground=6, polarization=:sigma_plus,
                saturation=0.3, detuning_over_gamma=0.0, t_pulse_gamma=tau)
            tab = build_sigma_eff_table(p)
            push!(ratios, tab[1] / tab[13])
        end
        @test ratios[1] < ratios[2] < ratios[3]   # τ-monotonic improvement
        @test ratios[3] > 0.9                     # asymptotic convergence
    end
end
