# Two-component (thermal + condensate) evaporation — the BEC transition.
# Scalar ms-scale kinetics (no ITP/RTP) ⇒ fast tier.

using Test
using SpinorBEC
using SpinorBEC: Eu151, Units, EvapTrap, EvapParams, FortRamp,
    bec_critical_temperature, condensate_split, run_evaporation_bec, EvapBecResult,
    euv3_evap_trap, trap_at, evap_rhs, evap_trap_grid, EvapTrapGrid
using SpinorBEC: _evap_rhs_bec, _condensate_three_body_rate

const _m_c = Eu151.mass
const _as_c = Eu151.a_s
const _z3 = 1.2020569031595942

_trap_c() = EvapTrap(;
    wavelength=1064e-9, alpha=2.0e-36, waists=[30e-6, 30e-6, 30e-6],
    directions=[(1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)],
    positions=[(0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)],
    mass=_m_c, gravity_axis=3)

# euv3-shaped ramp from the loaded crossed trap (cools the gas below T_c)
_ramp_c() = FortRamp(
    [0.0, 0.9, 1.5, 2.1],
    [2.0 0.56 0.16 0.099; 1.8 1.6 1.0 0.09; 0.0 0.0 0.0 0.0])

@testset "BEC transition (two-component)" begin
    @testset "critical temperature closed form + scaling" begin
        N, ω̄ = 1e5, 2π * 100
        @test bec_critical_temperature(N, ω̄) ≈
            (Units.HBAR * ω̄ / Units.KB) * (N / _z3)^(1 / 3)
        @test bec_critical_temperature(8N, ω̄) ≈ 2 * bec_critical_temperature(N, ω̄)  # ∝ N^{1/3}
        @test bec_critical_temperature(N, 2ω̄) ≈ 2 * bec_critical_temperature(N, ω̄)  # ∝ ω̄
    end

    @testset "condensate split: regimes, continuity, conservation" begin
        N, ω̄ = 1e5, 2π * 100
        Tc = bec_critical_temperature(N, ω̄)
        # above T_c: all thermal
        N0, Nth = condensate_split(N, 1.5Tc, ω̄)
        @test N0 == 0 && Nth ≈ N
        # at the boundary: continuous (N_th → N)
        N0, Nth = condensate_split(N, Tc, ω̄)
        @test N0 == 0 && Nth ≈ N
        # below: N_th = N (T/T_c)³, conservation N₀+N_th = N
        N0, Nth = condensate_split(N, 0.5Tc, ω̄)
        @test Nth ≈ N / 8 rtol = 1e-6
        @test N0 ≈ 7N / 8 rtol = 1e-6
        @test N0 + Nth ≈ N
        # T → 0: fully condensed
        N0, Nth = condensate_split(N, 1e-3 * Tc, ω̄)
        @test N0 ≈ N rtol = 1e-3
        # degenerate guards
        @test condensate_split(0.0, Tc, ω̄) == (0.0, 0.0)
    end

    @testset "run_evaporation_bec forms a condensate + thermal crash" begin
        trap = _trap_c()
        p = EvapParams(; a_s=_as_c, tau_bg=10.0, K3=0.0)
        r = run_evaporation_bec(trap, _ramp_c(), p; N0=2e6, T0=40e-6)
        @test r isa EvapBecResult
        @test r.N0_final > 0                          # a condensate formed
        @test !isnan(r.t_bec)                         # the transition happened
        @test all(r.N0 .>= -1e-9)                     # non-negative condensate
        @test all(r.N0 .+ r.Nth .≈ r.N)               # split conserves total
        @test r.Nth[1] ≈ r.N[1]                       # starts fully thermal
        @test r.Nth[end] < maximum(r.Nth)             # thermal cloud crashes below T_c
        @test r.N0[end] > r.Nth[end]                  # mostly condensed at the end
    end

    # ANTI-DRIFT GATE: above T_c the two-component RHS must be BIT-IDENTICAL to the thermal
    # evap_rhs (same evaporation rate, excess-energy heating, thermal three-body, adiabatic
    # term, background loss). Both call the single _thermal_evap_rates declaration, so the two
    # paths cannot silently diverge — this test fails the instant a term is added to one only.
    @testset "RHS parity gate: _evap_rhs_bec ≡ evap_rhs above T_c (no drift)" begin
        ω̄ = 2π * 300
        for K3 in (0.0, 5e-41), dlnω in (0.0, -0.7, 1.1)
            p = EvapParams(; a_s=_as_c, tau_bg=12.0, K3=K3)
            N, T = 5e5, 30e-6
            U = 6.0 * Units.KB * T                          # η = 6
            @test T > bec_critical_temperature(N, ω̄)        # genuinely above T_c (N0 = 0)
            a = evap_rhs(N, T, U, ω̄, p, _m_c; dlnω_dt=dlnω)
            b = _evap_rhs_bec(N, T, U, ω̄, p, _m_c; dlnω_dt=dlnω)
            @test a[1] == b[1]                              # dN identical
            @test a[2] == b[2]                              # dT identical
        end
        # and below T_c the two genuinely differ (condensate 3-body + saturated thermal cloud)
        p = EvapParams(; a_s=_as_c, tau_bg=12.0, K3=5e-41)
        Nlo, ω̄2 = 2e6, 2π * 300
        Tlo = 0.3 * bec_critical_temperature(Nlo, ω̄2)       # well below T_c
        Ulo = 6.0 * Units.KB * Tlo
        @test _evap_rhs_bec(Nlo, Tlo, Ulo, ω̄2, p, _m_c) !=
            evap_rhs(Nlo, Tlo, Ulo, ω̄2, p, _m_c)
    end

    # Independent tightness axis m_ω(t): a multiplier on ω̄ only (the ODT waist), leaving the
    # depth U (evaporation drive) set by the power ramp. m_ω ≡ 1 must recover the power-ramp run
    # exactly; loosening collapses T_c ∝ ω̄ and melts the BEC (the numeric form of the
    # "dilute but not too dilute" constraint).
    @testset "tightness axis m_ω: identity + T_c-collapse melt" begin
        trap = _trap_c()
        p = EvapParams(; a_s=_as_c, tau_bg=10.0, K3=0.0)
        base = run_evaporation_bec(trap, _ramp_c(), p; N0=2e6, T0=40e-6)
        # m_ω ≡ 1 is bit-identical to the default (no waist axis engaged)
        one = run_evaporation_bec(trap, _ramp_c(), p; N0=2e6, T0=40e-6, omega_mult=(t -> 1.0))
        @test one.N0_final == base.N0_final
        @test one.T_final == base.T_final
        @test one.N == base.N
        @test one.N0 == base.N0
        @test base.N0_final > 0                        # baseline forms a condensate
        # loosening far enough collapses T_c ∝ ω̄ ⇒ the condensate melts away
        loose = run_evaporation_bec(trap, _ramp_c(), p; N0=2e6, T0=40e-6, omega_mult=(t -> 0.2))
        @test loose.N0_final < base.N0_final
    end

    # Precomputed trap grid (reused across omega_mult scans on a fixed ramp) must give a
    # bit-identical run to the in-line build — the crossed-dipole (U, ω̄) nodes are the same.
    @testset "precomputed trap grid is bit-identical" begin
        trap = _trap_c()
        p = EvapParams(; a_s=_as_c, tau_bg=10.0, K3=1e-41)
        ramp = _ramp_c()
        g = evap_trap_grid(trap, ramp)
        @test g isa EvapTrapGrid
        r0 = run_evaporation_bec(trap, ramp, p; N0=2e6, T0=40e-6)
        r1 = run_evaporation_bec(trap, ramp, p; N0=2e6, T0=40e-6, trap_grid=g)
        @test r1.N0_final == r0.N0_final
        @test r1.T_final == r0.T_final
        @test r1.N == r0.N
        @test r1.N0 == r0.N0
        # composes with the tightness axis
        r2 = run_evaporation_bec(trap, ramp, p; N0=2e6, T0=40e-6,
            omega_mult=(t -> 0.8), trap_grid=g)
        r3 = run_evaporation_bec(trap, ramp, p; N0=2e6, T0=40e-6, omega_mult=(t -> 0.8))
        @test r2.N0_final == r3.N0_final
    end

    # Feshbach a_s axis: as_mult rescales a_s (and K₃=K₃·as_mult⁴, universal van der Waals).
    # as_mult≡1 must be bit-identical; lowering a_s must cut the condensate 3-body rate.
    @testset "Feshbach a_s axis: identity + K₃∝a_s⁴ cuts 3-body" begin
        trap = _trap_c()
        p = EvapParams(; a_s=_as_c, tau_bg=10.0, K3=1e-41)
        ramp = _ramp_c()
        base = run_evaporation_bec(trap, ramp, p; N0=2e6, T0=40e-6)
        one = run_evaporation_bec(trap, ramp, p; N0=2e6, T0=40e-6, as_mult=(t -> 1.0))
        @test one.N0_final == base.N0_final       # bit-identical at as_mult≡1
        @test one.N == base.N
        # condensate 3-body rate ∝ K₃·n₀² = as_mult⁴·(as_mult^{-3/5})² = as_mult^{2.8}: lower a_s ⇒ lower rate
        r_full = _condensate_three_body_rate(1e5, 2π * 100, p, _m_c, 1.0)
        r_half = _condensate_three_body_rate(1e5, 2π * 100, p, _m_c, 0.5)
        @test r_full > 0
        @test r_half < r_full
        @test r_half ≈ r_full * 0.5^2.8 rtol = 1e-6
        # as_mult≠1 genuinely changes a full run (non-trivial coupling)
        low = run_evaporation_bec(trap, ramp, p; N0=2e6, T0=40e-6, as_mult=(t -> 0.5))
        @test low.N0_final != base.N0_final
    end

    @testset "above T_c reduces to the thermal model (no condensate)" begin
        trap = _trap_c()
        p = EvapParams(; a_s=_as_c, tau_bg=Inf, K3=0.0)
        deep = FortRamp([0.0, 1.0], [50.0 50.0; 50.0 50.0; 50.0 50.0])  # deep ⇒ no cooling
        r = run_evaporation_bec(trap, deep, p; N0=1e5, T0=50e-6, dt=1e-3)
        @test r.N0_final == 0
        @test all(r.N0 .== 0)
        @test isnan(r.t_bec)
    end

    @testset "three-body loss limits the condensate atom number" begin
        trap = _trap_c()
        n0(K3) = run_evaporation_bec(trap, _ramp_c(),
            EvapParams(; a_s=_as_c, tau_bg=10.0, K3=K3); N0=2e6, T0=40e-6).N0_final
        # three-body loss monotonically reduces the surviving condensate (down to 0)
        @test n0(0.0) > 0                         # without loss, a condensate forms
        @test n0(1e-41) <= n0(0.0)                # loss can only remove atoms
        @test n0(1e-40) <= n0(1e-41)              # monotone decreasing in K3
        @test n0(1e-41) >= 0                      # never negative
    end

    # C-validation against the published ¹⁵¹Eu BEC (Miyazawa/Matsui et al.,
    # PRL 129, 223401 (2022); arXiv:2207.11692). The H ODT is an elliptical beam
    # 31 µm (horizontal) × 25 µm (vertical) at 1550 nm; using the effective round
    # waist √(31·25) preserves both the depth and the geometric-mean trap frequency.
    # Polarizability α = 5.88e-37 J/(W/m²) is fixed by the paper's loading depth.
    @testset "C-validation vs Eu BEC paper (PRL 129, 223401)" begin
        α = 5.88e-37
        wH = sqrt(31e-6 * 25e-6)                  # elliptical H beam → effective waist
        trap = euv3_evap_trap(; alpha=α, waists=[wH, 42e-6, 42e-6])
        # loading: 10 W H-only ⇒ depth ≈ 350 µK, η ≈ 7 at the measured 50 µK
        U, _ = trap_at(trap, [10.0, 0.0, 0.0])
        @test U / Units.KB * 1e6 ≈ 350 rtol = 0.1     # paper: 350 µK
        @test U / (Units.KB * 50e-6) ≈ 7 rtol = 0.15  # paper-implied η_start ≈ 7 (efficient)
        # BEC onset: ideal-gas T_c is ~12 % above the paper's finite-size+interaction-
        # +DDI-corrected 367 nK, at the measured N = 1.61e5 and ω̄ = 168 Hz.
        Tc = bec_critical_temperature(1.61e5, 2π * 168)
        @test Tc * 1e9 ≈ 367 * 1.12 rtol = 0.1        # ≈ 410 nK uncorrected
        @test Tc * 1e9 > 349                          # above the measured BEC temperature
    end
end
