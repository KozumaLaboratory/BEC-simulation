#!/usr/bin/env julia
# scripts/sprint5_M1_ITP_omega_sweep.jl
#
# Track M1-ITP — rotating-frame GS Ω-sweep at Eu Matsui digital twin.
# Gate-1 deliverable: maps (Ω, B_z) → (E, ⟨L_z⟩, ⟨F_z⟩, m-content, f_max)
# to identify go/no-go region for Barnett response + vortex onset.
#
# Hamiltonian (rotating frame):
#   H_rot = H_kin + H_trap + H_contact + H_DDI − γB·F − Ω·L_z − Ω·F_z
#   The Barnett term −Ω·F_z is added by make_workspace internally when
#   `rotating_frame_omega=Ω` is set (effective_p = z.p + Ω). The user
#   therefore passes z.p = p_lab_z directly; the workspace handles the
#   frame conversion. (Sign was flipped 2026-06-02 after sprint5_M1_barnett_test
#   identified the half-term cancellation bug; see workflow/initialization/make_workspace.jl.)
#   B is in the rotating-frame x̂ (constant transverse field) — z + Ω·L_z
#   commute, so a z-aligned B yields no genuine RF mixing. Implemented
#   with TimeDependentZeeman(bx_wf = ConstantWaveform(p_lab)) at t=0 (ITP).
#   Full DDI (no secular). This avoids the secular_ddi=true constraint
#   that spin_rotating_frame_omega would impose.
#
# Sweep:
#   Ω ∈ {0.0, 0.1, 0.2, 0.4, 0.6} ω_⊥  (5 values, brackets Ω_c≈ω_⊥/√2)
#   B ∈ {0, 1, 2.6, 5, 10, 100} nT     (6 values, Klaus window [1,5] + ends)
# = 30 cells × 2 multistart seeds (polar + fl_vortex) = 60 ITP+LBFGS runs
#
# Convergence:
#   ITP n_steps=20000 → LBFGS n_steps=4000 with Sobolev α=0.02
#   ‖∇E‖ reported (not dE) per Step 1 mistake-memo lesson.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_M1_ITP_omega_sweep.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Printf
using JLD2

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()
const DT_ITP = 0.005
const N_ITP = 500   # scout level
const TOL_ITP = 1e-7
const NOISE_AMP = 0.01

const OMEGAS = [0.0, 0.1, 0.2, 0.4, 0.6]
const B_VALUES_NT = [0.0, 1.0, 2.6, 5.0, 10.0, 100.0]
const SEEDS_BUILDERS = [:polar]   # scout mode: 1 seed; multistart in follow-up
const NOISE_SEED = 1

const OUT_DIR = "runs/sprint5_M1_ITP_omega_sweep"

function build_seed(state::Symbol, grid::Grid)
    sys = SpinSystem(TW.F)
    if state == :fl_vortex
        return init_psi(grid, sys; state=:fl_vortex, init_vortex_charge=1)
    else
        return init_psi(grid, sys; state=state)
    end
end

# Run one (Ω, B, seed) cell. Returns NamedTuple with diagnostics.
function run_cell(omega::Float64, B_nT::Float64, seed_state::Symbol)
    # B is rotating-frame x̂. p_lab is the in-plane Zeeman strength γB/ω_ref.
    # z.p_wf = 0 (no z-Zeeman); the workspace adds Barnett −Ω·F_z via
    # rotating_frame_omega=omega kwarg. (Sign now correct after make_workspace
    # fix 2026-06-02.) Cross-check: B=0 row of ⟨F_z⟩ should rise with Ω.
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0),         # p_wf: z-Zeeman (none — B is in-plane)
        ConstantWaveform(0.0),         # q_wf: quadratic Zeeman
        ConstantWaveform(p_lab),       # bx_wf: static rotating-frame B_x
        ConstantWaveform(0.0),         # by_wf
    )

    psi_init = build_seed(seed_state, TW.grid)
    add_noise!(psi_init, NOISE_AMP, NOISE_SEED, TW.grid)

    initial_state_for_fgs = seed_state == :fl_vortex ? :fl_vortex : :polar

    t0 = time()
    ws_itp, conv_itp, E_itp, _, _ = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=DT_ITP, n_steps=N_ITP, tol=TOL_ITP,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=omega,
        backend=CUDABackend())
    t_run = time() - t0

    E_pol = E_itp
    ws = ws_itp
    b = energy_decomposition(ws)
    grad_norm = NaN   # SKIP for scout (LBFGS-free)

    psi = Array(ws.state.psi)
    sm = ws.spin_matrices
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    f_max = maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
    dV = SpinorBEC.cell_volume(TW.grid)
    fz_total = sum(fz) * dV
    m_dist = zeros(TW.D)
    for c in 1:TW.D
        m_dist[c] = sum(abs2, psi[:, :, :, c]) * dV
    end
    plans = ws.fft_plans
    Lz = orbital_angular_momentum(psi, ws.grid, plans)
    CUDA.reclaim()
    return (
        omega=omega, B_nT=B_nT, seed=seed_state,
        E=E_pol, conv_lbfgs=conv_itp, grad_norm=grad_norm,
        breakdown=b, fz_total=fz_total, Lz=Lz, f_max=f_max,
        m_dist=m_dist, time_min=t_run/60,
    )
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== M1-ITP — rotating-frame Ω-sweep (Gate-1 scout) ===\n")
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9
    @printf "N=%d, ω=(110,110,130) Hz, c_dd/c_0=%.4f\n" TW.n_atoms (TW.c_dd/TW.c0)
    @printf "Sweep: %d Ω × %d B × %d seeds = %d ITP+LBFGS runs\n\n" length(OMEGAS) length(
        B_VALUES_NT
    ) length(SEEDS_BUILDERS) (length(OMEGAS) * length(B_VALUES_NT) * length(SEEDS_BUILDERS))

    results = []
    icell = 0
    n_cells_total = length(OMEGAS) * length(B_VALUES_NT)
    partial_path = joinpath(OUT_DIR, "partial.jld2")
    for B_nT in B_VALUES_NT
        for Ω in OMEGAS
            icell += 1
            @printf "\n[cell %d/%d] B=%.1f nT, Ω=%.2f\n" icell n_cells_total B_nT Ω
            flush(stdout)
            cell_results = []
            for seed_state in SEEDS_BUILDERS
                r = run_cell(Ω, B_nT, seed_state)
                @printf "  seed=%-10s E=%.6f conv=%s ‖∇E‖=%.3e ⟨F_z⟩=%+.3e ⟨L_z⟩=%+.3e f_max=%.3f (%.1f min)\n" string(
                    r.seed
                ) r.E (r.conv_lbfgs ? "✓" : "✗") r.grad_norm r.fz_total r.Lz r.f_max r.time_min
                push!(cell_results, r)
            end
            winner = argmin([r.E for r in cell_results])
            push!(results, cell_results...)
            @printf "  → winner: seed=%s E=%.6f\n" string(cell_results[winner].seed) cell_results[winner].E

            # Incremental checkpoint: save full results after each cell
            partial = [
                Dict(
                    "omega" => r.omega, "B_nT" => r.B_nT, "seed" => string(r.seed),
                    "E" => r.E, "conv_lbfgs" => r.conv_lbfgs, "grad_norm" => r.grad_norm,
                    "breakdown" => Dict(
                        string(k) => getfield(r.breakdown, k) for k in propertynames(r.breakdown)
                    ),
                    "fz_total" => r.fz_total, "Lz" => r.Lz, "f_max" => r.f_max,
                    "m_dist" => r.m_dist, "time_min" => r.time_min,
                ) for r in results
            ]
            @save partial_path partial icell n_cells_total
        end
    end

    # --- Sweep table ---
    println("\n\n=== M1-ITP Ω-sweep — winner per cell ===\n")
    @printf "%-10s %-6s %-13s %-13s %-13s %-13s %-13s %-8s\n" "B[nT]" "Ω" "E_min" "⟨F_z⟩" "⟨L_z⟩" "f_max" "‖∇E‖" "seed"
    cell_winners = []
    for B_nT in B_VALUES_NT
        for Ω in OMEGAS
            cell_rows = filter(r -> r.omega == Ω && r.B_nT == B_nT, results)
            winner = cell_rows[argmin([r.E for r in cell_rows])]
            push!(cell_winners, winner)
            @printf "%-10.2f %-6.2f %.6f %+.4e %+.4e %.4f %.3e %-8s\n" B_nT Ω winner.E winner.fz_total winner.Lz winner.f_max winner.grad_norm string(
                winner.seed
            )
        end
    end

    # --- Barnett map ⟨F_z⟩ at each (B, Ω) ---
    println("\n--- Barnett response map ⟨F_z⟩(B, Ω) ---")
    @printf "%-10s " "B\\Ω"
    for Ω in OMEGAS
        @printf "%-13.2f " Ω
    end
    println()
    for B_nT in B_VALUES_NT
        @printf "%-10.2f " B_nT
        for Ω in OMEGAS
            w = filter(r -> r.omega == Ω && r.B_nT == B_nT, cell_winners)[1]
            @printf "%+.4e " w.fz_total
        end
        println()
    end

    # --- ⟨L_z⟩ map ---
    println("\n--- Orbital ⟨L_z⟩(B, Ω) ---")
    @printf "%-10s " "B\\Ω"
    for Ω in OMEGAS
        @printf "%-13.2f " Ω
    end
    println()
    for B_nT in B_VALUES_NT
        @printf "%-10.2f " B_nT
        for Ω in OMEGAS
            w = filter(r -> r.omega == Ω && r.B_nT == B_nT, cell_winners)[1]
            @printf "%+.4e " w.Lz
        end
        println()
    end

    # Save full data
    snapshot = [
        Dict(
            "omega" => r.omega, "B_nT" => r.B_nT, "seed" => string(r.seed),
            "E" => r.E, "conv_lbfgs" => r.conv_lbfgs, "grad_norm" => r.grad_norm,
            "breakdown" =>
                Dict(string(k) => getfield(r.breakdown, k) for k in propertynames(r.breakdown)),
            "fz_total" => r.fz_total, "Lz" => r.Lz, "f_max" => r.f_max,
            "m_dist" => r.m_dist, "time_min" => r.time_min,
        ) for r in results
    ]
    @save joinpath(OUT_DIR, "m1_itp_sweep.jld2") snapshot
    @info "Saved M1-ITP sweep"

    # --- Gate-1 verdict ---
    println("\n--- Gate-1 verdict ---")
    max_abs_fz_winner = cell_winners[argmax([abs(w.fz_total) for w in cell_winners])]
    max_abs_Lz_winner = cell_winners[argmax([abs(w.Lz) for w in cell_winners])]
    @printf "Max |⟨F_z⟩|: %.4e at (B=%.1f nT, Ω=%.2f)   ratio to N=%.2f%%\n" abs(
        max_abs_fz_winner.fz_total
    ) max_abs_fz_winner.B_nT max_abs_fz_winner.omega (100 * abs(max_abs_fz_winner.fz_total))
    @printf "Max |⟨L_z⟩|: %.4e at (B=%.1f nT, Ω=%.2f)\n" abs(max_abs_Lz_winner.Lz) max_abs_Lz_winner.B_nT max_abs_Lz_winner.omega
    if abs(max_abs_fz_winner.fz_total) > 0.01
        println(
            "→ Barnett signal MEANINGFUL — theme stands; target M1-realtime/M2-dynamics at this (B, Ω) point.",
        )
    elseif abs(max_abs_fz_winner.fz_total) > 1e-3
        println("→ Barnett signal MARGINAL — finer Ω/B sweep recommended near peak.")
    else
        println("→ Barnett signal NEGLIGIBLE across the scanned (B, Ω) box. Reconsider framework.")
    end

    println("\n=== Done ===")
end

main()
