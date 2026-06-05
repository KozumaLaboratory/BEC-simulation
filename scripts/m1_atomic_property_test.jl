#!/usr/bin/env julia
# scripts/m1_atomic_property_test.jl
#
# Verifies spine G atomic property at LBFGS return:
#   r = find_ground_state_lbfgs(...)
#   ψ_returned = Array(r.workspace.state.psi)
#   grad_norm_returned = r.grad_norm
#   energy_returned = r.energy
#
#   # Build INDEPENDENT fresh workspace (no shared state)
#   ws_fresh = make_workspace(... same params ...)
#   copyto!(ws_fresh.state.psi, ψ_returned)
#   grad = energy_gradient!(...)
#   _project_constraints!(...)
#   grad_norm_fresh = sqrt(sum(abs2, grad) * dV)
#
#   # The atomic property:
#   @assert grad_norm_fresh ≈ grad_norm_returned to ulp
#   @assert energy_fresh ≈ energy_returned to ulp
#
# BEFORE the spine-G fix this assertion failed (30-50× drift, M1
# 2026-06-05 audit). AFTER the fix it should pass.

using SpinorBEC
using SpinorBEC: energy_gradient!, _project_constraints!
using JLD2
using Printf

const SWEEP_DIR = "runs/sprint5_M1_ITP_omega_sweep_converged"
const CELL_NAME = "cell_B10.0_Om0.00.jld2"
const TW = eu151_preset()

function main()
    # Load any saved ψ as a starting point
    d = JLD2.load(joinpath(SWEEP_DIR, CELL_NAME))
    psi_start = d["psi"]
    result = d["result"]
    B_nT = Float64(result["B_nT"])
    Ω = Float64(result["omega"])

    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=Ω)

    @info "Phase 1: Run LBFGS (only 3 steps — we just need to exercise the epilogue)"
    ws_lbfgs = make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman, potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
    )
    copyto!(ws_lbfgs.state.psi, psi_start)

    r = SpinorBEC.find_ground_state_lbfgs(;
        ws_init=ws_lbfgs, n_steps=3, tol=1e-5,
        verbose=false, sobolev_alpha=0.05,
    )

    psi_returned = Array(r.workspace.state.psi)
    grad_norm_returned = r.grad_norm
    energy_returned = r.energy

    @printf "LBFGS returned: E=%.10f  ‖∇E‖=%.10e  converged=%s\n" energy_returned grad_norm_returned r.converged

    @info "Phase 2: Independent fresh ws re-evaluation at ψ_returned"
    ws_fresh = make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman, potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
    )
    copyto!(ws_fresh.state.psi, psi_returned)

    E_fresh = SpinorBEC.total_energy(ws_fresh)
    grad = similar(ws_fresh.state.psi)
    fill!(grad, 0)
    energy_gradient!(grad, ws_fresh.state.psi, ws_fresh)
    _project_constraints!(grad, ws_fresh.state.psi, ws_fresh.grid,
        nothing, ws_fresh.spin_matrices.system.F)
    dV = SpinorBEC.cell_volume(TW.grid)
    grad_norm_fresh = sqrt(sum(abs2, grad) * dV)

    @printf "fresh ws re-eval: E=%.10f  ‖∇E‖=%.10e\n" Float64(E_fresh) grad_norm_fresh

    println()
    println("=== Atomic property check ===")
    ΔE = Float64(E_fresh) - energy_returned
    Δg = grad_norm_fresh - grad_norm_returned
    @printf "ΔE              = %+.3e   (should be 0 to ulp)\n" ΔE
    @printf "Δ‖∇E‖           = %+.3e   (should be 0 to ulp)\n" Δg
    rel_g = abs(Δg) / max(grad_norm_returned, 1e-30)
    @printf "rel Δ‖∇E‖       = %+.3e\n" rel_g

    println()
    if abs(ΔE) < 1e-10 && rel_g < 1e-10
        println("✅ ATOMIC PROPERTY HOLDS to ulp.")
        println("   {ws.state.psi, r.energy, r.grad_norm} are all consistent")
        println("   with a single iterate. Save-bug structurally eliminated.")
    elseif rel_g < 1e-6
        println("◆ Marginal (rel diff $rel_g).")
        println("   Acceptable for FP-level consistency but worth understanding.")
    else
        println("⚠ ATOMIC PROPERTY VIOLATED (rel Δ‖∇E‖ = $rel_g).")
        println("   The spine-G atomic finalization didn't fully close the drift.")
        println("   Investigate: ws.state.psi at return ≠ snapshot used for E/∇E.")
    end
end

main()
