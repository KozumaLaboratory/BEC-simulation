#!/usr/bin/env julia
# scripts/m1_groundstate_audit.jl
#
# Gate (1) of the M1 phase-verdict: GROUND-STATE-NESS of the on-disk
# 30-cell rotating-frame sweep (runs/sprint5_M1_multistart_groundstate/,
# B × Ω). The gradients are gated (master oracle) and the BdG is now
# anchored (test_bogoliubov_anchor) — but "gradient correct" ≠ "this ψ
# is the ground state". This audit extracts that gate, per cell:
#
#   - fresh re-eval ‖∇E‖ from the saved winner ψ. The disk grad_norm is
#     the save-bug-drifted value (saved ψ and saved grad_norm are
#     different iterates — see m1_save_bug_two_basins) and is NOT
#     authoritative; the fresh re-eval IS the verdict.
#   - basin reproducibility: how many independent seeds reached the
#     winner energy (candidate ENERGIES are reliable even where
#     grad_norm drifted), and the gap to the next distinct basin.
#
# Classifies each cell and writes a (B,Ω) table. This is gate (1) only;
# saddle-rejection (gate 2, BdG stability) and vortex-resolution (gate
# 3, the monopole resolution lesson) are separate. No bare-table claim:
# the table is the *gated* ground-state-ness, honestly partitioned.
#
# Cost: ~5 s/cell CPU re-eval (GPU=CPU parity gated). 30 cells ≈ 3 min.

using SpinorBEC
using SpinorBEC: energy_gradient!
using JLD2
using Printf
using LinearAlgebra

const DIR = "runs/sprint5_M1_multistart_groundstate"
const TW = eu151_preset()
const TOL = 1e-5          # B≥1 convergence gate
const TOL_B0 = 1e-3       # B=0 Goldstone manifold floor (degenerate spin)

function build_cpu_ws(B_nT::Float64, Ω::Float64)
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=Ω)
    make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman, potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
    )
end

function audit_cell(f::String)
    d = JLD2.load(f)
    haskey(d, "psi") || return nothing
    psi = d["psi"]
    r = d["result"]
    B = Float64(r["B_nT"])
    Ω = Float64(r["omega"])
    cands = d["all_candidates_summary"]            # (seed, E, gnorm, status)
    Es = [Float64(c[2]) for c in cands]
    iwin = argmin(Es)
    winnerE = Es[iwin]
    winner = String(cands[iwin][1])

    # basin reproducibility from reliable candidate ENERGIES
    ΔE = max(1e-3, 1e-4 * abs(winnerE))
    n_basin = count(E -> abs(E - winnerE) < ΔE, Es)
    distinct = sort(unique(round.(Es ./ ΔE)))       # bucketed basins
    gap = length(distinct) >= 2 ?
          (distinct[2] - distinct[1]) * ΔE : Inf

    # authoritative ‖∇E‖: fresh re-eval of the saved winner ψ
    ws = build_cpu_ws(B, Ω)
    copyto!(ws.state.psi, psi)
    grad = similar(ws.state.psi)
    fill!(grad, 0)
    Ere = energy_gradient!(grad, ws.state.psi, ws)
    SpinorBEC._project_constraints!(
        grad, ws.state.psi, ws.grid, nothing, ws.spin_matrices.system.F
    )
    gnorm_re = sqrt(sum(abs2, grad) * SpinorBEC.cell_volume(TW.grid))

    cls = if B == 0.0
        gnorm_re < TOL_B0 ? :goldstone : :unconverged
    elseif gnorm_re < TOL
        n_basin >= 2 ? :GS_confident : :converged_single
    else
        :unconverged
    end

    (; B, Ω, winner, winnerE, n_seeds=length(cands), n_basin, gap,
        gnorm_disk=Float64(r["grad_norm"]), gnorm_re,
        E_reeval=Float64(Ere), cls)
end

function main()
    files = sort(
        filter(f -> startswith(basename(f), "cell_B") &&
                    endswith(f, ".jld2"),
            readdir(DIR; join=true)),
    )
    @printf("Gate (1) ground-state-ness audit — %d cells in %s\n\n", length(files), DIR)
    @printf("%-7s %-6s %-22s %12s %5s %5s %10s %11s %11s  %s\n",
        "B[nT]", "Ω", "winner", "E", "seed", "basn", "gap", "‖∇E‖disk", "‖∇E‖fresh", "class")
    println("-"^118)
    rows = []
    for f in files
        a = audit_cell(f)
        a === nothing && continue
        push!(rows, a)
        @printf("%-7.1f %-6.2f %-22s %12.5f %5d %5d %10.2e %11.2e %11.2e  %s\n",
            a.B, a.Ω, a.winner, a.winnerE, a.n_seeds, a.n_basin,
            a.gap, a.gnorm_disk, a.gnorm_re, a.cls)
    end
    println("-"^118)
    for c in (:GS_confident, :converged_single, :goldstone, :unconverged)
        n = count(r -> r.cls === c, rows)
        @printf("  %-18s %d / %d\n", string(c), n, length(rows))
    end
    JLD2.save(joinpath(DIR, "groundstate_audit.jld2"), "rows", rows)
    @printf("\nwrote %s\n", joinpath(DIR, "groundstate_audit.jld2"))
end

main()
