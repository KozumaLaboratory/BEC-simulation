#!/usr/bin/env julia
# scripts/m1_outlier_cell_recheck.jl
#
# Re-audit Bz=5 nT / Ω=0.20 (the one cell whose kinetic FD/inner ratio
# came back 1.2684 in the grid scan) at multiple ε to disambiguate
# ε²-truncation noise vs a real per-state gradient bug.
#
# If kinetic ratio → 1.0 as ε shrinks 1e−5 → 1e−7 → 1e−9, it was
# warm-start kinetic-stiffness truncation. If it stays at 1.27, there's
# a per-state bug specific to this region of the (Bz, Ω) phase diagram.

import CUDA
using SpinorBEC
using Printf
using JLD2
const TW = eu151_preset()
const B_NT = 5.0
const OMEGA = 0.20
const N_ITP_WARM = 300

function main()
    println("=== Bz=5/Ω=0.20 kinetic outlier ε-scan ===\n")

    p_lab = B_NT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    sys = SpinSystem(TW.F)
    psi_init = init_psi(TW.grid, sys; state=:polar)
    add_white_noise!(psi_init, 0.01, 1, TW.grid)

    r = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=0.005, n_steps=N_ITP_WARM, tol=0.0,
        initial_state=:polar, verbose=false, psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=OMEGA, backend=CUDABackend(),
    )
    ws = r.workspace
    psi_dev = copy(ws.state.psi)
    psi_cpu = Array(psi_dev)
    dV = SpinorBEC.cell_volume(TW.grid)

    grad_dev = similar(ws.state.psi)
    k2_dev = SpinorBEC._to_device(ws.backend, ws.grid.k_squared)
    SpinorBEC.energy_gradient!(grad_dev, ws.state.psi, ws; k_squared_dev=k2_dev)
    grad_cpu = Array(grad_dev)
    μ = real(sum(conj.(grad_cpu) .* psi_cpu)) * dV / (sum(abs2, psi_cpu) * dV)
    proj_cpu = grad_cpu .- μ .* psi_cpu

    n_pts = ntuple(d -> size(psi_dev, d), Val(3))
    D_eu = ws.spin_matrices.system.n_components
    proj_dev = SpinorBEC._to_device(ws.backend, proj_cpu)
    psi_plus_dev = similar(ws.state.psi)

    # Per-term kinetic only (the outlier)
    grad_buf = similar(ws.state.psi)
    fill!(grad_buf, 0)
    copyto!(ws.state.psi, psi_dev)
    fft_buf = similar(grad_buf, ComplexF64, n_pts...)
    SpinorBEC._grad_kinetic!(grad_buf, ws.state.psi, ws, fft_buf, k2_dev, n_pts, D_eu, Val(3))
    grad_buf .*= 2
    grad_kin_cpu = Array(grad_buf)
    inner_kin = real(sum(conj.(grad_kin_cpu) .* proj_cpu)) * dV

    @printf "‖P_⊥∇E‖²_L²       = %.4e\n" real(sum(abs2, proj_cpu)) * dV
    @printf "Re⟨grad_kin, proj⟩ = %.6e   (the inner predictor for kinetic)\n\n" inner_kin

    @printf "%10s  %14s  %14s  %12s\n" "ε" "E_kin(ψ+ε·proj)" "FD slope ΔE/ε" "ratio FD/inner"
    println("-"^60)
    function E_kin_at(psi_arr)
        copyto!(ws.state.psi, psi_arr)
        SpinorBEC.energy_decomposition(ws).kinetic
    end
    E_kin_0 = E_kin_at(psi_dev)
    for ε in [1e-4, 1e-5, 1e-6, 1e-7, 1e-8, 1e-9]
        psi_plus_dev .= psi_dev .+ ε .* proj_dev
        E_kin_ε = E_kin_at(psi_plus_dev)
        fd = (E_kin_ε - E_kin_0) / ε
        ratio = fd / inner_kin
        @printf "%10.0e  %+.6e  %+.6e  %12.6f\n" ε E_kin_ε fd ratio
    end

    println("\nInterpretation:")
    println("  ratio → 1 as ε shrinks → ε² truncation in warm-start state (no bug)")
    println("  ratio plateaus at 1.27 → real gradient bug at this (Bz, Ω)")
end

main()
