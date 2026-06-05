#!/usr/bin/env julia
# scripts/m0_cpu_gpu_propagator_parity.jl
#
# Cheap screen (priority A per user 2026-06-04):
#
#   The GPU `_energy_decomposition_gpu` bug we fixed today was a missing
#   term in ONE of the two paths (energy vs gradient). M0 dynamics is
#   driven by the PROPAGATOR — `split_step!`. If the GPU propagator has
#   an analogous missing-term bug at M0 parameters (Eu Matsui dynamics),
#   the 5–10× M0 time-constant anomaly could be explained without any
#   physics-level investigation.
#
# Test: run M0 EdH dynamics at small grid (16³, ~30 s wall each) on CPU
# and GPU; compare per-m populations N_m(t) and per-term energies
# E_term(t). If they agree to F64 noise → GPU propagator is clean →
# anomaly is physics, not bookkeeping → schedule M0 sprint. If they
# disagree → find the diverging term → fix → re-run M0 cheaply.
#
# Cost: ~1 min CPU + ~30 s GPU + analyze.

import CUDA
using SpinorBEC
using Printf
const TW_LARGE = eu151_preset()  # for atom/c_dd/p_per_nT
const ATOM = TW_LARGE.atom

# Override grid for parity test — match TW physical params but use 16³.
const GRID = make_grid(GridConfig{3}((16, 16, 16), TW_LARGE.grid.config.box_size))
const POTENTIAL = TW_LARGE.potential
const C_DD = TW_LARGE.c_dd
const INTERACTIONS = TW_LARGE.interactions

const P_DYNAMICS = 0.385                # Matsui Phase-2 quench Bz
const T_EVOLVE = 5.0                    # ω_ref⁻¹ (~8 ms physical)
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))
const SAMPLE_EVERY = 100

function run_dynamics(backend)
    sys = SpinSystem(TW_LARGE.F)
    psi_init = init_psi(GRID, sys; state=:m_minus_F)
    zeeman = ZeemanParams(P_DYNAMICS, 0.0)
    sp = SimParams(; dt=DT, n_steps=N_STEPS, imaginary_time=false,
        normalize_every=0, save_every=SAMPLE_EVERY)
    ws = make_workspace(;
        grid=GRID, atom=ATOM, interactions=INTERACTIONS,
        zeeman=zeeman, potential=POTENTIAL, sim_params=sp,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD, secular_ddi=false,
        backend=backend,
    )
    dV = SpinorBEC.cell_volume(GRID)
    times = Float64[0.0]
    N_m_t = Vector{Vector{Float64}}()
    psi_cpu = Array(ws.state.psi)
    push!(N_m_t, [sum(abs2, view(psi_cpu,:,:,:,c)) * dV for c in 1:(2 * TW_LARGE.F + 1)])
    t0 = time()
    for step in 1:N_STEPS
        SpinorBEC.split_step!(ws)
        if step % SAMPLE_EVERY == 0
            t_now = step * DT
            push!(times, t_now)
            psi_now = Array(ws.state.psi)
            push!(N_m_t, [sum(abs2, view(psi_now,:,:,:,c)) * dV for c in 1:(2 * TW_LARGE.F + 1)])
        end
    end
    wall = time() - t0
    backend isa CUDABackend && CUDA.reclaim()
    return (times=times, N_m_t=N_m_t, wall=wall)
end

function main()
    println("=== M0 CPU / GPU propagator parity (16³, T=5 ω_ref⁻¹) ===\n")

    println("--- CPU ---")
    r_cpu = run_dynamics(CPUBackend())
    @printf "  wall: %.1fs\n" r_cpu.wall
    @printf "  N_{-F}: %.6f → %.6f\n" r_cpu.N_m_t[1][end] r_cpu.N_m_t[end][end]
    @printf "  N_{-5}: %.6f → %.6f\n" r_cpu.N_m_t[1][end - 1] r_cpu.N_m_t[end][end - 1]
    @printf "  Total norm: %.6f → %.6f\n\n" sum(r_cpu.N_m_t[1]) sum(r_cpu.N_m_t[end])

    println("--- GPU ---")
    r_gpu = run_dynamics(CUDABackend())
    @printf "  wall: %.1fs\n" r_gpu.wall
    @printf "  N_{-F}: %.6f → %.6f\n" r_gpu.N_m_t[1][end] r_gpu.N_m_t[end][end]
    @printf "  N_{-5}: %.6f → %.6f\n" r_gpu.N_m_t[1][end - 1] r_gpu.N_m_t[end][end - 1]
    @printf "  Total norm: %.6f → %.6f\n\n" sum(r_gpu.N_m_t[1]) sum(r_gpu.N_m_t[end])

    println("--- Per-m parity (final-time difference) ---")
    @printf "%4s  %12s  %12s  %12s\n" "m" "CPU_final" "GPU_final" "|Δ|"
    println("-"^54)
    max_diff = 0.0
    max_diff_m = 0
    for c in 1:(2 * TW_LARGE.F + 1)
        m = TW_LARGE.F - (c - 1)
        cpu = r_cpu.N_m_t[end][c]
        gpu = r_gpu.N_m_t[end][c]
        diff = abs(cpu - gpu)
        @printf "%+4d  %.6e  %.6e  %.3e\n" m cpu gpu diff
        if diff > max_diff
            max_diff = diff
            max_diff_m = m
        end
    end
    @printf "\nMax |Δ N_m| = %.3e at m=%d\n" max_diff max_diff_m

    println("\n--- Verdict ---")
    if max_diff < 1e-6
        println("✓ CPU/GPU propagator parity CLEAN (max |Δ| < 1e-6).")
        println("  → M0 5-10× anomaly is NOT a GPU missing-term bug.")
        println("  → Next cheap check: units/time scaling vs analytic Larmor / EdH onset.")
    elseif max_diff < 1e-3
        println("≈ CPU/GPU agree to ~1e-3 (F64-borderline). Likely OK but verify with longer T.")
    else
        @printf "✗ CPU/GPU DIVERGE — Δ = %.3e at m=%d. Find the missing-term substep.\n" max_diff max_diff_m
        println("  → Audit each propagator substep (spin_mixing, singlet_pair, tensor,")
        println("    DDI, Coriolis, transverse_zeeman) for CPU/GPU per-substep output.")
    end
end

main()
