#!/usr/bin/env julia
# scripts/m1_fresh_reevaluate.jl
#
# Spine-G first implementation piece: collapse "state ψ" and "gate-status
# grad_norm" into one authoritative pair by **re-evaluating ‖∇E‖ from
# the saved ψ** for every cell. The sweep's reported `grad_norm` and
# saved ψ are different iterates (~4% drift at cell 7 due to LBFGS
# final-state ordering), so the sweep value is NOT authoritative.
#
# Usage:
#   julia --project=. scripts/m1_fresh_reevaluate.jl
#   → reads runs/sprint5_M1_ITP_omega_sweep_converged/cell_*.jld2
#   → writes runs/sprint5_M1_ITP_omega_sweep_converged/fresh_reaudit.jld2
#     containing {B_nT, omega, seed, E_saved, E_reeval, grad_norm_saved,
#                 grad_norm_reeval, gate_saved, gate_reeval}
#
# Wire into m1_sweep_golden_export.jl (downstream) so dashboard uses
# `grad_norm_reeval` for verdict colouring, not `grad_norm_saved`.
#
# Cost: ~5 s per cell × N_cells CPU. 30 cells → ~2.5 min.

using SpinorBEC
using SpinorBEC: energy_gradient!, _to_device
using JLD2
using Printf
using LinearAlgebra

const SWEEP_DIR = "runs/sprint5_M1_ITP_omega_sweep_converged"
const TW = eu151_preset()
const TOL_LBFGS = 1e-5

function build_cpu_ws(B_nT::Float64, Ω::Float64)
    # CRITICAL: use make_workspace directly, NOT find_ground_state(n_steps=0).
    # The n_steps=0 builder is incomplete — see gotcha entry
    # `find_ground_state_n_steps_zero_incomplete_builder` (2026-06-05).
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

function reevaluate_cell(cell_path::String)
    cached = JLD2.load(cell_path)
    haskey(cached, "psi") || return nothing
    psi = cached["psi"]
    result = cached["result"]
    B_nT = Float64(result["B_nT"])
    Ω = Float64(result["omega"])
    seed = result["seed"]
    grad_norm_saved = Float64(result["grad_norm"])
    E_saved = Float64(result["E"])
    conv_saved = Bool(result["conv_lbfgs"])

    ws = build_cpu_ws(B_nT, Ω)
    copyto!(ws.state.psi, psi)

    grad = similar(ws.state.psi)
    fill!(grad, 0)
    E_reeval = energy_gradient!(grad, ws.state.psi, ws)
    SpinorBEC._project_constraints!(grad, ws.state.psi, ws.grid,
        nothing, ws.spin_matrices.system.F)
    dV = SpinorBEC.cell_volume(TW.grid)
    grad_norm_reeval = sqrt(sum(abs2, grad) * dV)

    gate_saved = (conv_saved && grad_norm_saved < TOL_LBFGS)
    gate_reeval = (grad_norm_reeval < TOL_LBFGS)

    return (;
        B_nT, omega=Ω, seed,
        E_saved, E_reeval=Float64(E_reeval),
        grad_norm_saved, grad_norm_reeval,
        gate_saved, gate_reeval,
        E_drift=Float64(E_reeval) - E_saved,
        grad_norm_drift=grad_norm_reeval - grad_norm_saved,
        grad_norm_ratio=grad_norm_reeval / grad_norm_saved,
    )
end

function main()
    isdir(SWEEP_DIR) || error("Sweep dir missing: $SWEEP_DIR")
    cell_files = sort(filter(f -> startswith(basename(f), "cell_B") &&
                                  endswith(f, ".jld2"),
                             readdir(SWEEP_DIR; join=true)))
    isempty(cell_files) && error("No cell files in $SWEEP_DIR")

    @printf "Found %d cells. Re-evaluating ‖∇E‖ on CPU from saved ψ...\n\n" length(cell_files)
    @printf "%-8s %-6s %-12s   %12s %12s   %12s %12s   %-8s %-8s\n" "B[nT]" "Ω" "seed" "E_saved" "E_reeval" "‖∇E‖_saved" "‖∇E‖_reeval" "gate_sv" "gate_re"
    println("-" ^ 130)

    audits = []
    n_gate_match = 0
    n_promoted = 0
    n_demoted = 0
    for cp in cell_files
        a = reevaluate_cell(cp)
        a === nothing && continue
        push!(audits, a)
        if a.gate_saved == a.gate_reeval
            n_gate_match += 1
        elseif !a.gate_saved && a.gate_reeval
            n_promoted += 1
        else
            n_demoted += 1
        end
        flag = if a.gate_saved == a.gate_reeval
            "—"
        elseif !a.gate_saved && a.gate_reeval
            "PROMO"
        else
            "DEMOT"
        end
        @printf "%-8.1f %-6.2f %-12s   %12.6f %12.6f   %12.4e %12.4e   %-8s %-8s  %s\n" a.B_nT a.omega string(a.seed) a.E_saved a.E_reeval a.grad_norm_saved a.grad_norm_reeval (a.gate_saved ? "✓✓" : "✗") (a.gate_reeval ? "✓✓" : "✗") flag
        flush(stdout)
    end

    println()
    println("=" ^ 60)
    @printf "Re-audit summary:\n"
    @printf "  cells re-evaluated:  %d\n" length(audits)
    @printf "  gate verdict match:  %d\n" n_gate_match
    @printf "  promoted (✗→✓✓):     %d   (sweep was OVERLY pessimistic)\n" n_promoted
    @printf "  demoted (✓✓→✗):      %d   (sweep was OVERLY optimistic)\n" n_demoted

    # Drift stats
    drifts_grad = [abs(a.grad_norm_drift) for a in audits]
    drifts_E = [abs(a.E_drift) for a in audits]
    if !isempty(drifts_grad)
        @printf "\n  ‖∇E‖ drift |saved−reeval|: max=%.3e, median=%.3e, mean=%.3e\n" maximum(drifts_grad) (sort(drifts_grad)[end÷2+1]) (sum(drifts_grad)/length(drifts_grad))
        @printf "  E    drift |saved−reeval|: max=%.3e, median=%.3e, mean=%.3e\n" maximum(drifts_E) (sort(drifts_E)[end÷2+1]) (sum(drifts_E)/length(drifts_E))
    end

    # Save audit
    out_path = joinpath(SWEEP_DIR, "fresh_reaudit.jld2")
    JLD2.jldopen(out_path, "w") do f
        f["audits"] = [
            Dict(string(k) => getfield(a, k) for k in propertynames(a))
            for a in audits
        ]
        f["TOL_LBFGS"] = TOL_LBFGS
        f["n_cells"] = length(audits)
        f["timestamp"] = time()
    end
    @printf "\n✅ Saved re-audit to %s\n" out_path
    @printf "\nNext: wire `grad_norm_reeval` into m1_sweep_golden_export.jl as\n"
    @printf "      the authoritative gate-status. The disk-reported value is\n"
    @printf "      stale (LBFGS save-ordering drift).\n"
end

main()
