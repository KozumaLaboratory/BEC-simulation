#!/usr/bin/env julia
# scripts/sprint4_phase1_K3_calibration.jl
#
# Phase 1 calibration: find K_3 magnitude that reproduces Matsui's reported
# 40% loss over 40 ms (T=28 ω_ref⁻¹). The previous demo used K_3=0.003 with
# T=0.5 ω_ref⁻¹ and observed 0% loss — both T was too short and K_3 likely
# too small.
#
# Codebase applies loss per split-step as exp(-K_3 · n² · dt / 2), so for
# peak density n ~ 5, dt=0.005, the per-step exponent is K_3 · 0.0625, and
# the cumulative exponent over N steps is N · K_3 · 0.0625. Matsui's 40%
# loss ≈ exponent 0.5; at T=5 ω_ref⁻¹ (N=1000), K_3 ≈ 0.008 should give
# 50% loss. Sweep around that.
#
# Run:   julia --project=. scripts/sprint4_phase1_K3_calibration.jl
# Expected wall-clock: ~ 10 minutes on a single CPU core.

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
const T_EVOLVE = 5.0
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

const K3_VALUES = [0.0, 1.0, 5.0, 10.0, 50.0, 200.0]

function run_with_K3(k3::Float64)
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => C0_NOMINAL, 1 => C1_NOMINAL,
            2 => C2_NOMINAL, 4 => C4_NOMINAL, 6 => C6_NOMINAL),
    )
    sp = SimParams(; dt=DT, n_steps=N_STEPS, imaginary_time=false,
        normalize_every=0, save_every=N_STEPS)
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:m_minus_F)
    loss = k3 > 0 ? LossParams(; K3_cubic=k3) : nothing
    ws = make_workspace(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN_QUENCH, potential=POT, sim_params=sp,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
        loss=loss)
    dV = SpinorBEC.cell_volume(ws.grid)
    n_init = sum(abs2, ws.state.psi) * dV
    for _ in 1:N_STEPS
        SpinorBEC.split_step!(ws)
    end
    n_final = sum(abs2, ws.state.psi) * dV
    1.0 - n_final / n_init
end

function main()
    @printf "=== Phase 1 K_3 calibration vs Matsui 40%%/40 ms ===\n"
    @printf "T_evolve = %.1f ω_ref⁻¹ (%.1f ms), Matsui T_full ≈ 28 ω_ref⁻¹ (40 ms)\n" T_EVOLVE (
        T_EVOLVE / OMEGA_REF * 1e3
    )
    @printf "Expected loss at this T scales as ≈ Matsui_loss × T/T_full = 40%% × %.2f = %.0f%%\n" (
        T_EVOLVE / 28.0
    ) (40 * T_EVOLVE / 28.0)
    println()

    println("K_3 sweep:")
    @printf "  %-8s  %-8s\n" "K_3" "loss %"
    println("  " * "-"^20)
    for k3 in K3_VALUES
        print("  ")
        print(rpad(@sprintf("%.4f", k3), 8))
        print("  ")
        t0 = time()
        loss_frac = run_with_K3(k3)
        @printf "%5.1f%%   (%.1f s)\n" 100 * loss_frac (time() - t0)
    end

    println()
    println("Calibration target: ~7%% at T=5 (scaling from Matsui 40%%/40 ms).")
    println("Use the K_3 value giving ~7%% as the m-independent loss baseline;")
    println("Matsui's m-dependent profile can then be encoded as a perturbation")
    println("around it (cascade-product enhancement, stretched immunity).")
    println()
    println("=== Done ===")
end

main()
