#!/usr/bin/env julia
# scripts/m1_cell7_gpu_determinism.jl
#
# Discriminator (3) per the 2026-06-05 user 5e-5 analysis:
#
# Build a GPU workspace at cell-7 params, load the disk-saved ψ,
# run energy_gradient! TWICE, compare ‖∇E‖ values.
#
#   ~5e-5 random variation → GPU stochastic (race conditions in
#                            reductions, non-deterministic CUFFT
#                            sequencing)
#   Exact match              → CPU/GPU systematic implementation drift
#                            (the 4% bridge gap is in CPU vs GPU
#                            reduction ordering, not GPU itself)
#
# Coexists with the running sweep (~3 GB sweep + ~3 GB this test = 6 GB
# out of 16 GB).

import CUDA
using SpinorBEC
using SpinorBEC: energy_gradient!
using JLD2
using LinearAlgebra
using Printf

const CELL_PATH = "runs/sprint5_M1_ITP_omega_sweep_converged/cell_B1.0_Om0.10.jld2"
const TW = eu151_preset()  # 24³ Eu

function main()
    @info "GPU determinism check on cell-7 state"

    isfile(CELL_PATH) || error("Cell file missing: $CELL_PATH")
    cached = JLD2.load(CELL_PATH)
    psi_state = cached["psi"]
    result = cached["result"]
    B_nT = Float64(result["B_nT"])
    Ω = Float64(result["omega"])
    grad_norm_gpu_saved = Float64(result["grad_norm"])

    @printf "cell:       B=%.1f nT  Ω=%.2f  seed=%s\n" B_nT Ω result["seed"]
    @printf "saved ‖∇E‖ = %.6e  (sweep-reported, GPU)\n\n" grad_norm_gpu_saved

    # Build GPU workspace at SAME params as sweep
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0),
        ConstantWaveform(0.0),
        ConstantWaveform(p_lab),
        ConstantWaveform(0.0),
    )
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=Ω)

    @info "Building GPU workspace (CUDABackend)"
    ws_gpu = make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        backend=CUDABackend(),
    )
    copyto!(ws_gpu.state.psi, psi_state)

    dV = SpinorBEC.cell_volume(TW.grid)
    k2_dev = SpinorBEC._to_device(ws_gpu.backend, ws_gpu.grid.k_squared)

    # Run twice
    measurements = Float64[]
    energies = Float64[]
    for trial in 1:3
        # Re-set psi each time so we measure at IDENTICAL input
        copyto!(ws_gpu.state.psi, psi_state)
        grad_gpu = similar(ws_gpu.state.psi)
        fill!(grad_gpu, 0)
        E_gpu = energy_gradient!(grad_gpu, ws_gpu.state.psi, ws_gpu;
            k_squared_dev=k2_dev)
        SpinorBEC._project_constraints!(grad_gpu, ws_gpu.state.psi, ws_gpu.grid,
            nothing, ws_gpu.spin_matrices.system.F)
        gn = sqrt(sum(abs2, grad_gpu) * dV)
        push!(measurements, Float64(gn))
        push!(energies, Float64(E_gpu))
        @printf "trial %d:  E_GPU = %.10f  ‖∇E‖_GPU = %.10e\n" trial Float64(E_gpu) Float64(gn)
    end

    spread_E = maximum(energies) - minimum(energies)
    spread_g = maximum(measurements) - minimum(measurements)

    println()
    println("=== Spread across 3 trials ===")
    @printf "ΔE   = %.3e   (energy spread)\n" spread_E
    @printf "Δ‖∇E‖ = %.3e   (gradient norm spread)\n" spread_g
    println()
    if spread_E < 1e-12 && spread_g < 1e-12
        println("✅ DETERMINISTIC (spread < 1e-12).")
        println("   GPU is bit-stable; the 4% CPU-GPU bridge gap is")
        println("   SYSTEMATIC = implementation drift between CPU (FFTW)")
        println("   and GPU (CUFFT) reduction order — not GPU noise.")
        println("   → Fix direction: per-term CPU-vs-GPU bit-identity")
        println("     audit at 24³ Eu F=6 to isolate the divergent kernel.")
    elseif spread_g > 1e-7
        println("⚠ STOCHASTIC (spread > 1e-7).")
        println("   GPU is non-deterministic at this scale — race conditions")
        println("   in reductions or non-deterministic CUFFT sequencing.")
        println("   The ~5e-5 in the bridge IS this noise.")
        println("   → Implications: GPU's ‖∇E‖=9.96e-6 ✓✓ at cell 6 may")
        println("     not be reproducible to ulp; load-bearing thesis numbers")
        println("     should be CPU-final-evaluated, not GPU-LBFGS-reported.")
    else
        println("◆ MARGINAL ($spread_g between 1e-12 and 1e-7).")
        println("   Mild numerical drift — likely a mix.")
    end
    println()
    @printf "(bridge from earlier: CPU=1.4446e-3, sweep GPU-saved=1.3877e-3)\n"
    @printf "(this run GPU avg=%.6e)\n" (sum(measurements) / length(measurements))
end

main()
