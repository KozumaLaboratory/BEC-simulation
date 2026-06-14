# Truncated-Boltzmann evaporative-cooling model: unit + integration gates.
# Scalar ms-scale kinetics (no ITP/RTP) → fast tier.

using Test
using SpinorBEC
using SpinorBEC: GaussianBeam, CrossedDipoleTrap, Eu151, Units,
    rayleigh_range, beam_depth, beam_frequencies,
    crossed_trap_frequencies, mean_trap_frequency, crossed_trap_depth,
    EvapTrap, EvapParams, evap_rhs, phase_space_density,
    FortRamp, fort_power_at, trap_at, run_evaporation,
    ramp_from_params, optimize_evaporation_ramp,
    hfort_power, hfort_volts, vfort_power, vfort_volts, sfort_power, sfort_volts,
    euv3_evaporation_ramp,
    final_trap_frequencies, bec_handoff, harmonic_trap_dimless, HarmonicTrap, Units

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
        U0_strong = crossed_trap_depth(strong, 1e-30)        # gravity ≈ off
        @test crossed_trap_depth(strong, _m) < U0_strong     # gravity lowers it
        @test crossed_trap_depth(strong, _m) / U0_strong > 0.9   # but barely, deep trap
        weak = CrossedDipoleTrap(beams(0.1), _α)
        U0_weak = crossed_trap_depth(weak, 1e-30)
        @test crossed_trap_depth(weak, _m) / U0_weak < 0.9   # shallow trap: gravity bites
    end

    @testset "ramp_from_params is a valid transform" begin
        base = _euv3_ramp()
        r = ramp_from_params([2.0, 0.5, 1.5], base)
        @test issorted(r.times)
        @test r.times[end] - r.times[1] ≈ 2.0 * (base.times[end] - base.times[1])
        @test r.powers_W[1, end] ≈ 0.5 * base.powers_W[1, end]
        @test fort_power_at(r, r.times[1]) ≈ r.powers_W[:, 1]
    end

    @testset "optimize_evaporation_ramp improves N_BEC (stub optimizer)" begin
        trap = _eu_trap()
        p = EvapParams(; a_s=_as, tau_bg=10.0, K3=0.0)
        base = _euv3_ramp()
        # deterministic grid-search stub matching the bayesian_optimize contract
        function grid_opt(obj, bounds; n_init, n_iter, minimise)
            best_p = [(lo + hi) / 2 for (lo, hi) in bounds]
            best_y = obj(best_p)
            for x1 in range(bounds[1]...; length=2), x2 in range(bounds[2]...; length=2),
                x3 in range(bounds[3]...; length=2)

                y = obj([x1, x2, x3])
                if (minimise && y < best_y) || (!minimise && y > best_y)
                    best_y = y
                    best_p = [x1, x2, x3]
                end
            end
            (best_p=best_p, best_y=best_y, X_history=Float64[], y_history=Float64[])
        end
        out = optimize_evaporation_ramp(trap, p, base; N0=2e6, T0=40e-6,
            n_init=2, n_iter=2, optimizer=grid_opt)
        @test out.result.reached_bec
        @test out.bo.best_y > 1                         # a real BEC atom number
        @test out.result.N_BEC == out.bo.best_y
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

    # End-to-end validation against the lab NumberOfAtoms.csv requires the real
    # FORT waists / α / N₀ / T₀ from the experiment notebook — gated until supplied.
    @testset "euv3 measured N_BEC (needs lab inputs)" begin
        @test_skip false
    end
end
