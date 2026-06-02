#!/usr/bin/env julia
# scripts/sprint5_M1_ITP_omega_sweep_converged.jl
#
# Track M1 Gate-1 — verdict-grade convergence attempt.
# Supersedes sprint5_M1_ITP_omega_sweep_polished.jl, whose 0/30
# convergence + 20× oracle violation at high B is documented in
# `mistake_unconverged_to_new_physics_ignoring_analytical_oracle.md`.
#
# Convergence upgrades vs the polished sweep:
#   * N_ITP = 3000 (1.5× the polished N_ITP = 2000)
#   * N_LBFGS = 5000 (5× the polished N_LBFGS = 1000)
#   * Sobolev α = 0.05 (2.5× the polished α = 0.02; needed for
#     finer-conditioning of the rotating-frame full functional)
#   * 2-seed multistart per cell: :polar + :fl_vortex(charge=1).
#     Pick the lowest-E cell that passes the ‖∇E‖ gate.
#
# ─── ANALYTICAL ORACLE GATE (required for verdict-grade) ───
# At B = 100 nT, Ω = 0.6:
#   Eu γ_F/2π ≈ 16.28 Hz/nT → Zeeman ≈ 1.63 kHz
#   Barnett(Ω=0.6) ≈ Ω · ω_ref / (2π) ≈ 66 Hz
#   DDI · c₁·⟨n⟩ ≈ 100-200 Hz
# Zeeman (1630) ≫ Barnett (66), DDI (150) by an order of magnitude
# → spin must rigid-pin to the in-plane B; ⟨F_z⟩ tiny tilt from Barnett:
#   ⟨F_z⟩(B=100, Ω=0.6) ≈ F · Barnett/Zeeman = 6 · 66/1630 ≈ 0.24
#
# At the end of the sweep this script checks ⟨F_z⟩(B=100, Ω=0.6) against
# 0.24 ± 30%. If outside, the high-B column is treated as artifact
# regardless of conv flag. Per
# `mistake_unconverged_to_new_physics_ignoring_analytical_oracle.md`.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_M1_ITP_omega_sweep_converged.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Printf
using JLD2

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()  # 24³, N=5×10⁴
const DT_ITP = 0.005
const N_ITP = 3000
const TOL_ITP = 1e-7
const N_LBFGS = 5000
const TOL_LBFGS = 1e-5
const SOBOLEV = 0.05
const NOISE_AMP = 0.01

const OMEGAS = [0.0, 0.1, 0.2, 0.4, 0.6]
const B_VALUES_NT = [0.0, 1.0, 2.6, 5.0, 10.0, 100.0]
const SEEDS = [:polar, :fl_vortex]
const NOISE_SEED = 1
const OUT_DIR = "runs/sprint5_M1_ITP_omega_sweep_converged"

# Analytical oracle gate
const ORACLE_FZ_HIGH_B = 0.24    # F · Barnett(Ω=0.6) / Zeeman(B=100nT) ≈ 6·66/1630
const ORACLE_TOL = 0.30          # ±30% tolerance

function build_seed(state::Symbol, grid::Grid)
    sys = SpinSystem(TW.F)
    if state == :fl_vortex
        return init_psi(grid, sys; state=:fl_vortex, init_vortex_charge=1)
    else
        return init_psi(grid, sys; state=state)
    end
end

function run_cell_one_seed(omega::Float64, B_nT::Float64, seed_state::Symbol)
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0),
        ConstantWaveform(0.0),
        ConstantWaveform(p_lab),
        ConstantWaveform(0.0),
    )

    psi_init = build_seed(seed_state, TW.grid)
    add_noise!(psi_init, NOISE_AMP, NOISE_SEED, TW.grid)

    initial_state_for_fgs = seed_state == :fl_vortex ? :fl_vortex : :polar

    t0 = time()
    r_itp = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=DT_ITP, n_steps=N_ITP, tol=TOL_ITP,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=omega,
        backend=CUDABackend())
    t_itp = time() - t0
    ws_itp = r_itp.workspace
    E_itp = r_itp.energy

    t0 = time()
    r_lbfgs = SpinorBEC.find_ground_state_lbfgs(;
        ws_init=ws_itp,
        n_steps=N_LBFGS, tol=TOL_LBFGS,
        verbose=false, sobolev_alpha=SOBOLEV,
    )
    t_lbfgs = time() - t0
    ws = r_lbfgs.workspace
    E = r_lbfgs.energy
    conv_lbfgs = r_lbfgs.converged
    grad_norm = r_lbfgs.grad_norm

    psi = Array(ws.state.psi)
    sm = ws.spin_matrices
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    f_max = maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
    dV = SpinorBEC.cell_volume(TW.grid)
    fz_total = sum(fz) * dV
    fx_total = sum(fx) * dV
    fy_total = sum(fy) * dV
    m_dist = zeros(TW.D)
    for c in 1:(TW.D)
        m_dist[c] = sum(abs2, psi[:, :, :, c]) * dV
    end
    Lz = orbital_angular_momentum(psi, ws.grid, ws.fft_plans)
    CUDA.reclaim()
    return (
        omega=omega, B_nT=B_nT, seed=seed_state,
        E=E, E_itp=E_itp,
        conv_lbfgs=conv_lbfgs, grad_norm=grad_norm,
        fx_total=fx_total, fy_total=fy_total, fz_total=fz_total,
        Lz=Lz, f_max=f_max, m_dist=m_dist,
        time_itp_min=t_itp/60, time_lbfgs_min=t_lbfgs/60,
    )
end

function run_cell_multistart(omega::Float64, B_nT::Float64)
    candidates = [run_cell_one_seed(omega, B_nT, s) for s in SEEDS]
    # Prefer cells passing the gate; fall back to lowest E if none pass.
    passing = filter(c -> c.conv_lbfgs && c.grad_norm < TOL_LBFGS, candidates)
    chosen = if isempty(passing)
        candidates[argmin([c.E for c in candidates])]
    else
        passing[argmin([c.E for c in passing])]
    end
    chosen, candidates
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== M1-ITP CONVERGED — rotating-frame Ω×B sweep ===\n")
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9
    @printf "N=%d, ω=(110,110,130) Hz, c_dd/c_0=%.4f\n" TW.n_atoms (TW.c_dd/TW.c0)
    @printf "ITP n_steps=%d → LBFGS n_steps=%d tol=%.0e Sobolev α=%.3f\n" N_ITP N_LBFGS TOL_LBFGS SOBOLEV
    @printf "Sweep: %d Ω × %d B × %d seeds = %d total cell-seeds\n\n" length(OMEGAS) length(
        B_VALUES_NT
    ) length(SEEDS) (length(OMEGAS) * length(B_VALUES_NT) * length(SEEDS))
    @printf "Oracle gate: ⟨F_z⟩(B=100, Ω=0.6) expected ≈ %.2f (±%.0f%%)\n\n" ORACLE_FZ_HIGH_B (
        100*ORACLE_TOL
    )

    results = []         # winning per cell
    all_attempts = []    # per (cell, seed)
    icell = 0
    n_total = length(OMEGAS) * length(B_VALUES_NT)
    partial_path = joinpath(OUT_DIR, "partial.jld2")

    for B_nT in B_VALUES_NT
        for Ω in OMEGAS
            icell += 1
            @printf "\n[cell %d/%d] B=%.1f nT, Ω=%.2f\n" icell n_total B_nT Ω
            flush(stdout)
            chosen, candidates = run_cell_multistart(Ω, B_nT)
            for c in candidates
                gate =
                    (c.conv_lbfgs && c.grad_norm < TOL_LBFGS) ? "✓✓" : (
                        c.conv_lbfgs ? "✓∇" : "✗"
                    )
                marker = c.seed == chosen.seed ? " ★" : ""
                @printf "  seed=%-10s E=%.6f gate=%s ‖∇E‖=%.3e ⟨F_z⟩=%+.3e ⟨L_z⟩=%+.3e (ITP %.1f / LBFGS %.1f min)%s\n" string(
                    c.seed
                ) c.E gate c.grad_norm c.fz_total c.Lz c.time_itp_min c.time_lbfgs_min marker
                push!(all_attempts, c)
            end
            push!(results, chosen)
            partial = [
                Dict(
                    "omega" => r.omega, "B_nT" => r.B_nT, "seed" => string(r.seed),
                    "E" => r.E, "E_itp" => r.E_itp,
                    "conv_lbfgs" => r.conv_lbfgs, "grad_norm" => r.grad_norm,
                    "fx_total" => r.fx_total, "fy_total" => r.fy_total,
                    "fz_total" => r.fz_total, "Lz" => r.Lz, "f_max" => r.f_max,
                    "m_dist" => r.m_dist,
                    "time_itp_min" => r.time_itp_min, "time_lbfgs_min" => r.time_lbfgs_min,
                ) for r in results
            ]
            @save partial_path partial icell n_total
        end
    end

    println("\n\n=== Converged Ω×B sweep — winner per cell ===\n")
    @printf "%-10s %-6s %-9s %-9s %-13s %-13s %-13s %-8s\n" "B[nT]" "Ω" "E" "‖∇E‖" "⟨F_z⟩" "⟨L_z⟩" "⟨F_x⟩" "seed"
    for r in results
        gate = (r.conv_lbfgs && r.grad_norm < TOL_LBFGS) ? "✓✓" : "✗"
        @printf "%-10.2f %-6.2f %.6f %.3e %+.4e %+.4e %+.4e %-8s %s\n" r.B_nT r.omega r.E r.grad_norm r.fz_total r.Lz r.fx_total string(
            r.seed
        ) gate
    end

    println("\n--- ⟨F_z⟩(B, Ω) winner map ---")
    @printf "%-10s " "B\\Ω"
    for Ω in OMEGAS
        @printf "%-13.2f " Ω
    end
    println()
    for B_nT in B_VALUES_NT
        @printf "%-10.2f " B_nT
        for Ω in OMEGAS
            cell = filter(r -> r.omega == Ω && r.B_nT == B_nT, results)
            isempty(cell) ? @printf("%-13s ", "—") : @printf("%+.4e ", cell[1].fz_total)
        end
        println()
    end

    println("\n--- ⟨L_z⟩(B, Ω) winner map ---")
    @printf "%-10s " "B\\Ω"
    for Ω in OMEGAS
        @printf "%-13.2f " Ω
    end
    println()
    for B_nT in B_VALUES_NT
        @printf "%-10.2f " B_nT
        for Ω in OMEGAS
            cell = filter(r -> r.omega == Ω && r.B_nT == B_nT, results)
            isempty(cell) ? @printf("%-13s ", "—") : @printf("%+.4e ", cell[1].Lz)
        end
        println()
    end

    n_conv = count(r -> r.conv_lbfgs && r.grad_norm < TOL_LBFGS, results)
    println("\nConverged cells (winner): $n_conv / $(length(results))")

    # ─── Analytical oracle gate ───
    println("\n=== ANALYTICAL ORACLE GATE ===")
    oracle_cell = filter(r -> r.omega == 0.6 && r.B_nT == 100.0, results)
    if isempty(oracle_cell)
        println("Oracle cell (B=100, Ω=0.6) MISSING — gate cannot evaluate.")
    else
        fz_obs = oracle_cell[1].fz_total
        @printf "Expected ⟨F_z⟩(B=100 nT, Ω=0.6) ≈ %.4f (F·Barnett/Zeeman = 6·66/1630)\n" ORACLE_FZ_HIGH_B
        @printf "Observed ⟨F_z⟩(B=100 nT, Ω=0.6) = %+.4f  (‖∇E‖=%.3e, conv=%s)\n" fz_obs oracle_cell[1].grad_norm string(
            oracle_cell[1].conv_lbfgs
        )
        rel_err = abs(fz_obs - ORACLE_FZ_HIGH_B) / ORACLE_FZ_HIGH_B
        @printf "Relative error vs oracle: %.1f%% (tolerance: %.0f%%)\n" (100*rel_err) (
            100*ORACLE_TOL
        )
        if rel_err < ORACLE_TOL
            println("→ ORACLE PASSED. High-B column is verdict-grade.")
        else
            println("→ ORACLE FAILED. High-B column is artifact regardless of conv flag.")
            println(
                "   Do NOT cite high-B ⟨F_z⟩ values. The convergence is still broken."
            )
        end
    end

    snapshot = [
        Dict(
            "omega" => r.omega, "B_nT" => r.B_nT, "seed" => string(r.seed),
            "E" => r.E, "E_itp" => r.E_itp,
            "conv_lbfgs" => r.conv_lbfgs, "grad_norm" => r.grad_norm,
            "fx_total" => r.fx_total, "fy_total" => r.fy_total,
            "fz_total" => r.fz_total, "Lz" => r.Lz, "f_max" => r.f_max,
            "m_dist" => r.m_dist,
            "time_itp_min" => r.time_itp_min, "time_lbfgs_min" => r.time_lbfgs_min,
        ) for r in results
    ]
    @save joinpath(OUT_DIR, "converged_sweep.jld2") snapshot
    all_attempts_dict = [
        Dict(
            "omega" => r.omega, "B_nT" => r.B_nT, "seed" => string(r.seed),
            "E" => r.E, "conv_lbfgs" => r.conv_lbfgs, "grad_norm" => r.grad_norm,
            "fz_total" => r.fz_total, "Lz" => r.Lz,
        ) for r in all_attempts
    ]
    @save joinpath(OUT_DIR, "all_attempts.jld2") all_attempts_dict
    println("\n=== Done ===")
end

main()
