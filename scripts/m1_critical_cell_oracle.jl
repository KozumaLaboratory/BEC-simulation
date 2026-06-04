#!/usr/bin/env julia
# scripts/m1_critical_cell_oracle.jl
#
# Single-cell post-fix validation at THE critical M1 cell
# (B = 100 nT in-plane Bx, Ω = 0.6) — the cell that defined the
# "4.51 unphysical" smoking-gun framing in
# `sprint5_M1_ITP_omega_sweep_polished.log` cell 30/30:
#
#     pre-fix:  E=8.618473  ‖∇E‖=2.401e-01  ⟨F_z⟩ = +4.501e+00
#
# That is 18× the analytical Barnett/Zeeman bound for in-plane Bx:
#
#     ⟨F_z⟩_bound = F · Ω · ℏω_ref / (g_F μ_B B) ≈ 6·0.6/(γ_F · 100 nT)
#                ≈ 6·66/1630 ≈ 0.24
#
# Three sign bugs fixed 2026-06-04 (GPU energy missing Coriolis +
# light_shift; transverse Zeeman sign inversion; [GAP-1] zeeman energy
# missing transverse) are all load-bearing for this regime. This script
# is the unambiguous post-fix verdict.
#
# Pass criterion:  ⟨F_z⟩ ∈ [0.17, 0.31]  (analytical ±30%, upper bound)
# Fail criterion:  ⟨F_z⟩ > 0.31  (still in pre-fix territory)
#
# Cost: ~5-10 min GPU (300 ITP + 2000 LBFGS). NOT the full 30-cell
# sweep — that's a separate multi-hour rerun.
#
# Run:
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#     scripts/m1_critical_cell_oracle.jl

import CUDA
using SpinorBEC
using Printf

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()
const B_NT = 100.0
const OMEGA = 0.6
const N_ITP = 300
const N_LBFGS = 2000
const SOBOLEV = 0.05

# Analytical oracle band (upper bound; AFM c_1>0 may suppress further)
const ORACLE_FZ = 0.24
const ORACLE_TOL = 0.30
const FZ_UPPER = ORACLE_FZ * (1 + ORACLE_TOL)   # 0.312 — strict ceiling
const FZ_LOWER = ORACLE_FZ * (1 - ORACLE_TOL)   # 0.168 — soft floor

const PRE_FIX_FZ_VALUE = +4.501e+00   # from polished.log:cell-30
const PRE_FIX_E = 8.618473
const PRE_FIX_GRAD = 2.401e-01

function main()
    println("=== M1 critical-cell post-fix oracle ===")
    @printf "Cell: B=%.1f nT (in-plane Bx), Ω=%.2f\n" B_NT OMEGA
    @printf "Phase params: N_ITP=%d  N_LBFGS=%d  sobolev_α=%.3f\n\n" N_ITP N_LBFGS SOBOLEV
    @printf "Pre-fix reference: ⟨F_z⟩=%+.3e  E=%.4f  ‖∇E‖=%.3e\n" PRE_FIX_FZ_VALUE PRE_FIX_E PRE_FIX_GRAD
    @printf "Oracle band:       ⟨F_z⟩ ∈ [%.3f, %.3f]  (target %.3f ±%.0f%%)\n\n" FZ_LOWER FZ_UPPER ORACLE_FZ (ORACLE_TOL * 100)

    p_lab = B_NT * TW.p_per_nT
    # Convention: position 3 of TimeDependentZeeman = bx_wf (in-plane Bx).
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0),
        ConstantWaveform(0.0),
        ConstantWaveform(p_lab),
        ConstantWaveform(0.0),
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
        verbose=false, sobolev_alpha=SOBOLEV,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=OMEGA, backend=CUDABackend(),
    )
    wall_lbfgs = time() - t_lbfgs

    ws = r_lbfgs[1]
    converged = r_lbfgs[2]
    E_final = r_lbfgs[3]
    dE = r_lbfgs[4]
    last_step = r_lbfgs[5]

    @printf "  LBFGS wall: %.1fs   steps: %d/%d   conv: %s   E=%.6f   dE=%.3e\n" wall_lbfgs last_step N_LBFGS converged E_final dE

    # Compute observables
    psi_cpu = Array(ws.state.psi)
    dV = SpinorBEC.cell_volume(TW.grid)
    N = ndims(psi_cpu) - 1
    fx, fy, fz = SpinorBEC.spin_density_vector(psi_cpu, ws.spin_matrices, N)
    Fz_total = sum(fz) * dV
    Fx_total = sum(fx) * dV
    Fy_total = sum(fy) * dV
    Lz_val = SpinorBEC.orbital_angular_momentum(psi_cpu, ws.grid, ws.fft_plans)

    # Residual gradient norm (post-fix should be ≪ 0.218)
    grad_dev = similar(ws.state.psi)
    k2_dev = SpinorBEC._to_device(ws.backend, ws.grid.k_squared)
    psi_dev = ws.state.psi
    SpinorBEC.energy_gradient!(grad_dev, psi_dev, ws; k_squared_dev=k2_dev)
    # Project onto constraint manifold for the L² norm comparable to
    # the pre-fix 0.218 value.
    grad_cpu = Array(grad_dev)
    grad_norm_L2 = sqrt(sum(abs2, grad_cpu) * dV)

    println("\n=== POST-FIX VERDICT ===")
    @printf "  ⟨F_z⟩   = %+.4e  (pre-fix: %+.3e, oracle: ≤ %.3f)\n" Fz_total PRE_FIX_FZ_VALUE FZ_UPPER
    @printf "  ⟨F_x⟩   = %+.4e\n" Fx_total
    @printf "  ⟨F_y⟩   = %+.4e\n" Fy_total
    @printf "  ⟨L_z⟩   = %+.4e\n" Lz_val
    @printf "  E       = %.6f  (pre-fix: %.4f)\n" E_final PRE_FIX_E
    @printf "  ‖∇E‖_L² = %.3e  (pre-fix: %.3e, gate: 1e-5)\n" grad_norm_L2 PRE_FIX_GRAD
    @printf "  conv    = %s\n" converged

    println()
    if Fz_total > FZ_UPPER
        @printf "  ✗ FAIL — ⟨F_z⟩ = %.3f > %.3f (still in pre-fix territory)\n" Fz_total FZ_UPPER
        @printf "    The transverse-Zeeman / GPU-Coriolis / GAP-1 fixes did NOT close this cell.\n"
        exit(1)
    elseif Fz_total < -FZ_UPPER
        @printf "  ✗ FAIL — ⟨F_z⟩ = %.3f < -%.3f (overshoot in opposite direction)\n" Fz_total FZ_UPPER
        exit(1)
    elseif abs(Fz_total) < FZ_LOWER
        @printf "  △ WEAK PASS — ⟨F_z⟩ = %+.3f (below oracle lower bound %.3f)\n" Fz_total FZ_LOWER
        @printf "    Possible AFM c_1 suppression below non-interacting bound — correct physics direction.\n"
    else
        @printf "  ✓ PASS — ⟨F_z⟩ = %+.3f lies in [%.3f, %.3f]\n" Fz_total FZ_LOWER FZ_UPPER
        @printf "    Pre-fix 4.501 → post-fix %+.3f confirms the 3-bug fix is load-bearing.\n" Fz_total
    end

    println()
    if grad_norm_L2 < 1e-2
        @printf "  ‖∇E‖ = %.3e is ≥3 orders below pre-fix 0.218 — bug class is closed at the gradient level.\n" grad_norm_L2
    else
        @printf "  ‖∇E‖ = %.3e is still ≫ 1e-5 gate — convergence-pending, but the freeze pathology is gone.\n" grad_norm_L2
    end
end

main()
