#!/usr/bin/env julia
# scripts/sprint5_M0_edh_realtime_validation.jl
#
# Track M0 — Matsui EdH cascade real-time validation.
#
# Real-time GP + MDDI evolution from m=-F polarized initial state at
# Matsui digital twin parameters. Tracks N_m(t) population per spin
# component. Compares to Matsui Fig 2C cascade:
#   t=0:    N_{-6} = 1, others 0
#   t=5ms:  m=-5 substantial growth, m=-4 small
#   t=40ms: m=-5 and m=-4 both populated, total norm ~60% (40% loss)
#
# Our simulation is loss-free (no K_3) for the baseline; loss can be
# added later as Matsui's "experiment-on" variant.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_M0_edh_realtime_validation.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Printf
using JLD2
const TW = eu151_preset()

# Matsui Zeeman: GS prep at 1 μT, quench to 2.6 nT for dynamics
# Use the dynamics value for the evolution
# p_dynamics in Hz: g_F μ_B B = 1.163 × 13.996 GHz/T × 2.6e-9 T ≈ 42.3 Hz
# In dimensionless: 42.3 × 2π / 691.15 ≈ 0.385
const P_DYNAMICS = 0.385
const ZEEMAN_DYN = ZeemanParams(P_DYNAMICS, 0.0)

# Real-time: T = 40 ms ≈ 27.65 in ω_ref⁻¹ units; dt = 0.005
const T_EVOLVE = 27.65
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))
# Save every Δt ≈ 0.5 ω_ref⁻¹ ≈ 0.72 ms
const SAVE_EVERY = Int(round(0.5 / DT))

const OUT_DIR = "runs/sprint5_M0_edh_realtime"

function build_FM_polarized(grid::Grid)
    sys = SpinSystem(TW.F)
    return init_psi(grid, sys; state=:m_minus_F)
end

function build_workspace_realtime(grid::Grid, psi_init::Array{ComplexF64, 4})
    sp = SimParams(;
        dt=DT, n_steps=N_STEPS,
        imaginary_time=false,
        normalize_every=0,        # real-time: no normalization
        save_every=SAVE_EVERY,
        rotating_frame_omega=0.0,
    )
    ws = make_workspace(;
        grid=grid, atom=TW.atom,
        interactions=TW.interactions, zeeman=ZEEMAN_DYN,
        potential=TW.potential,
        sim_params=sp,
        psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd,
        secular_ddi=false,
        backend=CUDABackend(),
    )
    return ws
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== M0 — Matsui EdH cascade real-time validation ===\n")
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9
    @printf "Atom: %s, N=%d, ω=(110, 110, 130) Hz aspect=(1, 1, 1.1818)\n" TW.atom.name TW.n_atoms
    @printf "Initial: m=-F (m=-6) fully polarised\n"
    @printf "B_z dynamics = 2.6 nT (p_dimless=%.3f, %.1f Hz)\n" P_DYNAMICS (
        P_DYNAMICS * TW.omega_ref / 2π
    )
    @printf "Channel set: Matsui-literal c_0=%.3e c_1=%.3e c_n=0 (n≥2)\n" TW.c0 TW.c1
    @printf "Real-time: T=%.2f ω_ref⁻¹ ≈ %.1f ms, dt=%.3f, n_steps=%d, save every %d\n\n" T_EVOLVE (
        T_EVOLVE / TW.omega_ref * 1000
    ) DT N_STEPS SAVE_EVERY

    psi_init = build_FM_polarized(TW.grid)
    dV = SpinorBEC.cell_volume(TW.grid)
    pop_m_minus_F_init = sum(abs2, psi_init[:, :, :, TW.F + 1 - (-TW.F)]) * dV
    @printf "Sanity: N_{m=-F}/N at t=0 = %.6f (expect 1.0 for FM init)\n" pop_m_minus_F_init

    ws = build_workspace_realtime(TW.grid, psi_init)
    t0 = time()
    println("Starting real-time evolution...")
    flush(stdout)
    res = run_simulation!(ws)
    t_run = time() - t0
    @printf "Done. Wall-clock: %.1f min\n\n" (t_run / 60)

    # Extract per-m populations from saved snapshots
    snapshots = res.psi_snapshots
    @info "Snapshots saved" length(snapshots)
    n_snap = length(snapshots)
    times = res.times
    println("\nPer-m population vs time:")
    @printf "%-10s %-8s %-8s " "t/ω_ref⁻¹" "ms" "N_tot"
    for m in -TW.F:TW.F
        @printf "N_m=%+d " m
    end
    println()
    populations = Float64[]  # flat array of n_snap × D
    for (i, snap_psi) in enumerate(snapshots)
        psi = snap_psi isa AbstractArray ? Array(snap_psi) : Array(snap_psi.psi)
        n_total = 0.0
        per_m = zeros(TW.D)
        for c in 1:TW.D
            per_m[c] = sum(abs2, psi[:, :, :, c]) * dV
            n_total += per_m[c]
        end
        @printf "%-10.3f %-8.2f %-8.4f " times[i] (times[i] / TW.omega_ref * 1000) n_total
        for c in 1:TW.D
            @printf "%.4f " per_m[c]
            push!(populations, per_m[c])
        end
        println()
    end

    @save joinpath(OUT_DIR, "edh_realtime.jld2") times populations n_snap

    println("\n--- Comparison to Matsui Fig 2C ---")
    # Find times closest to 5 ms and 40 ms
    target_times_ms = [5.0, 10.0, 20.0, 40.0]
    @printf "%-8s %-8s %-10s %-10s %-10s %-10s\n" "target_ms" "actual_ms" "N_{-6}" "N_{-5}" "N_{-4}" "total"
    for tgt in target_times_ms
        # find closest snapshot
        ms_arr = [t * 1000 / TW.omega_ref for t in times]
        ii = argmin(abs.(ms_arr .- tgt))
        Nm = populations[((ii - 1) * TW.D + 1):(ii * TW.D)]
        @printf "%-8.1f %-8.2f %-10.4f %-10.4f %-10.4f %-10.4f\n" tgt ms_arr[ii] Nm[TW.D] Nm[TW.D - 1] Nm[TW.D - 2] sum(
            Nm
        )
    end

    println("\nMatsui expected (Fig 2C loss-free reference):")
    println("  5 ms:  N_{-6} dominant, N_{-5} growing, N_{-4} small")
    println("  40 ms: substantial N_{-5}, N_{-4} both grown")
    println()
    println("=== Done ===")
end

main()
