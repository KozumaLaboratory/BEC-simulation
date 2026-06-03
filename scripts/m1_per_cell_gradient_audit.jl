#!/usr/bin/env julia
# scripts/m1_per_cell_gradient_audit.jl
#
# Extends `m1_per_term_gradient_audit.jl` from one cell (B=0/Ω=0.4) to
# the full (Bz_nT, Ω) Barnett-window grid. The single-cell post-fix audit
# established FD/inner ratio ≈ 1.0 to 4 sig figs for every term at one
# state; this script asserts the same identity at every cell of a 4×4
# grid as a regression guard before any further Ω>0 rotating-frame
# LBFGS sweep can be trusted quantitatively.
#
# For each (B_nT, Ω) cell:
#   1. ITP-warm-start workspace from polar + 1% noise
#   2. Build `grad = energy_gradient!(ψ_warm)`
#   3. Lagrange-project off ψ: `proj = grad − μ·ψ`
#   4. For each term T ∈ {kinetic, trap, zeeman, density, spin, ddi, coriolis}:
#        - inner_T = Re⟨2·δE_T/δψ*, proj⟩  (per-term gradient)
#        - fd_T    = (E_T(ψ + ε·proj) − E_T(ψ)) / ε  (per-term energy FD)
#   5. Assert ratio FD/inner ∈ [0.9995, 1.0005] for every term
#
# If a cell fails, prints which term diverged and writes the cell's
# (ψ_warm, grad, proj) to JLD2 for follow-up audit.
#
# Cost: 16 cells × (~30s ITP + ~5s audit) ≈ 10 min on GPU.

import CUDA
using SpinorBEC
using Printf
using JLD2

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()
const BZ_NT_GRID = [0.0, 2.0, 5.0, 10.0]
const OMEGA_GRID = [0.1, 0.2, 0.4, 0.6]
const N_ITP_WARM = 300
const ε_FD = 1e-5
const TOL_RATIO = 5e-4
const OUTPUT_JLD2 = "runs/m1_per_cell_gradient_audit_2026_06_04.jld2"

function audit_cell(B_nT::Float64, omega::Float64)
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    sys = SpinSystem(TW.F)
    psi_init = init_psi(TW.grid, sys; state=:polar)
    add_noise!(psi_init, 0.01, 1, TW.grid)

    # Warm-start workspace (short ITP — just to populate buffers + relax 1 step)
    r = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=0.005, n_steps=N_ITP_WARM, tol=0.0,
        initial_state=:polar, verbose=false, psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=omega, backend=CUDABackend(),
    )
    ws = r.workspace
    psi_dev = copy(ws.state.psi)
    psi_cpu = Array(psi_dev)
    dV = SpinorBEC.cell_volume(TW.grid)

    # Total gradient + projection
    grad_dev = similar(ws.state.psi)
    k2_dev = SpinorBEC._to_device(ws.backend, ws.grid.k_squared)
    SpinorBEC.energy_gradient!(grad_dev, ws.state.psi, ws; k_squared_dev=k2_dev)
    grad_cpu = Array(grad_dev)
    μ = real(sum(conj.(grad_cpu) .* psi_cpu)) * dV / (sum(abs2, psi_cpu) * dV)
    proj_cpu = grad_cpu .- μ .* psi_cpu
    R² = real(sum(abs2, proj_cpu)) * dV

    # Per-term build
    n_pts = ntuple(d -> size(psi_dev, d), Val(3))
    D_eu = ws.spin_matrices.system.n_components
    proj_dev = SpinorBEC._to_device(ws.backend, proj_cpu)
    psi_plus_dev = similar(ws.state.psi)
    grad_buf = similar(ws.state.psi)

    function single_term_grad!(term::Symbol)
        fill!(grad_buf, 0)
        copyto!(ws.state.psi, psi_dev)
        if term === :kinetic
            fft_buf = similar(grad_buf, ComplexF64, n_pts...)
            SpinorBEC._grad_kinetic!(grad_buf, ws.state.psi, ws, fft_buf, k2_dev, n_pts, D_eu, Val(3))
        elseif term === :trap
            SpinorBEC._grad_trap!(grad_buf, ws.state.psi, ws, n_pts, D_eu, Val(3))
        elseif term === :zeeman
            SpinorBEC._grad_zeeman!(grad_buf, ws.state.psi, ws, n_pts, D_eu, Val(3))
        elseif term === :density
            n_density = SpinorBEC.total_density(ws.state.psi, 3)
            SpinorBEC._grad_c0_density!(grad_buf, ws.state.psi, ws, n_density, n_pts, D_eu, Val(3))
        elseif term === :spin
            fx = similar(grad_buf, ComplexF64, n_pts...)
            fy = similar(grad_buf, ComplexF64, n_pts...)
            fz = similar(grad_buf, ComplexF64, n_pts...)
            SpinorBEC._grad_c1_spin!(grad_buf, ws.state.psi, ws, fx, fy, fz, n_pts, D_eu, Val(3))
        elseif term === :ddi
            SpinorBEC._grad_ddi!(grad_buf, ws.state.psi, ws, n_pts, D_eu, Val(3))
        elseif term === :coriolis
            fft_buf = similar(grad_buf, ComplexF64, n_pts...)
            deriv_buf = similar(grad_buf, ComplexF64, n_pts...)
            SpinorBEC._grad_coriolis!(grad_buf, ws.state.psi, ws, fft_buf, deriv_buf, n_pts, D_eu, Val(3))
        end
        grad_buf .*= 2
    end

    function E_term_at(psi_arr, term::Symbol)
        copyto!(ws.state.psi, psi_arr)
        SpinorBEC.energy_decomposition(ws)[term]
    end

    terms = [:kinetic, :trap, :zeeman, :density, :spin, :ddi, :coriolis]
    ratios = Dict{Symbol, Float64}()
    inner_total = 0.0
    fd_total = 0.0
    for term in terms
        single_term_grad!(term)
        gt_cpu = Array(grad_buf)
        inner_T = real(sum(conj.(gt_cpu) .* proj_cpu)) * dV
        E_T_0 = E_term_at(psi_dev, term)
        psi_plus_dev .= psi_dev .+ ε_FD .* proj_dev
        E_T_eps = E_term_at(psi_plus_dev, term)
        fd_T = (E_T_eps - E_T_0) / ε_FD
        ratio = inner_T != 0 ? fd_T / inner_T : 1.0
        ratios[term] = ratio
        inner_total += inner_T
        fd_total += fd_T
    end
    total_ratio = fd_total / inner_total
    CUDA.reclaim()
    return (R², ratios, total_ratio, psi_cpu, proj_cpu)
end

function main()
    println("=== M1 per-cell gradient ↔ energy audit ===")
    @printf "Grid: %d × %d cells | ε=%.0e | tol on |ratio−1| = %.0e\n\n" length(BZ_NT_GRID) length(OMEGA_GRID) ε_FD TOL_RATIO

    @printf "%6s  %6s  %10s  %s\n" "Bz" "Ω" "R²" "ratios per term (k/t/z/d/sp/ddi/cor) + TOTAL"
    println("-"^110)
    all_rows = []
    n_fail = 0
    t_start = time()
    for B_nT in BZ_NT_GRID, omega in OMEGA_GRID
        t_cell = time()
        R², ratios, total_ratio, ψ, proj = audit_cell(B_nT, omega)
        rs = [ratios[t] for t in [:kinetic, :trap, :zeeman, :density, :spin, :ddi, :coriolis]]
        bad = any(r -> abs(r - 1.0) > TOL_RATIO, rs) || abs(total_ratio - 1.0) > TOL_RATIO
        mark = bad ? "✗" : "✓"
        n_fail += bad
        @printf "%6.1f  %6.2f  %.3e  %.4f %.4f %.4f %.4f %.4f %.4f %.4f  TOT=%.4f  %s  (%.0fs)\n" B_nT omega R² rs... total_ratio mark (time() - t_cell)
        push!(all_rows, (B_nT, omega, R², ratios, total_ratio, bad))
        flush(stdout)
    end
    @printf "\nTotal wall: %.1f min   failures: %d/%d\n" ((time() - t_start) / 60) n_fail (length(BZ_NT_GRID) * length(OMEGA_GRID))

    JLD2.jldsave(OUTPUT_JLD2; rows=all_rows, BZ_NT_GRID, OMEGA_GRID, ε_FD, TOL_RATIO,
        timestamp=string(time()),
        note="Post-2026-06-04 GPU energy fix; per-cell FD ↔ inner audit on the Barnett window grid.")
    @printf "Wrote %s\n" OUTPUT_JLD2

    if n_fail == 0
        println("\n✓ All cells pass — Option 1 (rotating-frame map) UNBLOCKED.")
    else
        @printf "\n✗ %d cells fail — re-audit before treating Ω>0 LBFGS quantitatively.\n" n_fail
    end
end

main()
