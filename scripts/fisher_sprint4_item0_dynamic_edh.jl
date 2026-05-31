#!/usr/bin/env julia
# scripts/fisher_sprint4_item0_dynamic_edh.jl
#
# Sprint-4 item 0 (CLOSED — rank 1 baseline confirmed). Linear-cascade Fisher
# on the m=−F EdH prep, run on Eu151 F=6 with full DDI for 0.5 ω_ref⁻¹ at the
# Matsui Phase 2 Zeeman scale (p=0.3 ≈ 2.6 nT). Companion to the Sprint-3
# static stretched gate; together they establish that the stretched-cascade
# subspace is structurally 1-D in c-space at linear order.
#
# Conclusion (recorded in sprint3_static_gate_baseline_2026_06_01.md):
# measurable rank = 1 / 5 with the one MEAS direction exactly aligned with
# c_0 + F²·c_1 = g_{S=2F} = the already-known a_12 prior. The other 4
# directions are null with eigenvalues 1e−9 … 1e−17. This is structural:
#   - MDDI Δm=±1 matrix elements are c-independent
#   - c_2 (singlet pair, M=0) is unreachable from stretched M=−2F
#   - c_4 / c_6 (rank-4/6 tensor) don't couple stretched ↔ (stretched−1) at
#     first order
# The Matsui paper's c_1-sign discrimination via m=−4 ring count is a
# second-order cascade effect outside linear Fisher; it requires non-linear
# SBI (SNPE/SNRE) on long-T dynamics, or one of the Sprint-4 items 1-3
# (non-stretched prep / microwave Feshbach / interferometric phase).
#
# Historic bug fixes documented in commit log:
#   - psi[..., c=1] is m=+F per codebase convention; populations were
#     reversed for ascending-m presentation
#   - secular_ddi defaults true in the codebase but its validity window
#     ω_L/(c_dd·⟨n⟩) > 100 is wrong for Eu EdH; full DDI required for
#     cascade physics
#
# Run:   julia --project=. scripts/fisher_sprint4_item0_dynamic_edh.jl
# Expected wall-clock: ~ 2 minutes on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((12, 12, 12), (10.0, 10.0, 10.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.182))
const ZEEMAN_QUENCH = ZeemanParams(0.3, 0.0)   # Matsui Phase 2 (~2.6 nT scale)
const T_EVOLVE = 0.5                            # ~0.7 ms in ω_ref⁻¹ units (linear-cascade regime)
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))

# Dimensionless c_0 with c1_ratio=1/36 (textbook Matsui truncation)
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0_NOMINAL = C_TOTAL / (1 + F^2 / 36.0)
const C1_NOMINAL = C0_NOMINAL / 36.0
const C2_NOMINAL = 0.05 * C0_NOMINAL
const C4_NOMINAL = 0.02 * C0_NOMINAL
const C6_NOMINAL = 0.005 * C0_NOMINAL
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const PARAM_NAMES = ["c_0", "c_1", "c_2", "c_4", "c_6"]

"""Build workspace at (c, weak-Bz) with m=−F initial state, evolve T_EVOLVE."""
function forward_dynamic_edh(c::AbstractVector{<:Real})
    length(c) == 5 || error("expected 5 params (c_0, c_1, c_2, c_4, c_6)")
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => Float64(c[1]), 1 => Float64(c[2]),
            2 => Float64(c[3]), 4 => Float64(c[4]), 6 => Float64(c[5])),
    )
    sp = SimParams(; dt=DT, n_steps=N_STEPS, imaginary_time=false,
        normalize_every=0, save_every=N_STEPS)
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:m_minus_F)
    ws = make_workspace(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN_QUENCH, potential=POT, sim_params=sp,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false)   # FULL DDI: cascade requires Δm coupling
    for _ in 1:N_STEPS
        SpinorBEC.split_step!(ws)
    end
    ws
end

"""Reduce ws → f_m vector ordered m = -F..+F (length 2F+1).

Codebase convention: psi[..., c=1] holds m=+F and psi[..., c=D] holds m=−F
(CLAUDE.md). The forward-image / SBI side wants m ordered ascending, so we
reverse here.
"""
function summary_populations(ws)
    psi = ws.state.psi
    F_loc = ws.atom.F
    dV = SpinorBEC.cell_volume(ws.grid)
    # n_by_component[c=1..D] = population in (m = F - (c-1)) — descending in m.
    n_by_component = Float64[sum(abs2, view(psi,:,:,:,c)) * dV
                             for c in 1:(2F_loc + 1)]
    # Reverse so output[1] = m=-F, output[end] = m=+F (ascending m).
    n_ascending_m = reverse(n_by_component)
    n_ascending_m ./ sum(n_ascending_m)
end

function main()
    println("=== Sprint-4 item 0: dynamic EdH Fisher ===")
    println("Atom: $(ATOM.name), N=$N_ATOMS, ω_ref=$OMEGA_REF rad/s")
    println("Grid: 12³ harmonic trap, λ_z = 1.182 (matches Matsui ω/2π = 110/130 Hz)")
    println("Quench Zeeman: p=$(ZEEMAN_QUENCH.p) (~2.6 nT)")
    @printf "c_dd (dimless) = %.4g   (Eu MDDI)\n" C_DD_DIMLESS
    @printf "Evolution: T=%.2f ω_ref⁻¹ = %.2f ms, dt=%.4f, N_steps=%d\n" T_EVOLVE (
        T_EVOLVE / OMEGA_REF * 1e3
    ) DT N_STEPS
    println("Observables: f_m for m = -6, -5, ..., +6  (length 13, populations normalised)")
    println()

    c_nominal = [C0_NOMINAL, C1_NOMINAL, C2_NOMINAL, C4_NOMINAL, C6_NOMINAL]

    # First run: nominal, time it, print f_m to confirm cascade is non-trivial
    print("Computing nominal forward (1 run) ... ")
    t0 = time()
    ws0 = forward_dynamic_edh(c_nominal)
    y0 = summary_populations(ws0)
    nominal_time = time() - t0
    @printf "%.1f s\n" nominal_time

    println()
    println("Nominal post-evolution populations (cascade signature):")
    for m in (-F):F
        idx = m + F + 1
        bar = "█"^max(0, round(Int, y0[idx] * 40))
        @printf "  f[m=%+d] = %.4e  %s\n" m y0[idx] bar
    end
    println()
    # Initial state was m=-F (ascending order: index 1).
    cascade_amplitude = 1.0 - y0[1]
    @printf "Depolarisation amplitude (1 − f[m=−F]) = %.4e\n" cascade_amplitude
    if cascade_amplitude < 1e-6
        println("  WARNING: cascade signal too small to extract c sensitivity.")
        println("  Increase T_EVOLVE or N_ATOMS (raises c_dd·n); aborting Fisher.")
        return nothing
    elseif cascade_amplitude > 0.7
        println("  WARNING: cascade > 70% — likely saturated, linear FD regime broken.")
        println("  Reduce T_EVOLVE for clean Fisher; continuing anyway.")
    end

    @printf "\nFisher FD will need 10 more runs (5 params × 2 sides), ETA %.1f s ... " (
        10 * nominal_time
    )
    t0 = time()
    J = fisher_jacobian(forward_dynamic_edh, c_nominal, summary_populations;
        delta_frac=1e-3, delta_floor=1e-6)
    @printf "%.1f s\n" (time() - t0)
    println()

    # Noise model: absolute 1e-3 per population fraction
    sigma_y = fill(1e-3, length(y0))
    fish = fisher_information(J, sigma_y)

    println("Fisher eigenvalues (ascending):")
    for (i, v) in enumerate(fish.eigenvalues)
        @printf "  λ_%d = %.4e\n" i v
    end
    println()

    ident = identifiable_directions(fish; cutoff_ratio=1e-4, param_names=PARAM_NAMES)
    println(ident.summary)
    println()
    println("Direction breakdown (eigenvectors in c-basis):")
    for i in 1:length(c_nominal)
        v = ident.eigenvectors[:, i]
        tag = ident.is_identifiable[i] ? "MEAS" : "NULL"
        σstr =
            isfinite(ident.posterior_sigma[i]) ?
            @sprintf("%.3e", ident.posterior_sigma[i]) : "Inf"
        @printf "  Dir %d [%s] σ_post=%s :  %s\n" i tag σstr join(
            (@sprintf("%+.3f·%s", v[k], PARAM_NAMES[k]) for k in 1:5), "  ")
    end

    println()
    println("--- Interpretation guide (post-closure) ---")
    println("Expected rank = 1, MEAS direction ≈ (1, F², 0, 0, 0) / √(1+F⁴) ⇒ g_{2F}.")
    println("σ_post on the g_{2F} combination is what the cascade *would* measure")
    println("if a_12 were not already pinned by prior; with prior, NEW c info = 0.")
    println("MEAS eigenvector's apparent c_1 dominance is the F²=36 weighting in")
    println("g_{2F} = c_0 + F²·c_1 — not an independent c_1 measurement.")
    println()
    println("Breaking the 4 NULL directions requires (Sprint-4 items 1-4):")
    println("  1. non-stretched (m=0 polar) prep — cascade products carry c_2")
    println("  2. microwave Feshbach — direct a_S response curve")
    println("  3. interferometric continuous-phase fringes")
    println("  4. nonlinear SBI on long-T cascade — Matsui m=−4 ring count → c_1 sign")
    println()
    println("=== Sprint-4 item 0 complete ===")
end

main()
