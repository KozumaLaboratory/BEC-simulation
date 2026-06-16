# Truncated-Boltzmann evaporative-cooling model: unit + integration gates.
# Scalar ms-scale kinetics (no ITP/RTP) → fast tier.

using Test
using SpinorBEC
using SpinorBEC: GaussianBeam, CrossedDipoleTrap, Eu151, Units,
    rayleigh_range, beam_depth, beam_frequencies,
    crossed_trap_frequencies, mean_trap_frequency, crossed_trap_depth,
    EvapTrap, EvapParams, evap_rhs, phase_space_density, thermal_peak_density,
    evap_volume_factor,
    FortRamp, fort_power_at, trap_at, run_evaporation, evaporation_diagnostics,
    ramp_from_params,
    hfort_power, hfort_volts, vfort_power, vfort_volts, sfort_power, sfort_volts,
    euv3_evaporation_ramp,
    final_trap_frequencies, bec_handoff, harmonic_trap_dimless, HarmonicTrap, Units,
    bec_gp_coupling, bec_workspace_kwargs, InteractionParams,
    gravity_strength_dimless, CompositePotential, GravityPotential,
    euv3_evap_trap, run_euv3_evaporation, evaporation_summary,
    euv3_defaults, calibrate_polarizability, beam_frequencies,
    thermal_cloud_widths, thermal_cloud_density

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

# euv3-shaped ramp from the LOADED crossed trap (both FORTs on): H 2→0.099 W,
# V 1.8→0.09 W over 2.1 s. ω̄ decreases monotonically (the V-turn-on loading
# transient is excluded — it would adiabatically heat; see euv3_evaporation_ramp).
_euv3_ramp() = FortRamp(
    [0.0, 0.9, 1.5, 2.1],
    [2.0 0.56 0.16 0.099;
        1.8 1.6 1.0 0.09;
        0.0 0.0 0.0 0.0])

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

    @testset "collision rate is theory-determined (evap_scale = 1)" begin
        # at the Eu BEC loading point (PRL 129,223401: N=3.5e6, 50µK, ω̄=2π·432 Hz) the
        # peak density and PSD match the measured values ⇒ γ_el = n₀σv̄/√2 is fixed, no
        # free prefactor: evap_scale's physical value is 1.
        N, T, ω̄ = 3.5e6, 50e-6, 2π * (30 * 1500 * 1800)^(1 / 3)
        n0 = thermal_peak_density(N, T, ω̄, _m)
        @test n0 / 1e6 ≈ 3.3e13 rtol = 0.1                 # paper: 3.3×10¹³ cm⁻³
        @test phase_space_density(N, T, ω̄) ≈ 2.7e-4 rtol = 0.1  # paper: 2.7×10⁻⁴
        @test EvapParams(; a_s=_as, tau_bg=1.0).evap_scale == 1.0   # default = theory
        # evap_scale multiplies the rate linearly (it is a prefactor, not a knob to tune)
        ω, U = 2π * 200, 8.0 * Units.KB * 30e-6
        p1 = EvapParams(; a_s=_as, tau_bg=Inf, evap_scale=1.0)
        p2 = EvapParams(; a_s=_as, tau_bg=Inf, evap_scale=2.0)
        @test evap_rhs(1e6, 30e-6, U, ω, p2, _m)[1] ≈ 2 * evap_rhs(1e6, 30e-6, U, ω, p1, _m)[1]
    end

    @testset "evap_rhs scaling coefficient + thresholds" begin
        p = EvapParams(; a_s=_as, tau_bg=Inf, K3=0.0)   # evaporation only
        N, T, ω̄ = 1e6, 30e-6, 2π * 200
        η = 8.0
        U = η * Units.KB * T
        dN, dT = evap_rhs(N, T, U, ω̄, p, _m)
        @test dN < 0                                   # atoms leave
        # dT/T = (dN/N)(η+κ̃-3)/3 with the THEORETICAL κ̃(η) (not a constant)
        _, κ̃ = evap_volume_factor(η)
        @test (dT / dN) * (N / T) ≈ (η + κ̃ - 3) / 3 rtol = 1e-10
        @test 0 < κ̃ < 0.5                              # excess energy small + decreasing at high η
        # all-η Luiten form: still evaporates below η=4 (spilling), faster than at η=8
        dN_low, _ = evap_rhs(N, T, 3.0 * Units.KB * T, ω̄, p, _m)   # η = 3
        @test dN_low < 0                                # active (not inert)
        @test dN_low < dN                               # lower η ⇒ stronger loss
        # very deep trap ⇒ evaporation exponentially suppressed
        dN_deep, _ = evap_rhs(N, T, 20.0 * Units.KB * T, ω̄, p, _m)  # η = 20
        @test abs(dN_deep) < abs(dN) * 1e-3
        # evap_scale linearly scales the rate
        ps = EvapParams(; a_s=_as, tau_bg=Inf, K3=0.0, evap_scale=0.5)
        dN_s, _ = evap_rhs(N, T, U, ω̄, ps, _m)
        @test dN_s ≈ 0.5 * dN rtol = 1e-12
    end

    @testset "evap_volume_factor: 3D Luiten form, no free parameter" begin
        # 3D harmonic (a=3, P3/P4) recovers the textbook (η−4)e^{−η}; a 2-D mistake
        # (P2/P3) would give (η−3)e^{−η}. κ̃ → 0 at large η (evaporated atom carries ~ηkT).
        for η in (8.0, 10.0, 12.0)
            f, κ̃ = evap_volume_factor(η)
            @test f ≈ (η - 4) * exp(-η) rtol = 0.05
            @test 0 <= κ̃ < 0.1
        end
        @test evap_volume_factor(4.0)[2] > evap_volume_factor(8.0)[2]  # more excess at low η
        @test evap_volume_factor(3.0)[1] > 0                           # spilling at low η
        @test evap_volume_factor(15.0)[1] < evap_volume_factor(6.0)[1] # suppressed at high η
    end

    @testset "adiabatic trap change ⇒ T ∝ ω̄, ρ invariant" begin
        # pure compression/expansion (no evaporation, no loss): dT/T = dω̄/ω̄, so the
        # phase-space density is conserved — the oracle that forbids the optimizer's
        # "drop the trap then recompress for free" path.
        p = EvapParams(; a_s=_as, tau_bg=Inf, K3=0.0)
        N, T, ω̄ = 1e6, 1e-6, 2π * 100
        Udeep = 50.0 * Units.KB * T                      # η huge ⇒ evaporation inert
        for dlnω in (+0.5, -0.5)                         # compress / expand
            _, dT = evap_rhs(N, T, Udeep, ω̄, p, _m; dlnω_dt=dlnω)
            @test dT / T ≈ dlnω rtol = 1e-12             # dT/T = dω̄/ω̄
            # ρ = N(ℏω̄/kT)³ rate: dlnρ/dt = 3(dlnω̄ - dlnT) = 0 under pure adiabatic
            @test 3 * (dlnω - dT / T) ≈ 0.0 atol = 1e-12
        end
        # a ramp that drops the trap then re-tightens must NOT manufacture BEC:
        # without adiabatic heating the recompression spiked ρ across ζ(3) for free.
        trap = _eu_trap()
        recompress = FortRamp([0.0, 0.5, 1.0], [6.0 0.3 6.0; 0.0 0.3 6.0; 0.0 0.0 0.0])
        res = run_evaporation(trap, recompress, EvapParams(; a_s=_as, tau_bg=Inf, K3=0.0);
            N0=2e6, T0=40e-6)
        @test !res.reached_bec                           # recompression alone ≠ BEC
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

    @testset "evaporation_diagnostics figures of merit" begin
        trap = _eu_trap()
        p = EvapParams(; a_s=_as, tau_bg=10.0, K3=0.0)
        res = run_evaporation(trap, _euv3_ramp(), p; N0=2e6, T0=40e-6)
        d = evaporation_diagnostics(res, trap, p)
        @test d.eta_start ≈ res.eta[1]
        @test d.eta_min ≈ minimum(res.eta)
        @test d.runaway                                  # this config runs away to BEC
        @test d.collision_ratio_R > 1                    # elastic ≫ loss (here τ=10, K3=0)
        @test d.collisions_per_atom > 0
        @test d.gamma_el_peak >= d.gamma_el_start
        # R scales with the loss rate: shorter τ_bg ⇒ more bad events ⇒ lower R
        dτ = evaporation_diagnostics(
            run_evaporation(trap, _euv3_ramp(), EvapParams(; a_s=_as, tau_bg=1.0, K3=0.0);
                N0=2e6, T0=40e-6), trap, EvapParams(; a_s=_as, tau_bg=1.0, K3=0.0))
        @test dτ.collision_ratio_R < d.collision_ratio_R
        # a deep static trap never reaches BEC ⇒ not a runaway
        deep = run_evaporation(trap, FortRamp([0.0, 1.0], fill(50.0, 3, 2)), p;
            N0=2e6, T0=40e-6, dt=1e-3)
        @test !evaporation_diagnostics(deep, trap, p).runaway
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
        # raw logged schedule (from_loaded=false): full 6→0.14 W incl. the V turn-on
        raw = euv3_evaporation_ramp(; from_loaded=false)
        @test size(raw.powers_W, 1) == 3                      # H, V, S
        @test raw.times[end] ≈ 2.7
        @test raw.powers_W[1, 1] ≈ 6.0 && raw.powers_W[1, end] ≈ 0.14   # HFORT 6 → 0.14 W
        @test raw.powers_W[2, 1] ≈ 0.0 && raw.powers_W[2, end] ≈ 0.09   # VFORT 0 → 0.09 W
        @test all(==(0.0), raw.powers_W[3, :])                # SFORT off
        @test issorted(raw.times)
        # default ramp starts from the LOADED crossed trap (V turn-on dropped, retimed)
        r = euv3_evaporation_ramp()
        @test r.times[1] ≈ 0.0 && r.times[end] ≈ 2.4          # 2.7 − 0.3 loading segment
        @test r.powers_W[1, 1] ≈ 4.0 && r.powers_W[2, 1] ≈ 1.8   # both FORTs loaded
        @test r.powers_W[1, end] ≈ 0.14 && r.powers_W[2, end] ≈ 0.09
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

    @testset "thermal cloud spatial profile during evaporation" begin
        trap = _eu_trap()
        ramp = _euv3_ramp()
        res = run_evaporation(trap, ramp, EvapParams(; a_s=_as, tau_bg=10.0); N0=2e6, T0=40e-6)
        w = thermal_cloud_widths(trap, ramp, res)
        @test length(w.t) == length(res.t)
        @test all(>(0), w.sigma_bar) && all(>(0), w.n0)
        @test w.sigma_bar[end] < w.sigma_bar[1]        # cloud shrinks as it cools
        @test w.n0[end] > w.n0[1]                       # and densifies
        @test w.n0[1] ≈ res.N[1] / ((2π)^1.5 * w.sigma_x[1] * w.sigma_y[1] * w.sigma_z[1])
        # density snapshot integrates to N and peaks at n₀
        x, y, z, n = thermal_cloud_density(trap, ramp, res, 1; npts=41, span=4.0)
        dV = (x[2] - x[1]) * (y[2] - y[1]) * (z[2] - z[1])
        @test sum(n) * dV ≈ res.N[1] rtol = 0.05        # Gaussian integrates to N
        @test maximum(n) ≈ w.n0[1] rtol = 1e-9          # peak n₀ at the centre (odd npts)
    end

    # End-to-end validation against the lab NumberOfAtoms.csv requires the real
    # FORT waists / α / N₀ / T₀ from the experiment notebook — gated until supplied.
    @testset "euv3 measured N_BEC (needs lab inputs)" begin
        @test_skip false
    end
end
