# B-1: Palindrome residual probe — base substep time-reversibility scan.
#
# Tests: ‖S(-dt) ∘ S(dt) ψ₀ − ψ₀‖_∞ vs dt log-log slope, for
#   (a) plain Strang (frozen MF generators)
#   (b) Strang + picard_midpoint=true (A4 path, palindromic at Picard tol)
#
# Measured at three reference states (state-dependent palindromicity):
#   (1) Vacuum     — ρ=0, κ=0 at start. MF source term vanishes →
#       leading O(dt²) error coefficient is zero → slope reverts to
#       the next-order term O(dt⁴). Special, not the asymptotic regime.
#   (2) Pre-evolved — vacuum evolved 20 steps at dt=0.002 (the v3
#       integration starting region). (ρ, κ) populated by V·φφ.
#       This is the regime the actual Y4 composition sees.
#   (3) Random Hermitian — generic non-trivial (ρ, κ). Matches the
#       header reproducer (`tdhfb_palindromic_gate.jl`) showing slope 2.
#
# Expectation from theory:
#   (a) plain:  slope ~2 in regimes (2), (3); slope ~4 in regime (1).
#       The O(dt²) BCH commutator term has coefficient proportional to
#       (ρ, κ) generator size — zero at vacuum, O(1) elsewhere.
#   (b) picard_midpoint: flat at Picard tolerance (~1e-12 to machine eps)
#       across all three regimes — midpoint Picard makes generators
#       state-symmetric, killing the BCH commutator structurally.
#
# The asymptotic Y4 global order is governed by the worst-case slope
# encountered during the integration (regime 2/3, slope ~2), which is
# why handover §4 measured Y4 ~3.41 not 4 on the lab path.
#
# Setup: v3 anti-polar (F=1 16³, harmonic trap, g_S=(0=>1.0, 2=>1.2)) —
# same physical setup as scripts/tdhfb_eu_pilot_v3.jl.
#
# Run: julia --project=. scripts/diagnostic/palindrome_residual_probe.jl

using SpinorBEC
using Printf
using LinearAlgebra
using Random

const F = 1
const D = 2F + 1
const N_SPATIAL = 16
const BOX = 10.0

function _initial_state_anti_polar()
    phi = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    sigma = 2.0
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
        g = exp(-r2 / (2 * sigma^2)) + 0im
        phi[i, j, k, 1] = g / sqrt(2)  # m=+1
        phi[i, j, k, 3] = g / sqrt(2)  # m=-1
    end
    phi ./= sqrt(sum(abs2, phi))
    init_tdhfb_vacuum(phi)
end

function _harmonic_trap()
    V_ext = zeros(Float64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    dx = BOX / N_SPATIAL
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        v = 0.5 * (((i - center) * dx)^2 + ((j - center) * dx)^2
                   + 1.4^2 * ((k - center) * dx)^2)
        for m in 1:D
            V_ext[i, j, k, m] = v
        end
    end
    return V_ext
end

function _measure(state0, dt; picard_midpoint::Bool, g_S, V_ext)
    s = deepcopy(state0)
    if picard_midpoint
        tdhfb_strang_step!(s, F, g_S, V_ext, +dt;
            picard_midpoint=true, picard_tol=1e-13, picard_max_iter=30)
        tdhfb_strang_step!(s, F, g_S, V_ext, -dt;
            picard_midpoint=true, picard_tol=1e-13, picard_max_iter=30)
    else
        tdhfb_strang_step!(s, F, g_S, V_ext, +dt)
        tdhfb_strang_step!(s, F, g_S, V_ext, -dt)
    end
    phi_dev = maximum(abs.(s.phi .- state0.phi))
    rho_dev = maximum(abs.(s.rho .- state0.rho))
    kappa_dev = maximum(abs.(s.kappa .- state0.kappa))
    (phi=phi_dev, rho=rho_dev, kappa=kappa_dev, total=max(phi_dev, rho_dev, kappa_dev))
end

function _scan(label, picard_midpoint, dts, state0, g_S, V_ext)
    @printf("\n%s\n", "─"^72)
    @printf("=== %s ===\n", label)
    @printf("%s\n", "─"^72)
    @printf("%-10s  %-14s  %-14s  %-14s  %-10s\n",
        "dt", "φ resid", "ρ resid", "κ resid", "slope(ρ)")
    results = NamedTuple[]
    prev_rho = NaN
    for dt in dts
        r = _measure(state0, dt; picard_midpoint=picard_midpoint, g_S=g_S, V_ext=V_ext)
        ord = isnan(prev_rho) ? NaN : log2(prev_rho / r.rho)
        @printf("%-10.5f  %-14.4e  %-14.4e  %-14.4e  %s\n",
            dt, r.phi, r.rho, r.kappa,
            isnan(ord) ? "—" : @sprintf("%.2f", ord))
        push!(results, (dt=dt, r...))
        prev_rho = r.rho
    end
    # log-log slope over the full range, on the ρ component
    log_dts = log.([r.dt for r in results])
    log_rho = log.([r.rho for r in results])
    n = length(log_dts)
    mean_x = sum(log_dts) / n;
    mean_y = sum(log_rho) / n
    slope =
        sum((log_dts[i] - mean_x) * (log_rho[i] - mean_y) for i in 1:n) /
        sum((log_dts[i] - mean_x)^2 for i in 1:n)
    @printf("\nLSQ slope (ρ residual, %d dts): %.3f\n", n, slope)
    return (slope=slope, results=results)
end

function _state_pre_evolved(state0, V_ext, g_S; n_steps=20, dt=0.002)
    s = deepcopy(state0)
    for _ in 1:n_steps
        tdhfb_strang_step!(s, F, g_S, V_ext, dt)
    end
    return s
end

function _state_random(seed::Int)
    rng = MersenneTwister(seed)
    phi = randn(rng, ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D) * 0.1
    rho = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D, D)
    kappa = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D, D)
    for I in CartesianIndices((N_SPATIAL, N_SPATIAL, N_SPATIAL))
        A = randn(rng, ComplexF64, D, D) * 0.05
        rho_loc = 0.5 * (A + adjoint(A))
        for c in 1:D
            rho_loc[c, c] += 0.05
        end
        B = randn(rng, ComplexF64, D, D) * 0.05
        kappa_loc = 0.5 * (B + transpose(B))
        for c in 1:D, cp in 1:D
            rho[I, c, cp] = rho_loc[c, cp]
            kappa[I, c, cp] = kappa_loc[c, cp]
        end
    end
    SpinorBEC.TDHFBState{3, typeof(phi), typeof(rho), Float64}(
        phi, rho, kappa, 0.0, 0
    )
end

@printf("=== B-1: Palindrome residual probe — 3 regimes × 2 schemes ===\n")
@printf("F=%d, %d³, g_S=(0=>1.0, 2=>1.2), anti-polar |+1⟩+|-1⟩ initial\n",
    F, N_SPATIAL)
@printf("Test:  ‖S(-dt) ∘ S(dt) − I‖_∞   vs   dt   log-log\n\n")

V_ext = _harmonic_trap()
g_S = Dict{Int, Float64}(0 => 1.0, 2 => 1.2)
dts = [0.04, 0.02, 0.01, 0.005, 0.0025]

# Three reference states
state_vacuum = _initial_state_anti_polar()
state_pre = _state_pre_evolved(state_vacuum, V_ext, g_S; n_steps=20, dt=0.002)
state_rand = _state_random(42)

# 3 × 2 scans
@printf("\n████ Regime 1: VACUUM (ρ=0, κ=0 — special, leading O(dt²) coeff vanishes) ████\n")
v_plain = _scan("(1a) plain Strang @ vacuum", false, dts, state_vacuum, g_S, V_ext)
v_pm = _scan("(1b) picard_midpoint @ vacuum", true, dts, state_vacuum, g_S, V_ext)

@printf("\n████ Regime 2: PRE-EVOLVED (20 steps @ dt=0.002 — production-relevant state) ████\n")
p_plain = _scan("(2a) plain Strang @ pre-evolved", false, dts, state_pre, g_S, V_ext)
p_pm = _scan("(2b) picard_midpoint @ pre-evolved", true, dts, state_pre, g_S, V_ext)

@printf("\n████ Regime 3: RANDOM Hermitian (generic ρ, κ — header's reproducer) ████\n")
r_plain = _scan("(3a) plain Strang @ random", false, dts, state_rand, g_S, V_ext)
r_pm = _scan("(3b) picard_midpoint @ random", true, dts, state_rand, g_S, V_ext)

@printf("\n%s\n", "═"^72)
@printf("=== Summary: ρ residual log-log slope ===\n")
@printf("%s\n", "═"^72)
@printf("%-30s  %-15s  %-15s\n", "regime", "plain Strang", "picard_midpoint")
@printf("%-30s  %-15.3f  %-15.3f\n", "(1) vacuum", v_plain.slope, v_pm.slope)
@printf("%-30s  %-15.3f  %-15.3f\n", "(2) pre-evolved", p_plain.slope, p_pm.slope)
@printf("%-30s  %-15.3f  %-15.3f\n", "(3) random Hermitian", r_plain.slope, r_pm.slope)

@printf("\n=== ρ residual magnitudes at dt=0.01 ===\n")
@printf("%-30s  %-15s  %-15s\n", "regime", "plain", "picard_midpoint")
function _at_dt(scan, dt)
    for r in scan.results
        if r.dt ≈ dt
            return r.rho
        end
    end
    return NaN
end
@printf("%-30s  %-15.4e  %-15.4e\n", "(1) vacuum", _at_dt(v_plain, 0.01), _at_dt(v_pm, 0.01))
@printf("%-30s  %-15.4e  %-15.4e\n", "(2) pre-evolved", _at_dt(p_plain, 0.01), _at_dt(p_pm, 0.01))
@printf(
    "%-30s  %-15.4e  %-15.4e\n", "(3) random Hermitian", _at_dt(r_plain, 0.01), _at_dt(r_pm, 0.01)
)

@printf("\n── Mechanism interpretation ──\n")
@printf("- Vacuum special-case (slope ~4): ρ=κ=0 makes the leading O(dt²)\n")
@printf("  commutator coefficient vanish; the next-order O(dt⁴) takes over.\n")
@printf("  NOT the asymptotic regime — Y4 global order is set by populated states.\n")
@printf("- Pre-evolved / random (slope ~2 expected): the production regime where\n")
@printf("  (ρ, κ) generators are O(1). Sets the Y4 global order ceiling.\n")
@printf("- picard_midpoint (flat at ~1e-12 / machine eps): the A4 fix kills the\n")
@printf("  BCH commutator structurally, lifts Y4 to its nominal order 4.\n")
