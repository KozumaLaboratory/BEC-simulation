#!/usr/bin/env julia
# scripts/sprint5_A1_v3_digital_twin_refine.jl
#
# Rank-stability refine for the digital-twin GPU result. Re-runs the
# top-3 (PCV, I_h, cyclic) with n_steps=60000 and tol=1e-9 on GPU.
# Original run had only PCV converged (others conv=✗) and rank gap
# 0.089% — may be unstable under tighter convergence.
#
# Same digital-twin geometry as the original run; identical seeds and
# initial conditions for reproducibility.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_A1_v3_digital_twin_refine.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Random
using Printf
using JLD2

const F = 6
const TW = eu151_preset()
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 60000   # 3× the original
const TOL_ITP = 1e-9        # 2 orders tighter

const REFINE_INITS = [:polar_core_vortex, :icosahedral_explicit, :cyclic]
const SEED = 1

function build_psi(state::Symbol, sys)
    if state === :icosahedral_explicit
        ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
        psi = init_psi(TW.grid, sys; state=:polar)
        for k in 1:size(psi, 3), j in 1:size(psi, 2), i in 1:size(psi, 1)
            spatial_amp = sqrt(sum(abs2, view(psi, i, j, k, :)))
            for c in 1:size(psi, 4)
                psi[i, j, k, c] = spatial_amp * ζ[c]
            end
        end
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(TW.grid))
        n > 0 && (psi ./= n)
        return psi
    else
        return init_psi(TW.grid, sys; state=state)
    end
end

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(TW.grid))
    psi ./= n
end

function run_one(init_state::Symbol)
    sys = SpinSystem(F)
    psi_init = build_psi(init_state, sys)
    apply_noise!(psi_init, 0.01, SEED)
    initial_state_for_fgs = init_state === :icosahedral_explicit ? :polar : init_state
    ws, conv, E, _, _ = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=ZEEMAN, potential=TW.potential,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL_ITP,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        backend=CUDABackend())
    return ws, E, conv
end

function spin_density_max(ws)
    sm = ws.spin_matrices
    psi_host = Array(ws.state.psi)
    fx, fy, fz = spin_density_vector(psi_host, sm, 3)
    maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
end

function main()
    println("=== A1 v3 digital twin REFINE (top-3, 60k ITP, tol=1e-9) ===\n")
    @printf "%d inits × 1 seed at n_steps=%d  tol=%.1e on GPU\n\n" length(REFINE_INITS) N_STEPS_ITP TOL_ITP
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9

    println("Original first-pass:")
    println("  polar_core_vortex   E=9.207429  conv=✓")
    println("  icosahedral_explicit E=9.215641  conv=✗")
    println("  cyclic              E=9.222582  conv=✗")
    println()

    results = []
    for init in REFINE_INITS
        print("  init=$init seed=$SEED ... ")
        flush(stdout)
        t0 = time()
        ws, E, conv = run_one(init)
        t_run = time() - t0
        b = energy_decomposition(ws)
        f_max = spin_density_max(ws)
        push!(results, (init=init, E=E, conv=conv, b=b, f_max=f_max,
            psi=Array(ws.state.psi)))
        @printf "E=%.8f conv=%s E_ddi=%+.4e E_spin=%+.4e f_max=%.4f (%.1f min)\n" E (
            conv ? "✓" : "✗"
        ) b.ddi b.spin f_max (t_run / 60)
        CUDA.reclaim()
    end

    println("\n--- REFINED rank ---\n")
    sorted = sort(results; by=r -> r.E)
    @printf "  %-3s %-26s %-14s  %-12s  %-12s  %-6s\n" "#" "init" "E_total (refined)" "E_ddi" "E_spin" "f_max"
    for (i, r) in enumerate(sorted)
        @printf "  %-3d %-26s %+.8e  %+.4e  %+.4e  %.4f\n" i string(r.init) r.E r.b.ddi r.b.spin r.f_max
    end

    println("\n--- Stability check ---\n")
    orig = Dict(
        :polar_core_vortex => 9.207429, :icosahedral_explicit => 9.215641, :cyclic => 9.222582
    )
    for r in sorted
        de = r.E - orig[r.init]
        @printf "  %-26s  ΔE refine vs first-pass = %+.4e\n" string(r.init) de
    end
    println()
    winner = sorted[1].init
    second = sorted[2].init
    gap = sorted[2].E - sorted[1].E
    @printf "Refined winner: %s\n" winner
    @printf "Refined gap to #2 (%s): %.4e (%.4f%% of |E|)\n" second gap (100gap / abs(sorted[1].E))

    if winner == :polar_core_vortex && gap > 0
        println("→ PCV winner CONFIRMED after refine.")
    elseif winner == :icosahedral_explicit
        println(
            "→ I_h reclaimed the lead under tighter convergence. Texture win may have been first-pass artefact.",
        )
    else
        println("→ Rank shifted — read individual ΔE above.")
    end

    # Save refined states
    out = "runs/sprint5_A1_v3_digital_twin_gpu/refined_states.jld2"
    snapshot = [
        Dict(
            "init" => string(r.init), "seed" => SEED,
            "E" => r.E, "conv" => r.conv,
            "breakdown" => Dict(string(k) => getfield(r.b, k) for k in propertynames(r.b)),
            "f_max" => r.f_max, "psi" => r.psi) for r in sorted
    ]
    @save out snapshot
    @info "Saved refined states to $out"

    println("\n=== Done ===")
end

main()
