#!/usr/bin/env julia
# scripts/m1_postfix_lbfgs_smoke.jl
#
# Cold-start LBFGS smoke at B=0/Ω=0.4 (the cell that defined the M1
# freeze) to verify the 2026-06-04 GPU energy fix
# (`mistake_gpu_energy_decomposition_missing_coriolis_2026_06_04`) makes
# LBFGS actually converge instead of plateauing at `‖∇E‖_{L²} ≈ 0.2`.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/m1_postfix_lbfgs_smoke.jl
#
# Cost: ~2-3 min GPU (300 ITP warm-start + 500 LBFGS).

import CUDA
using SpinorBEC
using Printf
const TW = eu151_preset()
const B_NT = 0.0
const OMEGA = 0.4
const N_ITP = 300
const N_LBFGS = 2000
const SOBOLEV = 0.05      # same as the converged-sweep recipe

function main()
    println("=== M1 post-fix LBFGS smoke ===")
    @printf "Cell: B=%.1f nT, Ω=%.2f\n" B_NT OMEGA
    @printf "N_ITP=%d  N_LBFGS=%d  sobolev_α=%.3f\n\n" N_ITP N_LBFGS SOBOLEV

    p_lab = B_NT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )

    println("--- Phase 1: ITP warm-start ---")
    t_itp = time()
    r_itp = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=0.005, n_steps=N_ITP, tol=1e-7,
        initial_state=:polar, verbose=false,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=OMEGA, backend=CUDABackend(),
    )
    @printf "  ITP wall: %.1fs   E_itp = %.6f\n\n" (time() - t_itp) r_itp.energy

    println("--- Phase 2: LBFGS polish ---")
    t_lbfgs = time()
    r_lbfgs = SpinorBEC.find_ground_state_lbfgs(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        psi_init=Array(r_itp.workspace.state.psi),
        n_steps=N_LBFGS, tol=1e-7,
        verbose=true, sobolev_alpha=SOBOLEV,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=OMEGA, backend=CUDABackend(),
    )
    wall_lbfgs = time() - t_lbfgs

    converged = r_lbfgs[2]
    E_final = r_lbfgs[3]
    dE = r_lbfgs[4]
    last_step = r_lbfgs[5]

    @printf "  LBFGS wall: %.1fs\n" wall_lbfgs
    @printf "  steps taken: %d / %d\n" last_step N_LBFGS
    @printf "  converged: %s\n" converged
    @printf "  E_final: %.6f\n" E_final
    @printf "  dE_final: %.3e\n\n" dE

    # Direct evaluate ‖P_⊥∇E‖_L² on the polished state to compare
    # with the pre-fix plateau magnitude 0.218.
    ws = r_lbfgs[1]
    dV = SpinorBEC.cell_volume(TW.grid)
    psi_cpu = Array(ws.state.psi)
    grad_dev = similar(ws.state.psi)
    k2_dev = SpinorBEC._to_device(ws.backend, ws.grid.k_squared)
    SpinorBEC.energy_gradient!(grad_dev, ws.state.psi, ws; k_squared_dev=k2_dev)
    grad_cpu = Array(grad_dev)
    psi_norm² = sum(abs2, psi_cpu) * dV
    μ = real(sum(conj.(grad_cpu) .* psi_cpu)) * dV / psi_norm²
    proj = grad_cpu .- μ .* psi_cpu
    R = sqrt(real(sum(abs2, proj)) * dV)
    @printf "Final ‖P_⊥∇E‖_L² = %.3e   (pre-fix plateau was 2.18e-1)\n" R
    @printf "  μ = %.4f\n\n" μ

    println("=== Verdict ===")
    if converged
        println("✓ LBFGS CONVERGED. The GPU energy fix resolves the M1 freeze.")
    elseif R < 1e-2
        @printf "≈ Effectively converged (‖P_⊥∇E‖ = %.2e < 1e-2) but tol=1e-7 not\n" R
        println("  reached. Either tighten tol or increase n_steps; physics looks fine.")
    elseif R < 0.1
        @printf "PARTIAL — ‖P_⊥∇E‖ = %.2e is a ~5× improvement over 0.218,\n" R
        println("  not yet sub-basin. Try longer n_steps or different sobolev_alpha.")
    else
        @printf "STILL FROZEN at ‖P_⊥∇E‖ = %.2e — there's a second issue.\n" R
        println("  Run `scripts/m1_per_term_gradient_audit.jl` on the new stalled ψ.")
    end
end

main()
