# Truncated-Boltzmann evaporative-cooling model: unit + integration gates.
# Scalar ms-scale kinetics (no ITP/RTP) → fast tier.

using Test
using SpinorBEC
using SpinorBEC: GaussianBeam, CrossedDipoleTrap, Eu151, Units,
    rayleigh_range, beam_depth, beam_frequencies,
    crossed_trap_frequencies, mean_trap_frequency, crossed_trap_depth,
    EvapTrap, EvapParams, evap_rhs, phase_space_density,
    FortRamp, fort_power_at, trap_at, run_evaporation,
    ramp_from_params,
    hfort_power, hfort_volts, vfort_power, vfort_volts, sfort_power, sfort_volts,
    euv3_evaporation_ramp,
    final_trap_frequencies, bec_handoff, harmonic_trap_dimless, HarmonicTrap, Units,
    bec_gp_coupling, bec_workspace_kwargs, InteractionParams,
    gravity_strength_dimless, CompositePotential, GravityPotential,
    euv3_evap_trap, run_euv3_evaporation, evaporation_summary,
    euv3_defaults, calibrate_polarizability, beam_frequencies

const _λ = 1064e-9
const _w0 = 30e-6
const _α = 2.0e-36
const _m = Eu151.mass
const _as = Eu151.a_s

_eu_trap() = EvapTrap(;
    wavelength=_λ, alpha=_α, waists=[_w0, _w0, _w0],
    directions=[(1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)],
    positions=[(0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)],
    mass=_m, gravity_axis=3)

# euv3-shaped ramp (H 6→0.099 W, V 0→0.09 W, S 0, over 2.7 s)
_euv3_ramp() = FortRamp(
    [0.0, 0.6, 1.5, 2.1, 2.7],
    [6.0 2.0 0.56 0.16 0.099;
        0.0 1.8 1.6 1.0 0.09;
        0.0 0.0 0.0 0.0 0.0])

@testset "Evaporative cooling (truncated Boltzmann)" begin
    @testset "single-beam geometry vs closed form" begin
        b = GaussianBeam(_λ, 1.0, _w0, (0.0, 0.0, 0.0), (1.0, 0.0, 0.0))
        @test rayleigh_range(b) ≈ π * _w0^2 / _λ
        @test beam_depth(b, _α) ≈ _α * 2 * 1.0 / (π * _w0^2)
        U0 = beam_depth(b, _α)
        ωr, ωax = beam_frequencies(b, _α, _m)
        @test ωr ≈ sqrt(4U0 / (_m * _w0^2))
        @test ωax ≈ sqrt(2U0 / (_m * rayleigh_range(b)^2))
        @test ωr > 50 * ωax            # radial confinement ≫ axial for a Gaussian beam
        # zero power ⇒ zero depth/frequencies
        @test beam_frequencies(
            GaussianBeam(_λ, 0.0, _w0, (0.0, 0.0, 0.0), (1.0, 0.0, 0.0)), _α, _m
        ) == (0.0, 0.0)
    end

    @testset "phase-space density formula" begin
        N, T, ω̄ = 1e5, 1e-6, 2π * 100
        @test phase_space_density(N, T, ω̄) ≈ N * (Units.HBAR * ω̄ / (Units.KB * T))^3
    end

    @testset "evap_rhs scaling coefficient + thresholds" begin
        p = EvapParams(; a_s=_as, tau_bg=Inf, K3=0.0, kappa=1.0)   # evaporation only
        N, T, ω̄ = 1e6, 30e-6, 2π * 200
        η = 8.0
        U = η * Units.KB * T
        dN, dT = evap_rhs(N, T, U, ω̄, p, _m)
        @test dN < 0                                   # atoms leave
        # dT/T = (dN/N)(η+κ-3)/3  ⇒  (dT/dN)(N/T) = (η+κ-3)/3
        @test (dT / dN) * (N / T) ≈ (η + 1.0 - 3) / 3 rtol = 1e-10
        # below the validity floor evaporation is inert (only bg+3b, here both off)
        Ulow = 3.0 * Units.KB * T                       # η = 3 < eta_min
        dN_low, _ = evap_rhs(N, T, Ulow, ω̄, p, _m)
        @test dN_low ≈ 0.0 atol = 1e-6
    end

    @testset "no-loss frozen limit (N, T constant)" begin
        trap = _eu_trap()
        # constant deep trap (η huge) + no background/3-body ⇒ nothing happens
        ramp = FortRamp([0.0, 1.0], [50.0 50.0; 50.0 50.0; 50.0 50.0])
        p = EvapParams(; a_s=_as, tau_bg=Inf, K3=0.0)
        res = run_evaporation(trap, ramp, p; N0=1e6, T0=1e-6, dt=1e-3)
        @test res.N[end] ≈ res.N[1] rtol = 1e-6
        @test res.T[end] ≈ res.T[1] rtol = 1e-6
        @test !res.reached_bec
    end

    @testset "background loss alone decays N exponentially" begin
        trap = _eu_trap()
        ramp = FortRamp([0.0, 1.0], [50.0 50.0; 50.0 50.0; 50.0 50.0])  # deep ⇒ no evap
        τ = 2.0
        p = EvapParams(; a_s=_as, tau_bg=τ, K3=0.0)
        res = run_evaporation(trap, ramp, p; N0=1e6, T0=1e-6, dt=1e-3)
        @test res.N[end] ≈ 1e6 * exp(-1.0 / τ) rtol = 1e-3
    end

    @testset "euv3-shaped ramp cools and reaches BEC" begin
        trap = _eu_trap()
        p = EvapParams(; a_s=_as, tau_bg=10.0, K3=0.0)
        res = run_evaporation(trap, _euv3_ramp(), p; N0=2e6, T0=40e-6)
        @test res.reached_bec
        @test res.T[end] < res.T[1]                    # cooling
        @test res.psd[end] > res.psd[1]                # PSD rises
        @test res.N[end] < res.N[1]                    # atoms evaporated
        @test 1 < res.N_BEC < 2e6
        @test res.gamma_eff > 1                        # efficient (PSD↑ per atom lost)
        @test phase_space_density(res.N_BEC, res.T_BEC, res.omega_bar[end]) ≈ 1.202 rtol = 0.1
    end

    @testset "gravity lowers the trap depth" begin
        # m enters crossed_trap_depth only through the gravity term, so a heavier
        # atom (or larger g) lowers the barrier; tiny m ≈ the pure-optical depth.
        beams(P) = [GaussianBeam(_λ, P, _w0, (0.0, 0.0, 0.0), (1.0, 0.0, 0.0)),
            GaussianBeam(_λ, P, _w0, (0.0, 0.0, 0.0), (0.0, 1.0, 0.0)),
            GaussianBeam(_λ, P, _w0, (0.0, 0.0, 0.0), (0.0, 0.0, 1.0))]
        strong = CrossedDipoleTrap(beams(6.0), _α)
        weak = CrossedDipoleTrap(beams(0.1), _α)
        r_strong = crossed_trap_depth(strong, _m) / crossed_trap_depth(strong, 1e-30)
        r_weak = crossed_trap_depth(weak, _m) / crossed_trap_depth(weak, 1e-30)
        @test r_strong < 1.0                  # gravity (∝ m) lowers the barrier
        @test r_weak < 1.0
        @test r_weak < r_strong               # the shallow trap is hurt more by gravity
    end

    @testset "ramp_from_params is a valid transform" begin
        base = _euv3_ramp()
        r = ramp_from_params([2.0, 0.5, 1.5], base)
        @test issorted(r.times)
        @test r.times[end] - r.times[1] ≈ 2.0 * (base.times[end] - base.times[1])
        @test r.powers_W[1, end] ≈ 0.5 * base.powers_W[1, end]
        @test fort_power_at(r, r.times[1]) ≈ r.powers_W[:, 1]
    end

    @testset "euv3 FORT calibration + evaporation ramp" begin
        # power ↔ voltage invertibility per beam
        for P in (0.099, 1.0, 6.0)
            @test hfort_power(hfort_volts(P)) ≈ P rtol = 1e-12
            @test vfort_power(vfort_volts(P)) ≈ P rtol = 1e-12
            @test sfort_power(sfort_volts(P)) ≈ P rtol = 1e-12
        end
        @test hfort_volts(6.0) ≈ (6.0 + 0.0010) / 0.6198      # transcribed constant
        # the lab ramp
        r = euv3_evaporation_ramp()
        @test size(r.powers_W, 1) == 3                        # H, V, S
        @test r.times[end] ≈ 2.7
        @test r.powers_W[1, 1] ≈ 6.0 && r.powers_W[1, end] ≈ 0.14   # HFORT 6 → 0.14 W
        @test r.powers_W[2, 1] ≈ 0.0 && r.powers_W[2, end] ≈ 0.09   # VFORT 0 → 0.09 W
        @test all(==(0.0), r.powers_W[3, :])                  # SFORT off
        @test issorted(r.times)
        # drives the model to BEC just like the hand-written ramp
        res = run_evaporation(_eu_trap(), r,
            EvapParams(; a_s=_as, tau_bg=10.0, K3=0.0); N0=2e6, T0=40e-6)
        @test res.reached_bec
    end

    @testset "BEC handoff → dimensionless GP trap" begin
        trap = _eu_trap()
        ramp = _euv3_ramp()
        res = run_evaporation(trap, ramp, EvapParams(; a_s=_as, tau_bg=10.0); N0=2e6, T0=40e-6)
        h = bec_handoff(trap, ramp, res)
        # default ω_ref = geometric mean ⇒ dimensionless ω̄ = 1
        @test cbrt(prod(h.omega_dimless)) ≈ 1.0 rtol = 1e-9
        @test h.a_ho ≈ sqrt(Units.HBAR / (trap.mass * h.omega_ref))
        @test h.N_BEC == res.N_BEC
        @test 0.5 < h.T_over_Tc < 2.0              # at onset T_BEC ≈ T_c
        # explicit ω_ref rescales
        h2 = bec_handoff(trap, ramp, res; omega_ref=2π * 100)
        @test h2.omega_ref ≈ 2π * 100
        ht = harmonic_trap_dimless(trap, ramp, res)
        @test ht isa HarmonicTrap
        ωx, ωy, ωz = final_trap_frequencies(trap, ramp)
        @test all(>(0), (ωx, ωy, ωz))
    end

    @testset "bec_workspace_kwargs (evaporation → GP bridge)" begin
        trap = _eu_trap()
        ramp = _euv3_ramp()
        res = run_evaporation(trap, ramp, EvapParams(; a_s=_as, tau_bg=10.0); N0=2e6, T0=40e-6)
        @test bec_gp_coupling(1e5, 1e-6; a_s=_as) ≈ 4π * 1e5 * _as / 1e-6
        kw = bec_workspace_kwargs(trap, ramp, res)
        @test kw.potential isa HarmonicTrap
        @test kw.atom === Eu151
        @test kw.interactions isa InteractionParams
        @test kw.c0 > 0                                # repulsive BEC (a_s > 0)
        @test kw.c0 ≈ 4π * res.N_BEC * _as / kw.a_ho   # dimensionless contact coupling
        @test kw.N_BEC == res.N_BEC
        # gravity sag: g̃ = m g a_ho / (ℏ ω_ref); ~10.7 in a 200 Hz Eu trap
        ω = 2π * 200
        @test gravity_strength_dimless(ω) ≈
            Eu151.mass * 9.80665 * sqrt(Units.HBAR / (Eu151.mass * ω)) / (Units.HBAR * ω)
        @test gravity_strength_dimless(ω) > 5            # sizeable sag at 200 Hz
        kwg = bec_workspace_kwargs(trap, ramp, res; gravity=true)
        @test kwg.potential isa CompositePotential
        @test length(kwg.potential.components) == 2
        @test any(p -> p isa GravityPotential, kwg.potential.components)
    end

    @testset "euv3 yokoyoko trap config" begin
        t = euv3_evaporation_ramp()                       # :tateyoko default
        y = euv3_evaporation_ramp(; config=:yokoyoko)
        @test t.powers_W[1, end] ≈ 0.14 && t.powers_W[3, end] ≈ 0.0   # tateyoko: SFORT off
        @test y.powers_W[1, end] ≈ 0.036                  # yokoyoko: HFORT lower
        @test y.powers_W[2, end] ≈ 0.0                    # VFORT off
        @test y.powers_W[3, end] ≈ 1.2                    # SFORT on
        @test t.times == y.times                          # same breakpoints
        @test_throws ArgumentError euv3_evaporation_ramp(; config=:bogus)
    end

    @testset "euv3 one-call convenience + summary" begin
        # scalar waist applies to all three beams
        trap = euv3_evap_trap(; waists=_w0, alpha=_α)
        @test length(trap.waists) == 3 && all(==(_w0), trap.waists)
        @test trap.mass == Eu151.mass
        res = run_euv3_evaporation(; waists=_w0, alpha=_α, N0=2e6, T0=40e-6, K3=0.0)
        @test res.reached_bec
        s = evaporation_summary(res)
        @test s.reached_bec
        @test s.N_BEC == res.N_BEC
        @test s.T_BEC_uK ≈ res.T_BEC * 1e6
        @test 0 < s.survival < 1                       # atoms lost but some survive
        @test s.peak_psd >= 1.202                      # crossed BEC onset
    end

    @testset "euv3 researched defaults reach BEC" begin
        d = euv3_defaults()
        @test d.wavelength == 1550e-9
        @test length(d.waists) == 3
        # no-arg run uses the researched defaults (1550 nm, 31/42 µm, calibrated α,
        # N₀=3.5e6 @ 50 µK, K3 fitted) and reproduces the measured BEC endpoint within ~3×.
        res = run_euv3_evaporation()
        @test res.reached_bec
        @test 0.3 < res.N_BEC / d.measured_N_BEC < 3.0   # ≈ measured 5.0e4
        @test 0.3 < res.T_BEC / d.measured_T_BEC < 3.0   # ≈ measured 349 nK
        # α calibration is self-consistent: build a beam at α, measure ω_r, recover α
        b = GaussianBeam(d.wavelength, 1.2, 42e-6, (0.0, 0.0, 0.0), (0.0, 0.0, 1.0))
        ωr, _ = beam_frequencies(b, d.alpha, Eu151.mass)
        @test calibrate_polarizability(; waist=42e-6, power_W=1.2, freq_Hz=ωr / 2π) ≈ d.alpha rtol =
            1e-9
    end

    # End-to-end validation against the lab NumberOfAtoms.csv requires the real
    # FORT waists / α / N₀ / T₀ from the experiment notebook — gated until supplied.
    @testset "euv3 measured N_BEC (needs lab inputs)" begin
        @test_skip false
    end
end
