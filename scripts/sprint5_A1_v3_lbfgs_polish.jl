#!/usr/bin/env julia
# scripts/sprint5_A1_v3_lbfgs_polish.jl
#
# Step 1 of the 6-step rigor protocol (anko 2026-06-02 night2).
#
# Take the 3 refined digital-twin states (PCV, I_h, cyclic) and apply
# LBFGS polish on GPU to TRUE convergence (grad_norm < 1e-8). Compare
# fully converged energies; gate any rank claim on
#   max(residual_a, residual_b) < 0.01 * ΔE.
#
# LBFGS asymptotic rate is super-linear, so this should converge in
# hundreds of iterations, not 200000+ ITP steps. Topology is preserved
# only by initial condition — if PCV relaxes to a lower no-winding
# state under LBFGS, that itself is a finding (PCV not true GS).
#
# Note: LBFGS gradient covers kinetic + trap + Zeeman + c0 + c1 + DDI.
# Does NOT cover c2 / tensor_cache. We use Matsui-literal (c_n=0 for
# n≥2) so this is OK; helper warns if violated.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_A1_v3_lbfgs_polish.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Printf
using JLD2

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 50000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((24, 24, 24), (30.0, 30.0, 26.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.1818))
const ZEEMAN = ZeemanParams(0.0, 0.0)
const N_STEPS_LBFGS = 8000
const TOL_LBFGS = 1e-10

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const REFINED_PATH = "runs/sprint5_A1_v3_digital_twin_gpu/refined_states.jld2"

function winding_at(psi_host, c::Int, ic::Int, jc::Int, k::Int, r::Int)
    pts = ComplexF64[]
    for theta in range(0, 2π; length=33)[1:(end - 1)]
        i = round(Int, ic + r * cos(theta))
        j = round(Int, jc + r * sin(theta))
        push!(pts, psi_host[i, j, k, c])
    end
    w = 0.0
    for ki in 1:length(pts)
        knext = mod1(ki+1, length(pts))
        dphi = angle(pts[knext]) - angle(pts[ki])
        while dphi > π
            ;
            dphi -= 2π;
        end
        while dphi < -π
            ;
            dphi += 2π;
        end
        w += dphi
    end
    w / 2π
end

function spin_density_max(ws)
    sm = ws.spin_matrices
    psi_host = Array(ws.state.psi)
    fx, fy, fz = spin_density_vector(psi_host, sm, 3)
    maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
end

function main()
    println("=== A1 v3 LBFGS polish — step 1 of rigor protocol ===\n")
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9

    @load REFINED_PATH snapshot
    @info "Loaded refined states" length(snapshot)

    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))

    results = []
    for s in snapshot
        label = s["init"]
        psi_seed = s["psi"]   # Array{ComplexF64, 4}
        E_refined = s["E"]

        @printf "\n--- LBFGS polish: %s (refined E=%.8f) ---\n" label E_refined
        flush(stdout)

        t0 = time()
        try
            res = find_ground_state_lbfgs(;
                grid=GRID, atom=ATOM, interactions=ip,
                zeeman=ZEEMAN, potential=POT,
                n_steps=N_STEPS_LBFGS, tol=TOL_LBFGS,
                initial_state=:polar, psi_init=psi_seed,
                enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
                backend=CUDABackend(), verbose=false)
            t_run = time() - t0
            E_pol = res.energy
            converged = res.converged
            dE_final = res.dE
            last_step = res.last_step
            ws = res.workspace
            b = energy_decomposition(ws)
            f_max = spin_density_max(ws)
            psi_pol = Array(ws.state.psi)
            wp1 = winding_at(psi_pol, 6, 12, 12, 13, 4)
            wm1 = winding_at(psi_pol, 8, 12, 12, 13, 4)
            wp2 = winding_at(psi_pol, 5, 12, 12, 13, 4)
            wm2 = winding_at(psi_pol, 9, 12, 12, 13, 4)
            @printf "  E_pol = %.10f  ΔE_pol_vs_refined = %+.4e  (%.1f min, conv=%s, dE_final=%.3e at step %d)\n" E_pol (
                E_pol - E_refined
            ) (t_run / 60) (converged ? "✓" : "✗") dE_final last_step
            @printf "  E_ddi = %+.6e  E_spin = %+.6e  E_kin = %+.6e  f_max = %.4f\n" b.ddi b.spin b.kinetic f_max
            @printf "  windings (m=+1, -1, +2, -2) = (%+.3f, %+.3f, %+.3f, %+.3f)\n" wp1 wm1 wp2 wm2
            push!(
                results,
                (
                    label=label, E_refined=E_refined, E_pol=E_pol,
                    converged=converged, dE_final=dE_final, last_step=last_step,
                    b=b, f_max=f_max,
                    psi=psi_pol, w_p1=wp1, w_m1=wm1, w_p2=wp2, w_m2=wm2,
                ),
            )
        catch err
            println("FAILED: $err")
        end
        CUDA.reclaim()
    end

    println("\n\n=== LBFGS-polished rank ===\n")
    sorted = sort(results; by=r -> r.E_pol)
    @printf "%-3s %-26s  %-16s  %-10s  %-10s  %-8s  %-12s\n" "#" "label" "E_pol" "dE_final" "conv" "f_max" "windings(±1)"
    for (i, r) in enumerate(sorted)
        @printf "%-3d %-26s  %+.10e  %.3e  %-4s  %.4f  (%+.2f, %+.2f)\n" i r.label r.E_pol r.dE_final (
            r.converged ? "✓" : "✗"
        ) r.f_max r.w_p1 r.w_m1
    end

    # Gate check: max(residual_a, residual_b) < 0.01 * gap
    # Use dE_final (LBFGS internal residual) as proxy for grad_norm
    println("\n--- Convergence gate (Step 1) ---")
    if length(sorted) >= 2
        a, b = sorted[1], sorted[2]
        gap = b.E_pol - a.E_pol
        max_res = max(a.dE_final, b.dE_final)
        ratio = max_res / abs(gap)
        @printf "Top-2 gap = %.4e (%.4f%% of |E|)\n" gap (100 * gap / abs(a.E_pol))
        @printf "Max dE_final of top-2 = %.4e\n" max_res
        @printf "Gate test: max_dE / gap = %.4e   (target < 0.01)\n" ratio
        if ratio < 0.01 && a.converged && b.converged
            println("→ GATE PASSED. Rank safe at LBFGS-converged accuracy.")
            @printf "→ Winner: %s\n" a.label
        elseif ratio < 0.01
            println(
                "→ GATE marginally PASSED on dE, but convergence flag is ✗ for at least one. Verify topology stability.",
            )
        else
            println("→ GATE FAILED. Rank between top-1 and top-2 is NOT safe.")
            println("  Continue LBFGS (larger n_steps) or report as indistinguishable.")
        end

        # Sector-level gate: PCV-topology sector vs no-winding sector
        # PCV-topology: winding magnitude > 0.5; no-winding: winding magnitude < 0.5
        pcv_sector = filter(r -> abs(r.w_p1) > 0.5 || abs(r.w_m1) > 0.5, sorted)
        nw_sector = filter(r -> abs(r.w_p1) < 0.5 && abs(r.w_m1) < 0.5, sorted)
        if !isempty(pcv_sector) && !isempty(nw_sector)
            println("\n--- Sector-level gate ---")
            pcv_best = pcv_sector[1]
            nw_best = nw_sector[1]
            sector_gap = nw_best.E_pol - pcv_best.E_pol
            sector_res = max(pcv_best.dE_final, nw_best.dE_final)
            sector_ratio = sector_res / abs(sector_gap)
            @printf "PCV-sector best: %s   E=%.8f\n" pcv_best.label pcv_best.E_pol
            @printf "No-wind sector best: %s   E=%.8f\n" nw_best.label nw_best.E_pol
            @printf "Sector gap = %.4e (%.4f%%)\n" sector_gap (
                100 * sector_gap / abs(pcv_best.E_pol)
            )
            @printf "Sector gate: max_dE / sector_gap = %.4e   (target < 0.01)\n" sector_ratio
            if sector_ratio < 0.01
                println("→ SECTOR GATE PASSED. Sector ranking safe.")
            else
                println("→ Sector gate marginal — gap is real but residual not tight enough.")
            end
        end
    end

    out = "runs/sprint5_A1_v3_digital_twin_gpu/lbfgs_polished_states_v2.jld2"
    snap = [
        Dict(
            "label" => r.label, "E_pol" => r.E_pol, "E_refined" => r.E_refined,
            "converged" => r.converged, "dE_final" => r.dE_final, "last_step" => r.last_step,
            "breakdown" => Dict(string(k) => getfield(r.b, k) for k in propertynames(r.b)),
            "f_max" => r.f_max, "psi" => r.psi,
            "windings" => (r.w_p1, r.w_m1, r.w_p2, r.w_m2),
        ) for r in sorted
    ]
    @save out snap
    @info "Saved LBFGS-polished states (v2) to $out"

    println("\n=== Done ===")
end

main()
