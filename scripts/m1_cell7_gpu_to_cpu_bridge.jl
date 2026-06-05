#!/usr/bin/env julia
# scripts/m1_cell7_gpu_to_cpu_bridge.jl
#
# CPU→GPU bridge for the cell-7 finding (2026-06-05 user-flagged closure).
#
# Per-term FD oracle (m1_cell7_grad_oracle.jl) closed:
#   - per-term CPU `_grad_<term>!` agrees with directional FD at 8³ CPU.
#
# Per-term GPU↔CPU parity gate (test_gpu_cpu_per_term_parity.jl):
#   - per-term CPU == per-term GPU for each term in isolation.
#
# Per-term gate ⊥ fused-axis (test_gpu_cpu_fused_group_parity.jl):
#   - fused (c0+c1+zeeman_z+light_shift+LHY) CPU == GPU at 16-pt 1D, F=1.
#
# But none of these directly verify: at the EXACT GPU 24³ F=6 state the
# sweep stalled at, the FULL combined ‖∇E‖ matches between CPU and GPU.
# Combinatorial residue (any 2-3 way ordering bug in Ω≠0 + DDI + F=6
# fused step) would survive every gate above.
#
# This 1-number test closes the gap:
#   1. Read the GPU-converged-at-1.4e-3 ψ from disk
#   2. Build a CPU workspace at the SAME parameters
#   3. Compute ‖∇E‖_CPU via energy_gradient! analytically
#   4. Compare with the reported GPU ‖∇E‖
#
# Match → CPU≡GPU at the live cell-7 state → bug class fully closed
# Mismatch → residual fused-axis bug at Eu F=6 24³ + Ω≠0 + DDI

using SpinorBEC
using SpinorBEC: energy_gradient!
using JLD2
using LinearAlgebra
using Printf

const CELL_PATH = "runs/sprint5_M1_ITP_omega_sweep_converged/cell_B1.0_Om0.10.jld2"
const TW = eu151_preset()  # 24³, N=5×10⁴ (migrated from scripts/lib/eu_digital_twin.jl)

function main()
    @info "Bridge oracle: cell 7 GPU state → CPU ‖∇E‖"

    isfile(CELL_PATH) || error("Cell file missing: $CELL_PATH")
    cached = JLD2.load(CELL_PATH)
    psi_gpu_state = cached["psi"]  # the actual GPU-stalled state
    result = cached["result"]
    B_nT = Float64(result["B_nT"])
    Ω = Float64(result["omega"])
    grad_norm_gpu = Float64(result["grad_norm"])
    seed = result["seed"]

    @printf "cell file:      %s\n" CELL_PATH
    @printf "B = %.1f nT  Ω = %.2f  seed = %s\n" B_nT Ω seed
    @printf "GPU-reported ‖∇E‖ = %.3e\n\n" grad_norm_gpu

    # Build CPU workspace at the SAME parameters
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0),
        ConstantWaveform(0.0),
        ConstantWaveform(p_lab),
        ConstantWaveform(0.0),
    )
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=Ω)

    @info "Building CPU workspace (24³ Eu F=6, Ω=$Ω, p_lab=$p_lab)"
    ws_cpu = make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        # backend defaults to CPU
    )
    copyto!(ws_cpu.state.psi, psi_gpu_state)

    @info "Computing CPU analytic gradient (this is the bridge number)"
    grad_cpu = similar(ws_cpu.state.psi)
    fill!(grad_cpu, 0)
    t0 = time()
    E_cpu = energy_gradient!(grad_cpu, ws_cpu.state.psi, ws_cpu)
    # CRITICAL: the LBFGS driver reports `grad_norm` AFTER `_project_constraints!`
    SpinorBEC._project_constraints!(grad_cpu, ws_cpu.state.psi, ws_cpu.grid,
        nothing, ws_cpu.spin_matrices.system.F)
    t_cpu = time() - t0

    dV = SpinorBEC.cell_volume(TW.grid)
    grad_norm_cpu = sqrt(sum(abs2, grad_cpu) * dV)

    # Sanity reports
    psi_norm = sqrt(sum(abs2, ws_cpu.state.psi) * dV)
    E_recompute_decomp = SpinorBEC.energy_decomposition(ws_cpu)
    println("\n--- Sanity reports ---")
    @printf "‖ψ‖_L²       = %.8f   (should be 1.0)\n" psi_norm
    @printf "E (gradient) = %.6f\n" E_cpu
    @printf "E (sweep)    = %.6f\n" Float64(result["E"])
    @printf "E (decomp)   = %.6f\n" E_recompute_decomp.total
    println("  per-term:")
    for f in propertynames(E_recompute_decomp)
        v = getproperty(E_recompute_decomp, f)
        @printf "    %-20s = %+.6e\n" string(f) Float64(v)
    end

    println("\n=== Bridge result ===")
    @printf "CPU ‖∇E‖   = %.6e   (computed in %.2f s)\n" grad_norm_cpu t_cpu
    @printf "GPU ‖∇E‖   = %.6e\n" grad_norm_gpu
    ratio = grad_norm_cpu / grad_norm_gpu
    rel_err = abs(ratio - 1.0)
    @printf "Ratio      = %.6f   (relative error = %.3e)\n" ratio rel_err

    println()
    if rel_err < 1e-3
        println("✅ CPU≡GPU at cell 7's live state to 1e-3.")
        println("   Fused-axis combination at Eu F=6 / 24³ / Ω≠0 / DDI: NO residual bug.")
        println("   Bug-class closure: COMPLETE for cell 7 conditioning floor.")
        println("   → ‖∇E‖=1.4e-3 confirmed as TRUE gradient norm; conditioning-limited.")
    else
        println("⚠ CPU vs GPU disagree at cell 7's state (relative error $rel_err).")
        println("   This is a fused-axis residue: a CPU-GPU mismatch that only")
        println("   manifests when Eu F=6 + DDI + Ω≠0 are simultaneously active.")
        println("   Investigate the combination not covered by single-term parity.")
    end
end

main()
