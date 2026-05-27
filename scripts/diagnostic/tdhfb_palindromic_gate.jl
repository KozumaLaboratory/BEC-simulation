# TDHFB Y4 palindromic-gate diagnostic — A4 prerequisite (#86 Option B).
#
# Design ref: `docs/design/tdhfb_y4_palindromic_substep_design.md` §2.
#
# Yoshida-4 composition delivers global order 4 IFF the base substep is
# palindromic at O(dt⁵):
#
#   ‖S(-dt) S(dt) − I‖_∞  ≤  C · dt⁵
#
# (i.e., log₂(residual_ratio) when halving dt should ≥ 5; theoretical for a
# truly palindromic substep is exactly 5).
#
# This script measures the residual on the current `tdhfb_strang_step!` and
# logs the failure mode. Per the design-doc table (§1) the residual is
# expected to scale as O(dt²), confirming the documented failure.
#
# The reproducer also serves as the **regression test** for any future
# A4 implementation:
#   - If Option B (full BdG-Nambu rotation) is implemented, the residual
#     order should rise to ≥ 5.
#   - If a partial fix is attempted, the order improvement tells us
#     which BCH terms have been cancelled.
#
# Run: julia --project=. scripts/diagnostic/tdhfb_palindromic_gate.jl

using SpinorBEC
using Printf
using Random

const F = 1
const D = 2F + 1
const NX = 16
const SPATIAL = (NX, NX, NX)

# Build a random Hermitian D×D matrix.
function _random_hermitian(rng, D)
    A = randn(rng, ComplexF64, D, D) * 0.05
    0.5 * (A + adjoint(A))
end

# Build a random symmetric D×D matrix (κ symmetry: κ[c, c'] = κ[c', c]).
function _random_symmetric(rng, D)
    A = randn(rng, ComplexF64, D, D) * 0.05
    0.5 * (A + transpose(A))
end

function _build_initial_state(seed::Int)
    rng = MersenneTwister(seed)
    phi = randn(rng, ComplexF64, SPATIAL..., D) * 0.1
    rho = zeros(ComplexF64, SPATIAL..., D, D)
    kappa = zeros(ComplexF64, SPATIAL..., D, D)
    # Per-voxel random Hermitian ρ and symmetric κ
    for I in CartesianIndices(SPATIAL)
        rho_loc = _random_hermitian(rng, D)
        kappa_loc = _random_symmetric(rng, D)
        # Make ρ positive-semidefinite-ish by adding a small diagonal
        for c in 1:D
            rho_loc[c, c] += 0.05
        end
        for c in 1:D, cp in 1:D
            rho[I, c, cp] = rho_loc[c, cp]
            kappa[I, c, cp] = kappa_loc[c, cp]
        end
    end
    SpinorBEC.TDHFBState{3, typeof(phi), typeof(rho), Float64}(
        phi, rho, kappa, 0.0, 0
    )
end

function _measure_residual(state0::SpinorBEC.TDHFBState, dt::Float64,
    F::Int, g_S, V_ext)
    # S(dt) then S(-dt)
    s = deepcopy(state0)
    SpinorBEC.tdhfb_strang_step!(s, F, g_S, V_ext, dt)
    SpinorBEC.tdhfb_strang_step!(s, F, g_S, V_ext, -dt)
    # Compare to original. Use a uniform L_∞-like measure across the three
    # components (the design doc reports the ρ component as dominant).
    phi_dev = maximum(abs.(s.phi .- state0.phi))
    rho_dev = maximum(abs.(s.rho .- state0.rho))
    kappa_dev = maximum(abs.(s.kappa .- state0.kappa))
    (phi=phi_dev, rho=rho_dev, kappa=kappa_dev, total=max(phi_dev, rho_dev, kappa_dev))
end

# ===== Run =====
@printf("=== TDHFB Strang substep palindromic gate ===\n")
@printf("Problem: F=%d, D=%d, grid=%s (random Hermitian ρ + symmetric κ init)\n",
    F, D, SPATIAL)
@printf("Test: ‖S(-dt) S(dt) − I‖_∞ scaling with dt\n")
@printf("Acceptance for Y4 Yoshida composition (A4 goal): order ≥ 5\n")
@printf("Documented current state: order ≈ 2 (Option B fix needed)\n\n")

state0 = _build_initial_state(42)
g_S = Dict{Int, Float64}(0 => 0.5, 2 => 0.1)
V_ext = zeros(Float64, SPATIAL..., D)

dts = [0.04, 0.02, 0.01, 0.005, 0.0025]

@printf("%-10s  %-14s  %-14s  %-14s  %-10s\n",
    "dt", "φ resid", "ρ resid", "κ resid", "order(ρ)")
prev_rho = NaN
results = NamedTuple[]
for dt in dts
    r = _measure_residual(state0, dt, F, g_S, V_ext)
    push!(results, (dt=dt, r...))
    ord_rho = isnan(prev_rho) ? NaN : log2(prev_rho / r.rho)
    @printf("%-10.4f  %-14.4e  %-14.4e  %-14.4e  %s\n",
        dt, r.phi, r.rho, r.kappa,
        isnan(ord_rho) ? "—" : @sprintf("%.2f", ord_rho))
    global prev_rho = r.rho
end

@printf("\n%s\n", "═"^60)
# Fit log-log slope over the dt range
log_dts = log.([r.dt for r in results])
log_rho = log.([r.rho for r in results])
# Least-squares slope
n = length(log_dts)
mean_x = sum(log_dts) / n;
mean_y = sum(log_rho) / n
slope =
    sum((log_dts[i] - mean_x) * (log_rho[i] - mean_y) for i in 1:n) /
    sum((log_dts[i] - mean_x)^2 for i in 1:n)
@printf("ρ residual log-log slope (LSQ over %d dts): %.3f\n", n, slope)
@printf("Theoretical for palindromic substep: ≥ 5 (= O(dt⁵) residual)\n")
@printf("Documented current value: ≈ 2 (= O(dt²) residual, Option B fix needed)\n")

if slope >= 4.5
    @printf("\n✓✓✓ A4 ACCEPTANCE PASS: Y4 composition delivers order 4\n")
elseif slope >= 2.5
    @printf("\n△ Partial: order in (2.5, 4.5) — some BCH terms cancelled but not enough\n")
else
    @printf("\n✗ Documented O(dt²) failure mode confirmed (slope %.2f)\n", slope)
    @printf("  Y4 composition delivers order 2, not 4.\n")
    @printf("  → Option B implementation needed (design doc §3.2).\n")
end
@printf("%s\n", "═"^60)
