# Two-component (thermal + condensate) evaporation — the BEC transition.
# Scalar ms-scale kinetics (no ITP/RTP) ⇒ fast tier.

using Test
using SpinorBEC
using SpinorBEC: Eu151, Units, EvapTrap, EvapParams, FortRamp,
    bec_critical_temperature, condensate_split, run_evaporation_bec, EvapBecResult,
    euv3_evap_trap, trap_at

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
