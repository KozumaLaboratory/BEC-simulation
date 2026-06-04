#!/usr/bin/env julia
# scripts/m2_barnett_window_scan.jl
#
# M2 Fig4 anchor: 2D rotating-frame Barnett window — ⟨F_z⟩(Ω, B_z),
# ⟨L_z⟩(Ω, B_z), and E(Ω, B_z) over a coarse 4×4 grid. Each cell is an
# Ω≠0 GPU LBFGS-polished ITP — the exact path that was buggy pre-fix
# (`mistake_gpu_energy_decomposition_missing_coriolis_2026_06_04`) and
# is now verified clean (per-term FD audit + post-fix LBFGS smoke).
#
# Observables:
#   ⟨F_z⟩ — spin response (Barnett pumping)
#   ⟨L_z⟩ — orbital response (must co-align with ⟨F_z⟩ per EdH oracle)
#   E_rot — rotating-frame energy at the GS
#   ⟨F_z⟩/Ω — Barnett gain at small Ω (limits to χ_perp)
#
# Cost: 16 cells × ~3 min/cell ≈ 50 min on GPU.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/m2_barnett_window_scan.jl

import CUDA
using SpinorBEC
using Printf
using JLD2

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()

const BZ_NT_GRID = [0.0, 2.0, 5.0, 10.0]
const OMEGA_GRID = [0.1, 0.2, 0.4, 0.6]
const N_ITP = 500
const N_LBFGS = 500
const SOBOLEV = 0.05
const DT = 0.005
const OUTPUT_JLD2 = "runs/m2_barnett_window_postfix_2026_06_04.jld2"

function cell_observables(B_nT::Float64, omega::Float64)
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )

    # Symmetry-breaking noise on the seed — without it, B=0 cells stay
    # locked at ⟨F_z⟩ = 0 to machine precision because the polar state
    # has perfect Z₂ spin symmetry. 1% noise + Bz/Ω matches the
    # working recipe in sprint5_M1_barnett_postfix.jl.
    sys = SpinSystem(TW.F)
    psi_init = init_psi(TW.grid, sys; state=:polar)
    add_noise!(psi_init, 0.01, 1, TW.grid)

    # Phase 1: ITP warm-start
    r_itp = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=DT, n_steps=N_ITP, tol=1e-7,
        initial_state=:polar, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=omega, backend=CUDABackend(),
    )

    # Phase 2: LBFGS polish
    r_lbfgs = SpinorBEC.find_ground_state_lbfgs(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        psi_init=Array(r_itp.workspace.state.psi),
        n_steps=N_LBFGS, tol=1e-7,
        verbose=false, sobolev_alpha=SOBOLEV,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=omega, backend=CUDABackend(),
    )

    ws = r_lbfgs[1]
    converged = r_lbfgs[2]
    E_rot = r_lbfgs[3]
    last_step = r_lbfgs[5]

    psi = Array(ws.state.psi)
    sm = ws.spin_matrices
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    dV = SpinorBEC.cell_volume(TW.grid)
    fz_tot = sum(fz) * dV
    Lz_tot = orbital_angular_momentum(psi, ws.grid, ws.fft_plans)

    # Projected residual L² norm for convergence reporting
    grad_dev = similar(ws.state.psi)
    k2_dev = SpinorBEC._to_device(ws.backend, ws.grid.k_squared)
    SpinorBEC.energy_gradient!(grad_dev, ws.state.psi, ws; k_squared_dev=k2_dev)
    grad_cpu = Array(grad_dev)
    psi_norm² = sum(abs2, psi) * dV
    μ = real(sum(conj.(grad_cpu) .* psi)) * dV / psi_norm²
    proj = grad_cpu .- μ .* psi
    R = sqrt(real(sum(abs2, proj)) * dV)

    CUDA.reclaim()
    return (E_rot, fz_tot, Lz_tot, R, μ, converged, last_step)
end

function main()
    println("=== M2 Barnett window: 2D scan (Bz, Ω) ===")
    @printf "Bz grid (nT): %s\n" string(BZ_NT_GRID)
    @printf "Ω  grid:      %s\n" string(OMEGA_GRID)
    @printf "N_ITP=%d  N_LBFGS=%d  sobolev_α=%.3f\n\n" N_ITP N_LBFGS SOBOLEV

    rows = Vector{Any}()
    @printf "%6s  %6s  %10s  %10s  %10s  %10s  %10s  %6s  %s\n" "Bz" "Ω" "E_rot" "⟨F_z⟩" "⟨L_z⟩" "⟨F_z⟩/Ω" "‖P_⊥∇E‖" "conv" "stp"
    println("-"^104)
    t_total = time()
    for B_nT in BZ_NT_GRID, omega in OMEGA_GRID
        t_cell = time()
        E, Fz, Lz, R, μ, conv, last_step = cell_observables(B_nT, omega)
        gain = omega > 0 ? Fz / omega : NaN
        @printf "%6.1f  %6.2f  %+.3e  %+.3e  %+.3e  %+.3e  %.3e  %6s  %4d  (%.0fs)\n" B_nT omega E Fz Lz gain R conv last_step (
            time() - t_cell
        )
        push!(rows, (B_nT, omega, E, Fz, Lz, gain, R, conv, last_step))
        flush(stdout)
    end
    @printf "\nTotal wall: %.1f min\n" (time() - t_total) / 60

    JLD2.jldsave(OUTPUT_JLD2;
        rows, BZ_NT_GRID, OMEGA_GRID, N_ITP, N_LBFGS, SOBOLEV, DT,
        timestamp=string(time()),
        note="Post-2026-06-04 GPU energy fix; rotating-frame ITP+LBFGS Barnett window.",
    )
    @printf "Wrote %s\n" OUTPUT_JLD2

    println("\n=== EdH oracle check (⟨F_z⟩·⟨L_z⟩ > 0 at every Ω > 0 cell) ===")
    failures = 0
    for r in rows
        Ω = r[2]
        Ω == 0 && continue
        same_sign = r[4] * r[5] > 0
        same_sign || (failures += 1)
    end
    if failures == 0
        println("✓ All cells co-aligned. Angular momentum conservation upheld.")
    else
        @printf "✗ %d cells violate EdH co-alignment — investigate.\n" failures
    end
end

main()
