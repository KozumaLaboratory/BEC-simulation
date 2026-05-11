# Diagnostic 1: dt refinement test for ρ artifact-vs-physical separation.
#
# Run F=1 16³ anti-polar same setup at 3 different dt values:
#   dt = 0.002 (baseline, T=1.0, 500 steps)
#   dt = 0.001 (T=1.0, 1000 steps)
#   dt = 0.0005 (T=1.0, 2000 steps)
#
# Each run uses identical physical setup (initial state, V_ext, g_S, T).
# Only dt and N_STEPS differ. The TOTAL physical time T = 1.0 is fixed.
#
# Expected outcomes:
#   Case (a) Physical:  ρ(T=1) value is dt-independent (within Strang error)
#   Case (b) Numerical: ρ(T=1) scales as dt² (factor of 4 between refinements)
#   Case (c) Mixed:     ρ = ρ_phys + dt²·ρ_num, refinement reveals ρ_phys
#
# Run: julia --project=. scripts/tdhfb_dt_refinement.jl

using SpinorBEC
using LinearAlgebra
using Printf

const F = 1
const D = 3
const N = 16
const BOX = 10.0
const T_FINAL = 1.0

function _initial_phi()
    phi0 = zeros(ComplexF64, N, N, N, D)
    center = N ÷ 2 + 1
    sigma = 2.0
    @inbounds for i in 1:N, j in 1:N, k in 1:N
        r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
        g = exp(-r2 / (2 * sigma^2)) + 0im
        phi0[i, j, k, 1] = g / sqrt(2)  # m=+1
        phi0[i, j, k, 3] = g / sqrt(2)  # m=-1
    end
    phi0 ./= sqrt(sum(abs2, phi0))
    return phi0
end

function _harmonic_trap()
    V_ext = zeros(Float64, N, N, N, D)
    center = N ÷ 2 + 1
    dx = BOX / N
    @inbounds for i in 1:N, j in 1:N, k in 1:N
        v = 0.5 * (((i - center) * dx)^2 + ((j - center) * dx)^2
                   + 1.4^2 * ((k - center) * dx)^2)
        for m in 1:D
            V_ext[i, j, k, m] = v
        end
    end
    return V_ext
end

function _run(dt::Float64)
    n_steps = round(Int, T_FINAL / dt)
    actual_T = n_steps * dt
    @printf("\n%s\n", "─"^70)
    @printf("dt=%.4f, N_STEPS=%d, T_final=%.4f\n", dt, n_steps, actual_T)
    @printf("%s\n", "─"^70)

    phi0 = _initial_phi()
    V_ext = _harmonic_trap()
    state = init_tdhfb_vacuum(phi0)
    g_S = Dict{Int, Float64}(0 => 1.0, 2 => 1.2)

    @printf("%-6s  %-8s  %-12s  %-12s\n", "step", "t", "‖ρ‖", "‖κ‖")
    t_start = time()
    n_snapshots = 5
    snapshot_steps = round.(Int, range(1, n_steps; length=n_snapshots))
    tdhfb_evolve!(state, F, g_S, V_ext, dt, n_steps;
        scheme=:strang,
        on_step=(s, step) -> begin
            if step in snapshot_steps
                @printf("%-6d  %-8.4f  %-12.6e  %-12.6e\n",
                    step, s.t, norm(s.rho), norm(s.kappa))
            end
        end,
    )
    elapsed = time() - t_start
    rho_final = norm(state.rho)
    kappa_final = norm(state.kappa)

    @printf("\nFinal: ‖ρ‖=%.6e, ‖κ‖=%.6e, wall=%.1fs (%.1fms/step)\n",
        rho_final, kappa_final, elapsed, 1000 * elapsed / n_steps)

    return (dt=dt, T=actual_T, n_steps=n_steps, rho=rho_final, kappa=kappa_final)
end

@printf("=== Diagnostic 1: dt refinement (F=%d, %d³, T=%.1f) ===\n", F, N, T_FINAL)
@printf("Testing dt = {0.002, 0.001, 0.0005}\n")
@printf("Hypothesis (a) physical: ρ(T=1) independent of dt\n")
@printf("Hypothesis (b) artifact: ρ(T=1) scales as dt²\n")

result_a = _run(0.002)
result_b = _run(0.001)
result_c = _run(0.0005)

@printf("\n%s\n", "="^70)
@printf("=== Summary: ρ(T=1.0) vs dt ===\n")
@printf("%s\n", "="^70)
@printf("%-12s  %-15s  %-15s  %-15s\n",
    "dt", "‖ρ‖ at T=1", "‖κ‖ at T=1", "ratio vs dt=0.002")
@printf("%-12.4f  %-15.6e  %-15.6e  %-15s\n",
    result_a.dt, result_a.rho, result_a.kappa, "1.0 (baseline)")
@printf("%-12.4f  %-15.6e  %-15.6e  %-15.3f\n",
    result_b.dt, result_b.rho, result_b.kappa, result_b.rho / result_a.rho)
@printf("%-12.4f  %-15.6e  %-15.6e  %-15.3f\n",
    result_c.dt, result_c.rho, result_c.kappa, result_c.rho / result_a.rho)

# Verdict
@printf("\n── Verdict ──\n")
ratio_b = result_b.rho / result_a.rho  # dt halved
ratio_c = result_c.rho / result_a.rho  # dt quartered
ratio_b_expected_phys = 1.0
ratio_b_expected_art = 0.25  # dt²: (0.001/0.002)² = 0.25
ratio_c_expected_phys = 1.0
ratio_c_expected_art = 0.0625  # (0.0005/0.002)² = 0.0625

dist_phys = abs(ratio_b - 1.0) + abs(ratio_c - 1.0)
dist_art = abs(ratio_b - 0.25) + abs(ratio_c - 0.0625)

if dist_phys < dist_art / 3
    @printf("→ Case (a) PHYSICAL: ρ is dt-independent (ratios ≈ 1.0)\n")
    @printf("  Eu extrapolation as physical signal likely OK\n")
elseif dist_art < dist_phys / 3
    @printf("→ Case (b) NUMERICAL ARTIFACT: ρ scales as dt² (ratios ≈ 0.25, 0.0625)\n")
    @printf("  Observed ρ is Strang truncation error, NOT physical depletion\n")
    @printf("  Calibration finding is artifact; real ρ_phys is below noise floor at this T\n")
else
    @printf("→ Case (c) MIXED: ratios b=%.3f, c=%.3f are intermediate\n", ratio_b, ratio_c)
    @printf("  dt→0 extrapolation needed to extract ρ_phys\n")
    # Linear in dt² extrapolation: ρ(dt) = ρ_phys + α·dt²
    # Solve: ρ(0.002) = ρ_phys + α·4e-6
    #        ρ(0.001) = ρ_phys + α·1e-6
    # → ρ_phys = (4·ρ(0.001) - ρ(0.002)) / 3
    rho_phys_extrap = (4 * result_b.rho - result_a.rho) / 3
    @printf("  Linear-in-dt² extrapolation: ρ_phys ≈ %.6e\n", rho_phys_extrap)
end

@printf("\nκ check: ‖κ‖ ratios %.3f, %.3f (should be ≈ 1.0 if κ is physical):\n",
    result_b.kappa / result_a.kappa, result_c.kappa / result_a.kappa)
@printf("  κ is sourced by V·φφ at leading order — robustness verification\n")
