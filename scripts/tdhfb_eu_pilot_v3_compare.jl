# Side-by-side comparison: v3 setup under plain Strang vs A4 (Y4+picard_midpoint).
#
# Same initial state, V_ext, g_S, dt, n_steps as scripts/tdhfb_eu_pilot_v3.jl
# (and tdhfb_eu_pilot_v3_a4.jl). Single regime (B: anti-polar spinor) — the
# one that drives ρ generation in v3. Goal: directly compare final ρ values
# at identical physical setup, different integrator.
#
# Verdict logic:
#   - ρ_strang ≈ ρ_a4: ρ is dominated by physical generation, not Strang
#     truncation. (Consistent with dt-refinement showing ρ ~ dt⁰.)
#   - ρ_strang ≫ ρ_a4: prior ρ values were inflated by O(dt²) Strang
#     palindrome breakdown; A4 reveals the smaller physical value.
#   - ρ_strang ≪ ρ_a4: unexpected (A4 should not amplify error). Investigate.
#
# Run: julia --project=. scripts/tdhfb_eu_pilot_v3_compare.jl

using SpinorBEC
using LinearAlgebra
using Printf

const F = 1
const D = 2F + 1
const N_SPATIAL = 16
const BOX = 10.0
const DT = 0.002
const N_STEPS = 100

function _initial_phi_anti_polar()
    phi0 = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    sigma = 2.0
    pops = [(1, 1.0 / sqrt(2.0) + 0im), (3, 1.0 / sqrt(2.0) + 0im)]
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

function _run(label::String; scheme::Symbol, picard_midpoint::Bool)
    @printf("\n%s\n%s\n  scheme=%s, picard_midpoint=%s\n%s\n",
        "─"^70, label, scheme, picard_midpoint, "─"^70)

    phi0 = _initial_phi_anti_polar()
    V_ext = _harmonic_trap()
    state = init_tdhfb_vacuum(phi0)
    g_S = Dict(0 => 1.0, 2 => 1.2)
    N_init = tdhfb_total_particle_number(state)
    E_init = tdhfb_energy(state, F, g_S, V_ext)

    @printf("Init: N=%.6f, E=%.6f\n", N_init, E_init)
    @printf("\n%-5s  %-8s  %-12s  %-12s  %-12s  %-12s\n",
        "step", "t", "ΔN/N", "ΔE/|E|", "‖ρ‖", "‖κ‖")

    t_start = time()
    if scheme === :strang
        tdhfb_evolve!(state, F, g_S, V_ext, DT, N_STEPS;
            scheme=:strang,
            on_step=(s, step) -> begin
                if step % 20 == 0
                    N_now = tdhfb_total_particle_number(s)
                    E_now = tdhfb_energy(s, F, g_S, V_ext)
                    @printf("%-5d  %-8.3f  %+10.3e   %+10.3e   %-12.6e  %-12.6e\n",
                        step, s.t,
                        (N_now - N_init) / N_init,
                        (E_now - E_init) / max(abs(E_init), 1e-12),
                        norm(s.rho), norm(s.kappa))
                end
            end,
        )
    else
        tdhfb_evolve!(state, F, g_S, V_ext, DT, N_STEPS;
            scheme=:y4_midpoint,
            picard_midpoint=picard_midpoint,
            picard_midpoint_max_iter=20,
            picard_midpoint_tol=1e-12,
            on_step=(s, step) -> begin
                if step % 20 == 0
                    N_now = tdhfb_total_particle_number(s)
                    E_now = tdhfb_energy(s, F, g_S, V_ext)
                    @printf("%-5d  %-8.3f  %+10.3e   %+10.3e   %-12.6e  %-12.6e\n",
                        step, s.t,
                        (N_now - N_init) / N_init,
                        (E_now - E_init) / max(abs(E_init), 1e-12),
                        norm(s.rho), norm(s.kappa))
                end
            end,
        )
    end
    elapsed = time() - t_start

    @printf("\nFinal: ‖ρ‖=%.6e, ‖κ‖=%.6e, wall=%.1fs (%.1fms/step)\n",
        norm(state.rho), norm(state.kappa), elapsed, 1000 * elapsed / N_STEPS)
    return (
        scheme=scheme,
        picard_midpoint=picard_midpoint,
        rho=norm(state.rho),
        kappa=norm(state.kappa),
        wall=elapsed,
    )
end

@printf("=== v3 anti-polar setup: Strang vs A4 (Y4+picard_midpoint) ===\n")
@printf("F=%d, %d³, %d steps×dt=%.4f, T=%.2f\n",
    F, N_SPATIAL, N_STEPS, DT, N_STEPS * DT)

r_strang = _run("Baseline: plain Strang"; scheme=:strang, picard_midpoint=false)
r_a4 = _run("A4: Y4 + picard_midpoint=true"; scheme=:y4_midpoint, picard_midpoint=true)

@printf("\n%s\n=== Comparison ===\n%s\n", "="^70, "="^70)
@printf("%-30s  %-15s  %-15s  %-10s\n", "scheme", "‖ρ‖", "‖κ‖", "wall (s)")
@printf("%-30s  %-15.6e  %-15.6e  %-10.1f\n",
    "Strang", r_strang.rho, r_strang.kappa, r_strang.wall)
@printf("%-30s  %-15.6e  %-15.6e  %-10.1f\n",
    "Y4 + picard_midpoint", r_a4.rho, r_a4.kappa, r_a4.wall)

ratio_rho = r_a4.rho / r_strang.rho
ratio_kappa = r_a4.kappa / r_strang.kappa
@printf("\nρ ratio (A4 / Strang): %.4f\n", ratio_rho)
@printf("κ ratio (A4 / Strang): %.4f\n", ratio_kappa)

if abs(ratio_rho - 1.0) < 0.1
    @printf("→ ρ is dominated by physical generation (palindrome breakdown <10%% effect).\n")
elseif ratio_rho < 0.1
    @printf(
        "→ Prior Strang ρ was inflated by palindrome breakdown (A4 reveals smaller physical value).\n"
    )
elseif ratio_rho > 10.0
    @printf("→ Unexpected: A4 ρ larger than Strang. Investigate Picard convergence / setup.\n")
else
    @printf(
        "→ Intermediate: %.0f%% physical / %.0f%% truncation, partial palindrome breakdown effect.\n",
        100 * ratio_rho, 100 * (1 - ratio_rho))
end
