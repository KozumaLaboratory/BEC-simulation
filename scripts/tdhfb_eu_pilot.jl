# TDHFB Eu pilot — Phase 3 production code exercise.
#
# Small-scale F=6 Eu post-quench analog test.
#  - 16³ grid (Phase 1 scope; production = 32³ post-Phase 4)
#  - vacuum initial (ρ = κ = 0)
#  - 100 Strang steps × dt=0.001
#  - track: particle number drift, ρ Hermiticity, |κ|, energy
#
# Goal: verify tdhfb_strang_step! works end-to-end on F=6 ¹⁵¹Eu config and
# characterise drift rates against the Phase 3 test suite's 7/9 PASS status.
#
# Not a physics-publication run — just a workout. Real Eu post-quench needs
# Phase 4 YAML pipeline integration (task #77).
#
# Run: julia --project=. scripts/tdhfb_eu_pilot.jl

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const D = 2F + 1
const N_SPATIAL = 16  # grid points per dim
const DT = 0.001
const N_STEPS = 100
const BOX = 10.0

# F=6 Eu approximate channel couplings (from Ch.6 § 6.5):
#   c_0 = (1/13) g_0 + (121/323) g_6 + (147/391) g_10 + (980/5681) g_12
# Use simplest: g_S all = 1 (scalar limit, c_0 = 1, c_1 = 0 → no spin mixing).
# Real Eu has the icosahedral channel structure; this is a kinematic test.
const G_S = Dict{Int, Float64}(
    0 => 1.0,
    2 => 1.0,
    4 => 1.0,
    6 => 1.0,
    8 => 1.0,
    10 => 1.0,
    12 => 1.0,
)

@printf("=== TDHFB Eu pilot (F=%d, %d³ grid, scalar limit) ===\n", F, N_SPATIAL)

# Initial spinor: stretched m=+F (= polar boundary), tight Gaussian
phi0 = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
center = N_SPATIAL ÷ 2 + 1
sigma = 2.0  # in grid units
@inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
    r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
    g = exp(-r2 / (2 * sigma^2))
    phi0[i, j, k, 1] = g + 0im  # m=+F
end
# normalize
nrm = sqrt(sum(abs2, phi0))
phi0 ./= nrm

# Initialize TDHFBState (vacuum ρ = κ = 0)
state = init_tdhfb_vacuum(phi0)
@printf("Initial state: ||φ||² = %.6f, ||ρ|| = %.2e, ||κ|| = %.2e\n",
    sum(abs2, state.phi), norm(state.rho), norm(state.kappa))

# External trap potential (harmonic): V(r) = 0.5 (x² + y² + 1.4²·z²)
V_ext = zeros(Float64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
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

# Initial diagnostics
N_init = tdhfb_total_particle_number(state)
rho_dev_init, kappa_dev_init = tdhfb_hermiticity_check(state)
@printf("\nInitial: N = %.6f, ρ Hermiticity dev = %.2e, κ symmetry dev = %.2e\n",
    N_init, rho_dev_init, kappa_dev_init)

# Time loop via tdhfb_evolve! with per-step diagnostics callback.
@printf("\n%-6s  %-12s  %-12s  %-12s  %-12s  %-10s\n",
    "step", "t", "N (drift)", "‖ρ‖", "‖κ‖", "Herm dev")
t_start = time()
tdhfb_evolve!(state, F, G_S, V_ext, DT, N_STEPS;
    scheme=:strang,
    on_step=(s, step) -> begin
        if step % 10 == 0
            N_now = tdhfb_total_particle_number(s)
            rho_dev, kappa_dev = tdhfb_hermiticity_check(s)
            N_drift = (N_now - N_init) / N_init
            @printf("%-6d  %-12.5f  %+10.3e   %-12.6f  %-12.6f  %-10.2e\n",
                step, s.t, N_drift, norm(s.rho), norm(s.kappa),
                max(rho_dev, kappa_dev))
        end
    end,
)
elapsed = time() - t_start
@printf("\nElapsed: %.2f s for %d Strang steps (= %.1f ms/step)\n",
    elapsed, N_STEPS, 1000 * elapsed / N_STEPS)

# Final diagnostics
N_final = tdhfb_total_particle_number(state)
rho_dev_final, kappa_dev_final = tdhfb_hermiticity_check(state)
@printf("\n=== Final ===\n")
@printf("N drift: %.3e (over T = %.3f)\n", (N_final - N_init) / N_init, state.t)
@printf("ρ Hermiticity dev: %.2e\n", rho_dev_final)
@printf("κ symmetry dev: %.2e\n", kappa_dev_final)
@printf("‖ρ‖ = %.6f (initial 0)\n", norm(state.rho))
@printf("‖κ‖ = %.6f (initial 0)\n", norm(state.kappa))
