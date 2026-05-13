# TDHFB Phase 3 v3 setup, rerun on the A4 acceptance path.
#
# Identical to scripts/tdhfb_eu_pilot_v3.jl except the integrator:
#   scheme=:strang             →  scheme=:y4_midpoint, picard_midpoint=true
#
# Purpose: separate Strang truncation error from physical ρ generation.
# If ρ values drop substantially under A4 path → previous v3 ρ was
# dominated by O(dt²) Strang truncation. If ρ persists → physical.
#
# Cost: A4 path is ~12-15× plain Strang per step. v3 had 100 steps total
# (4 regimes), so this is ~4 regimes × 100 steps × 15× ≈ feasible CPU.
#
# Run: julia --project=. scripts/tdhfb_eu_pilot_v3_a4.jl

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
        comp = 2;
        pops = [(comp, 1.0 + 0im)]
    elseif state_type === :fm
        comp = 1;
        pops = [(comp, 1.0 + 0im)]
    elseif state_type === :anti_polar
        pops = [(1, 1.0 / sqrt(2.0) + 0im), (3, 1.0 / sqrt(2.0) + 0im)]
    elseif state_type === :polar_seed
        a = sqrt(1 - 2 * 0.05^2)
        pops = [(1, 0.05 + 0im), (2, a + 0im), (3, 0.05 + 0im)]
    else
        error("unknown state $state_type")
    end
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
        g = exp(-r2 / (2 * sigma^2))
        for (comp, amp) in pops
            phi0[i, j, k, comp] = g * amp
        end
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
    @printf("\n%s\n%s\n  g_S=%s, init=%s\n%s\n",
        "─"^70, label, g_S, state_type, "─"^70)

    phi0 = _initial_phi(state_type)
    V_ext = _harmonic_trap()
    state = init_tdhfb_vacuum(phi0)
    N_init = tdhfb_total_particle_number(state)
    E_init = tdhfb_energy(state, F, g_S, V_ext)

    @printf("Init: N=%.6f, E=%.6f\n", N_init, E_init)
    @printf("\n%-5s  %-8s  %-12s  %-12s  %-9s  %-9s\n",
        "step", "t", "ΔN/N", "ΔE/|E|", "‖ρ‖", "‖κ‖")
    @printf("%-5d  %-8.3f  %-12s  %-12s  %-9.5f  %-9.5f\n",
        0, 0.0, "—", "—", norm(state.rho), norm(state.kappa))

    t_start = time()
    tdhfb_evolve!(state, F, g_S, V_ext, DT, N_STEPS;
        scheme=:y4_midpoint,
        picard_midpoint=true,
        picard_midpoint_max_iter=20,
        picard_midpoint_tol=1e-12,
        on_step=(s, step) -> begin
            if step % 20 == 0
                N_now = tdhfb_total_particle_number(s)
                E_now = tdhfb_energy(s, F, g_S, V_ext)
                @printf("%-5d  %-8.3f  %+10.3e   %+10.3e   %-9.5f  %-9.5f\n",
                    step, s.t,
                    (N_now - N_init) / N_init,
                    (E_now - E_init) / max(abs(E_init), 1e-12),
                    norm(s.rho), norm(s.kappa))
            end
        end,
    )
    elapsed = time() - t_start

    rho_dev, kappa_dev = tdhfb_hermiticity_check(state)
    @printf("\nFinal ρ=%.5f, κ=%.5f, dev=(%.1e, %.1e), wall=%.1fs (%.1fms/step)\n",
        norm(state.rho), norm(state.kappa), rho_dev, kappa_dev,
        elapsed, 1000 * elapsed / N_STEPS)

    return (
        rho_final=norm(state.rho),
        kappa_final=norm(state.kappa),
        rho_dev=rho_dev,
        kappa_dev=kappa_dev,
        N_drift=(tdhfb_total_particle_number(state) - N_init) / N_init,
        E_drift=(tdhfb_energy(state, F, g_S, V_ext) - E_init) / max(abs(E_init), 1e-12),
    )
end

@printf("=== TDHFB Phase 3 v3 rerun on A4 path (Y4 + picard_midpoint=true) ===\n")
@printf("F=%d, %d³, %d steps×dt=%.4f, T=%.2f\n",
    F, N_SPATIAL, N_STEPS, DT, N_STEPS * DT)

result_A = _run_regime("A: SCALAR polar (control)",
    Dict(0 => 1.0, 2 => 1.0), :polar)
result_B = _run_regime("B: SPINOR g_0=1.0, g_2=1.2 + ANTI-POLAR",
    Dict(0 => 1.0, 2 => 1.2), :anti_polar)
result_B2 = _run_regime("B2: SPINOR same + POLAR-SEED (5% ±1 admixture)",
    Dict(0 => 1.0, 2 => 1.2), :polar_seed)
result_C = _run_regime("C: SCALAR FM (control)",
    Dict(0 => 1.0, 2 => 1.0), :fm)

@printf("\n%s\n=== Phase 3 v3 A4-path summary ===\n%s\n", "="^70, "="^70)
@printf("\n%-30s  %-10s  %-10s  %-12s\n", "regime", "‖ρ‖", "‖κ‖", "ΔE/|E|")
for (lbl, r) in [
    ("A: scalar polar", result_A),
    ("B: spinor anti-polar", result_B),
    ("B2: spinor polar-seed 5%", result_B2),
    ("C: scalar FM", result_C),
]
    @printf("%-30s  %-10.5f  %-10.5f  %+12.3e\n",
        lbl, r.rho_final, r.kappa_final, r.E_drift)
end

@printf("\n── Criteria (same thresholds as v3) ──\n")
max_rho_dev = max(result_A.rho_dev, result_B.rho_dev, result_B2.rho_dev, result_C.rho_dev)
max_kappa_dev = max(result_A.kappa_dev, result_B.kappa_dev, result_B2.kappa_dev, result_C.kappa_dev)

@printf("[1] ρ Hermiticity (4 regimes):  max dev = %.2e   %s\n",
    max_rho_dev, max_rho_dev < 1e-10 ? "✓ PASS" : "✗ FAIL")
@printf("[2] κ symmetry (4 regimes):     max dev = %.2e   %s\n",
    max_kappa_dev, max_kappa_dev < 1e-10 ? "✓ PASS" : "✗ FAIL")
@printf("[3] Scalar limit ρ stays ≈0:    ‖ρ‖_A=%.1e, ‖ρ‖_C=%.1e   %s\n",
    result_A.rho_final, result_C.rho_final,
    (result_A.rho_final < 1e-3 && result_C.rho_final < 1e-3) ? "✓ PASS" : "✗ FAIL")
@printf("[4] Spinor ρ generation:        ‖ρ‖_B=%.5f, ‖ρ‖_B2=%.5f   %s\n",
    result_B.rho_final, result_B2.rho_final,
    max(result_B.rho_final, result_B2.rho_final) > 1e-4 ? "✓ PASS" : "✗ FAIL")
@printf("[5] κ kinematic (all):          min ‖κ‖=%.5f   %s\n",
    min(result_A.kappa_final, result_B.kappa_final, result_B2.kappa_final, result_C.kappa_final),
    if min(
        result_A.kappa_final, result_B.kappa_final, result_B2.kappa_final, result_C.kappa_final
    ) > 1e-4
        "✓ PASS"
    else
        "✗ FAIL"
    end)

max_E_drift = maximum(abs(r.E_drift) for r in [result_A, result_B, result_B2, result_C])
@printf("[6] Energy drift Phase 3 limit: |ΔE/E|_max=%.2e   %s\n",
    max_E_drift, max_E_drift < 1e-2 ? "✓ PASS" : "△ further refinement")
