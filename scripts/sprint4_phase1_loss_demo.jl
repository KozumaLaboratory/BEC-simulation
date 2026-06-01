#!/usr/bin/env julia
# scripts/sprint4_phase1_loss_demo.jl
#
# Phase 1 of the original SBI roadmap: m-dependent 3-body loss demonstration.
# Uses the existing `LossParams.K3_per_m_cubic::Vector{Float64}` infrastructure
# (already present in `src/foundation/types/ddi_loss.jl`).
#
# The Matsui 2026 Science EdH paper reported ~40% loss over 40 ms in the weak
# Bz hold phase — a signature of m-dependent 3-body recombination. This demo
# runs the same stretched-cascade dynamics as Sprint 4 item 0 v2 but with two
# loss configurations:
#   (a) no loss baseline (Sprint 4 item 0 v2 setup, T=0.5 ω_ref⁻¹)
#   (b) uniform K_3 = 0.003 across all m (cascade-driven depopulation +
#       global 3-body loss)
#   (c) m-dependent K_3: stretched m=-F immune (0.0), depolarised m=-F+1..0
#       enhanced (0.005). Captures the qualitative Matsui signature where the
#       cascade products dominate loss.
#
# Validation aim: confirm that (i) the infrastructure delivers per-m loss
# rates, (ii) total norm decreases as expected, (iii) m-dependent loss
# reshapes the cascade signature beyond what cascade transfer alone does.
#
# Run:   julia --project=. scripts/sprint4_phase1_loss_demo.jl
# Expected wall-clock: ~ 5 minutes on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((12, 12, 12), (10.0, 10.0, 10.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.182))
const ZEEMAN_QUENCH = ZeemanParams(0.3, 0.0)
const T_EVOLVE = 0.5
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0_NOMINAL = C_TOTAL / (1 + F^2 / 36.0)
const C1_NOMINAL = C0_NOMINAL / 36.0
const C2_NOMINAL = 0.05 * C0_NOMINAL
const C4_NOMINAL = 0.02 * C0_NOMINAL
const C6_NOMINAL = 0.005 * C0_NOMINAL
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

# Stretched m=−F initial state under standard Sprint 4 item 0 cascade.
# Compares 3 loss configurations.

function build_workspace(loss::Union{Nothing, LossParams})
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => C0_NOMINAL, 1 => C1_NOMINAL,
            2 => C2_NOMINAL, 4 => C4_NOMINAL, 6 => C6_NOMINAL),
    )
    sp = SimParams(; dt=DT, n_steps=N_STEPS, imaginary_time=false,
        normalize_every=0, save_every=N_STEPS)
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:m_minus_F)
    make_workspace(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN_QUENCH, potential=POT, sim_params=sp,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
        loss=loss)
end

function evolve_and_report(ws, label)
    dV = SpinorBEC.cell_volume(ws.grid)
    n_init = sum(abs2, ws.state.psi) * dV
    for _ in 1:N_STEPS
        SpinorBEC.split_step!(ws)
    end
    n_final = sum(abs2, ws.state.psi) * dV
    loss_frac = 1.0 - n_final / n_init
    # Per-m populations after evolution
    psi = ws.state.psi
    D = 2F + 1
    n_per_m = Float64[sum(abs2, view(psi,:,:,:,c)) * dV for c in 1:D]
    n_per_m_asc = reverse(n_per_m)
    println()
    println("--- $label ---")
    @printf "  total norm: %.4f → %.4f  (loss %.1f%%)\n" n_init n_final 100 * loss_frac
    println("  per-m populations (ascending m=-F..+F):")
    for m in (-F):F
        idx = m + F + 1
        n_per_m_asc[idx] > 1e-4 &&
            @printf "    m=%+d : %.5f\n" m n_per_m_asc[idx]
    end
    (loss_frac=loss_frac, n_per_m=n_per_m_asc)
end

function main()
    println("=== Phase 1 demo: m-dependent 3-body loss in stretched EdH cascade ===")
    println("Atom: $(ATOM.name), N=$N_ATOMS, T_evolve=$T_EVOLVE ω_ref⁻¹")
    println("Comparing 3 loss configurations under identical c, B, dynamics.")

    # (a) no loss baseline
    print("\n(a) Building workspace (no loss baseline) ... ")
    t0 = time()
    ws_a = build_workspace(nothing)
    @printf "%.1f s\n" (time() - t0)
    print("    Evolving ... ")
    t0 = time()
    out_a = evolve_and_report(ws_a, "(a) no loss")
    @printf "    %.1f s\n" (time() - t0)

    # (b) uniform K_3
    print("\n(b) Building workspace (uniform K_3=0.003) ... ")
    t0 = time()
    loss_b = LossParams(; K3_cubic=0.003)
    ws_b = build_workspace(loss_b)
    @printf "%.1f s\n" (time() - t0)
    print("    Evolving ... ")
    t0 = time()
    out_b = evolve_and_report(ws_b, "(b) uniform K_3 = 0.003")
    @printf "    %.1f s\n" (time() - t0)

    # (c) m-dependent K_3: stretched immune, cascade products enhanced
    k3_per_m = zeros(Float64, 2F + 1)
    for c in 1:(2F + 1)
        m = F - (c - 1)   # codebase order: c=1 ↔ m=+F
        if m == -F            # stretched component (immune)
            k3_per_m[c] = 0.0
        elseif m <= 0         # depolarised cascade products
            k3_per_m[c] = 0.005
        else                  # m > 0 (shouldn't populate from m=-F under MDDI Δm=+1)
            k3_per_m[c] = 0.001
        end
    end
    print("\n(c) Building workspace (m-dep K_3, stretched immune) ... ")
    t0 = time()
    loss_c = LossParams(; K3_per_m_cubic=k3_per_m)
    ws_c = build_workspace(loss_c)
    @printf "%.1f s\n" (time() - t0)
    print("    Evolving ... ")
    t0 = time()
    out_c = evolve_and_report(ws_c, "(c) m-dep K_3, stretched immune")
    @printf "    %.1f s\n" (time() - t0)

    println()
    println("=== Summary ===")
    @printf "  (a) no loss     : total loss %.1f%%\n" 100 * out_a.loss_frac
    @printf "  (b) uniform K3  : total loss %.1f%%\n" 100 * out_b.loss_frac
    @printf "  (c) m-dep K3    : total loss %.1f%%\n" 100 * out_c.loss_frac
    println()
    println("Interpretation:")
    if abs(out_b.loss_frac - out_c.loss_frac) > 0.01
        println("  (b) and (c) loss fractions differ → m-dependent K_3 ≠ uniform-equivalent.")
        println("  The cascade products experience higher loss than stretched, reshaping")
        println("  the post-evolution m-distribution. This is the Matsui signature.")
    else
        println("  (b) and (c) close to equal → cascade fraction too small at T=$T_EVOLVE for")
        println("  m-dependence to dominate. Push T further to see the Matsui-regime split.")
    end
    println()
    println("=== Phase 1 demo complete ===")
end

main()
