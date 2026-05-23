# A4 acceptance criterion #2 — Y4 Yoshida composition order on TDHFB.
#
# Design ref: `docs/design/tdhfb_y4_palindromic_substep_design.md` §6.
# Companion to `scripts/diagnostic/tdhfb_palindromic_gate.jl`.
#
# Yoshida-4 composition `S₄ = S₂(w₁·dt) ∘ S₂(w₀·dt) ∘ S₂(w₁·dt)` with
#   w₁ = 1/(2 - 2^(1/3)),  w₀ = 1 - 2w₁
# delivers global order 4 IFF S₂ is palindromic at O(dt⁵).
#
# Current state: S₂ (`tdhfb_strang_step!`) is palindromic only at O(dt²)
# (per `tdhfb_palindromic_gate.jl`). Composition collapses to order 2.
# A4 Option B implementation must lift S₂'s palindromicity → Y4 reaches
# order 4.
#
# This bench measures the EFFECTIVE order of `tdhfb_y4_midpoint_step!`
# against a fine-dt reference. Output: log₂(err(dt) / err(dt/2)) ≈ order.
#
# Acceptance: order ≥ 3.5 (within slop of theoretical 4) after A4 Option B
# implementation.
#
# Run: julia --project=. scripts/bench/track_a4_y4_order.jl

using SpinorBEC
using Printf
using Random
using LinearAlgebra

const F = 1
const D = 2F + 1
const NX = 16
const SPATIAL = (NX, NX, NX)
const T_FINAL = 0.04

function _build_state(seed::Int)
    rng = MersenneTwister(seed)
    phi = randn(rng, ComplexF64, SPATIAL..., D) * 0.1
    rho = zeros(ComplexF64, SPATIAL..., D, D)
    kappa = zeros(ComplexF64, SPATIAL..., D, D)
    for I in CartesianIndices(SPATIAL)
        rho_loc = randn(rng, ComplexF64, D, D) * 0.05
        rho_loc = 0.5 * (rho_loc + adjoint(rho_loc))
        for c in 1:D
            rho_loc[c, c] += 0.05
        end
        kappa_loc = randn(rng, ComplexF64, D, D) * 0.05
        kappa_loc = 0.5 * (kappa_loc + transpose(kappa_loc))
        for c in 1:D, cp in 1:D
            rho[I, c, cp] = rho_loc[c, cp]
            kappa[I, c, cp] = kappa_loc[c, cp]
        end
    end
    SpinorBEC.TDHFBState{3, typeof(phi), typeof(rho), Float64}(
        phi, rho, kappa, 0.0, 0,
    )
end

function _run_y4(state0, dt, F, g_S, V_ext)
    state = deepcopy(state0)
    n_steps = Int(round(T_FINAL / dt))
    actual_dt = T_FINAL / n_steps
    for _ in 1:n_steps
        SpinorBEC.tdhfb_y4_midpoint_step!(state, F, g_S, V_ext, actual_dt;
            hfb_mode=:full_hfb,
        )
    end
    state
end

function _state_diff(s1, s2)
    max(
        maximum(abs.(s1.phi .- s2.phi)),
        maximum(abs.(s1.rho .- s2.rho)),
        maximum(abs.(s1.kappa .- s2.kappa)),
    )
end

# ===== Run =====
@printf("=== TDHFB Y4 Yoshida composition order test ===\n")
@printf("Problem: F=%d, grid=%s, T_FINAL=%.3f, random Hermitian ρ + symmetric κ init\n",
    F, SPATIAL, T_FINAL)
@printf("A4 acceptance: order ≥ 3.5 (target = 4)\n")
@printf("Current expectation: order ≈ 2 (Strang substep not palindromic at O(dt⁵))\n\n")

state0 = _build_state(42)
g_S = Dict{Int, Float64}(0 => 0.5, 2 => 0.1)
V_ext = zeros(Float64, SPATIAL..., D)

# Reference: Y4 at dt = 2.5e-4 (smallest)
@printf("Building reference (Y4 at dt=2.5e-4, %d steps)... ", Int(T_FINAL / 2.5e-4))
flush(stdout)
t_ref = time()
state_ref = _run_y4(state0, 2.5e-4, F, g_S, V_ext)
@printf("done (%.1fs)\n\n", time() - t_ref)

dts = [4.0e-3, 2.0e-3, 1.0e-3, 5.0e-4]

@printf("%-10s  %-14s  %-14s  %-14s  %-10s\n",
    "dt", "φ err", "ρ err", "κ err", "order")
prev_err = NaN
for dt in dts
    state_test = _run_y4(state0, dt, F, g_S, V_ext)
    err = _state_diff(state_test, state_ref)
    ord = isnan(prev_err) ? NaN : log2(prev_err / err)
    # Re-compute per-component for reporting
    phi_e = maximum(abs.(state_test.phi .- state_ref.phi))
    rho_e = maximum(abs.(state_test.rho .- state_ref.rho))
    kappa_e = maximum(abs.(state_test.kappa .- state_ref.kappa))
    @printf("%-10.4f  %-14.4e  %-14.4e  %-14.4e  %s\n",
        dt, phi_e, rho_e, kappa_e,
        isnan(ord) ? "—" : @sprintf("%.2f", ord))
    global prev_err = err
end

@printf("\n%s\n", "═"^60)
@printf("Acceptance: order ≥ 3.5 → A4 PASS\n")
@printf("Documented current state: order ≈ 2 (Option B fix needed)\n")
@printf("%s\n", "═"^60)
