# TDHFB Phase 3 完了判定 pilot — F=1 non-trivial spinor + energy conservation.
#
# Two-part diagnostic running in sequence:
#
#   Part A: scalar limit (g_0 = g_2)  — expect ρ ≈ 0 throughout, κ kinematic only
#   Part B: spinor (g_0 ≠ g_2)        — expect ρ generation, both κ and ρ alive
#
# Both parts track total energy E[φ, ρ, κ] via `tdhfb_energy()` to characterise
# Strang + frozen-midpoint energy drift (Phase 3 limit, Y4-mid is Phase 4 work).
#
# F=1 (D=3) keeps cost minimal so multiple regimes can be swept in one script.
# Grid 16³, 100 steps × dt=0.002 (= total T=0.2, double the Phase 3 pilot).
#
# Run: julia --project=. scripts/tdhfb_eu_pilot_v2.jl

using SpinorBEC
using LinearAlgebra
using Printf

const F = 1
const D = 2F + 1
const N_SPATIAL = 16
const BOX = 10.0
const DT = 0.002
const N_STEPS = 100

function _initial_phi(state_type::Symbol)
    phi0 = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    sigma = 2.0
    if state_type === :polar
        # m = 0 polar Gaussian
        comp = 2
    elseif state_type === :fm
        # m = +F stretched
        comp = 1
    else
        error("unknown state $state_type")
    end
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
        phi0[i, j, k, comp] = exp(-r2 / (2 * sigma^2)) + 0im
    end
    phi0 ./= sqrt(sum(abs2, phi0))
    return phi0
end

function _harmonic_trap()
    V_ext = zeros(Float64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    dx = BOX / N_SPATIAL
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        x = (i - center) * dx
        y = (j - center) * dx
        z = (k - center) * dx
        v = 0.5 * (x^2 + y^2 + 1.4^2 * z^2)
        for m in 1:D
            V_ext[i, j, k, m] = v
        end
    end
    return V_ext
end

function _run_regime(label::String, g_S::Dict{Int, Float64}, state_type::Symbol)
    @printf("\n%s\n", "─"^70)
    @printf("%s\n", label)
    @printf("  g_S = %s\n", g_S)
    @printf("  initial state = %s (Gaussian)\n", state_type)
    @printf("%s\n", "─"^70)

    phi0 = _initial_phi(state_type)
    V_ext = _harmonic_trap()
    state = init_tdhfb_vacuum(phi0)

    N_init = tdhfb_total_particle_number(state)
    E_init = tdhfb_energy(state, F, g_S, V_ext)

    @printf("Initial: N = %.6f, E = %.6f\n", N_init, E_init)
    @printf("\n%-5s  %-10s  %-12s  %-12s  %-10s  %-10s\n",
        "step", "t", "ΔN/N", "ΔE/|E|", "‖ρ‖", "‖κ‖")

    @printf("%-5d  %-10.4f  %-12s  %-12s  %-10.5f  %-10.5f\n",
        0, 0.0, "—", "—", norm(state.rho), norm(state.kappa))

    t_start = time()
    tdhfb_evolve!(state, F, g_S, V_ext, DT, N_STEPS;
        scheme=:strang,
        on_step=(s, step) -> begin
            if step % 10 == 0
                N_now = tdhfb_total_particle_number(s)
                E_now = tdhfb_energy(s, F, g_S, V_ext)
                dN_N = (N_now - N_init) / N_init
                dE_E = (E_now - E_init) / max(abs(E_init), 1e-12)
                @printf("%-5d  %-10.4f  %+10.3e   %+10.3e   %-10.5f  %-10.5f\n",
                    step, s.t, dN_N, dE_E, norm(s.rho), norm(s.kappa))
            end
        end,
    )
    elapsed = time() - t_start

    rho_dev, kappa_dev = tdhfb_hermiticity_check(state)
    @printf("\nFinal: ‖ρ‖ = %.5f, ‖κ‖ = %.5f\n", norm(state.rho), norm(state.kappa))
    @printf("       Hermiticity dev (ρ, κ) = (%.2e, %.2e)\n", rho_dev, kappa_dev)
    @printf("       Wall clock: %.1fs (%.1f ms/step)\n",
        elapsed, 1000 * elapsed / N_STEPS)

    return (
        rho_final = norm(state.rho),
        kappa_final = norm(state.kappa),
        rho_dev = rho_dev,
        kappa_dev = kappa_dev,
        N_drift = (tdhfb_total_particle_number(state) - N_init) / N_init,
        E_drift = (tdhfb_energy(state, F, g_S, V_ext) - E_init) / max(abs(E_init), 1e-12),
        elapsed = elapsed,
    )
end

@printf("=== TDHFB Phase 3 完了判定: F=%d, %d³ grid, %d steps × dt=%.4f, T=%.2f ===\n",
    F, N_SPATIAL, N_STEPS, DT, N_STEPS * DT)

# Part A: scalar limit (g_0 = g_2) → ρ should stay 0
result_A = _run_regime(
    "Part A: SCALAR LIMIT (g_0 = g_2 = 1.0) — polar initial",
    Dict{Int, Float64}(0 => 1.0, 2 => 1.0),
    :polar,
)

# Part B: spinor (g_0 ≠ g_2) → ρ generation expected
# For F=1: c_0 = (g_0 + 2g_2)/3, c_1 = (g_2 - g_0)/3
# Choose g_0 = 1.0, g_2 = 1.2 → c_1 = 0.067, ferromagnetic preference (c_1 > 0)
result_B = _run_regime(
    "Part B: SPINOR (g_0 = 1.0, g_2 = 1.2; c_1 ≈ +0.067) — polar initial",
    Dict{Int, Float64}(0 => 1.0, 2 => 1.2),
    :polar,
)

# Part C: FM initial state, scalar limit → check that ρ stays 0 in FM too
result_C = _run_regime(
    "Part C: SCALAR LIMIT (g_0 = g_2 = 1.0) — FM (m=+F) initial",
    Dict{Int, Float64}(0 => 1.0, 2 => 1.0),
    :fm,
)

# ─────────────────────────────────────────────────────────────────────
# Phase 3 完了判定
# ─────────────────────────────────────────────────────────────────────
@printf("\n%s\n", "="^70)
@printf("=== Phase 3 完了判定 ===\n")
@printf("%s\n", "="^70)

@printf("\n%-25s  %-15s  %-15s  %-15s\n",
    "regime", "‖ρ‖ final", "‖κ‖ final", "ΔE/|E|")
@printf("%-25s  %-15.5f  %-15.5f  %+15.3e\n",
    "A: scalar polar", result_A.rho_final, result_A.kappa_final, result_A.E_drift)
@printf("%-25s  %-15.5f  %-15.5f  %+15.3e\n",
    "B: spinor g_0≠g_2 polar", result_B.rho_final, result_B.kappa_final, result_B.E_drift)
@printf("%-25s  %-15.5f  %-15.5f  %+15.3e\n",
    "C: scalar FM", result_C.rho_final, result_C.kappa_final, result_C.E_drift)

@printf("\n── Phase 3 完了判定 criteria ──\n")
@printf("[1] Hermiticity preserved (A+B+C):  ρ dev max = %.2e   ",
    max(result_A.rho_dev, result_B.rho_dev, result_C.rho_dev))
println(max(result_A.rho_dev, result_B.rho_dev, result_C.rho_dev) < 1e-10 ? "✓ PASS" : "✗ FAIL")

@printf("[2] Symmetry preserved (κ, A+B+C): κ dev max = %.2e   ",
    max(result_A.kappa_dev, result_B.kappa_dev, result_C.kappa_dev))
println(max(result_A.kappa_dev, result_B.kappa_dev, result_C.kappa_dev) < 1e-10 ? "✓ PASS" : "✗ FAIL")

@printf("[3] Scalar limit ρ ≈ 0 (A, C):     ‖ρ‖_A = %.2e, ‖ρ‖_C = %.2e   ",
    result_A.rho_final, result_C.rho_final)
println(result_A.rho_final < 1e-3 && result_C.rho_final < 1e-3 ? "✓ PASS" : "✗ FAIL")

@printf("[4] Spinor ρ generation (B):       ‖ρ‖_B = %.5f   ", result_B.rho_final)
println(result_B.rho_final > 1e-4 ? "✓ PASS (ρ alive)" : "✗ FAIL (ρ stayed near 0)")

@printf("[5] κ kinematic motion (all):      ‖κ‖_min = %.5f   ",
    min(result_A.kappa_final, result_B.kappa_final, result_C.kappa_final))
println(min(result_A.kappa_final, result_B.kappa_final, result_C.kappa_final) > 1e-4 ? "✓ PASS" : "✗ FAIL")

@printf("[6] Energy drift ≤ Phase 3 limit:  |ΔE/E|_max = %.2e   ",
    max(abs(result_A.E_drift), abs(result_B.E_drift), abs(result_C.E_drift)))
phase3_ok = max(abs(result_A.E_drift), abs(result_B.E_drift), abs(result_C.E_drift)) < 1e-2
println(phase3_ok ? "✓ PASS (Phase 3 OK)" : "△ Phase 4 (Y4-midpoint) で改善 expected")

@printf("\nTotal wall clock: %.1f s for 3 × %d steps = %.1f ms/step avg\n",
    result_A.elapsed + result_B.elapsed + result_C.elapsed,
    N_STEPS,
    1000 * (result_A.elapsed + result_B.elapsed + result_C.elapsed) / (3 * N_STEPS))
