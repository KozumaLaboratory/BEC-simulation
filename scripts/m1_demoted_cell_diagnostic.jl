#!/usr/bin/env julia
# scripts/m1_demoted_cell_diagnostic.jl
#
# Discriminator for the 2026-06-05 disk≠reeval fork:
#   (B) save bug: LBFGS truly converged at some ψ_true (in-loop grad_norm 9.9e-6
#                 was real); saved ψ is a different iterate → fix is save
#                 ordering, NOT preconditioning. 13 cells are recoverable.
#   (A) metric bug: in-loop convergence metric isn't true ‖∇E‖, driver was
#                  fooled. True grad stalls at 4e-4 → preconditioning needed.
#
# Test on demoted cell B=10.0/Ω=0.00 (originally "✓✓" at disk-grad 9.99e-6,
# fresh-reeval 2.56e-4). Run LBFGS for n_steps=1 verbose=true on the saved ψ:
# observe the in-loop grad_norm at step 1.
#
#   in-loop ≈ 9.9e-6   → LBFGS would re-converge instantly → ⊕(A) ??  Need to
#                       check what LBFGS does NEXT; if instant break with
#                       a recomputed-same-number, that says metric is true
#                       and disk ψ ≠ in-loop ψ at convergence.
#   in-loop ≈ 4e-4     → LBFGS sees current ψ as far from gate → matches
#                       fresh reeval → driver was reporting a stale value
#                       at sweep time → (B) save bug.
#
# Either way the in-loop value is decisive.

using SpinorBEC
using JLD2
using Printf

const SWEEP_DIR = "runs/sprint5_M1_ITP_omega_sweep_converged"
const TARGET = "cell_B10.0_Om0.00.jld2"
const TW = eu151_preset()

cell_path = joinpath(SWEEP_DIR, TARGET)
d = JLD2.load(cell_path)
psi = d["psi"]
result = d["result"]
B_nT = Float64(result["B_nT"])
Ω = Float64(result["omega"])
disk_grad = Float64(result["grad_norm"])
disk_E = Float64(result["E"])

@printf "Testing demoted cell: %s\n" TARGET
@printf "  disk-reported: E=%.6f  ‖∇E‖=%.3e  conv=%s\n" disk_E disk_grad result["conv_lbfgs"]

p_lab = B_nT * TW.p_per_nT
zeeman = TimeDependentZeeman(
    ConstantWaveform(0.0), ConstantWaveform(0.0),
    ConstantWaveform(p_lab), ConstantWaveform(0.0),
)
sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
    normalize_every=1, rotating_frame_omega=Ω)
ws = make_workspace(;
    grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
    zeeman, potential=TW.potential, sim_params=sp,
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
)
copyto!(ws.state.psi, psi)

# Run LBFGS with verbose=true and n_steps just large enough to print step 1.
# With Sobolev α=0.05, same params as the sweep.
println("\n--- LBFGS n_steps=3, verbose=true, sobolev_alpha=0.05 ---")
r = SpinorBEC.find_ground_state_lbfgs(;
    ws_init=ws, n_steps=3, tol=1e-5,
    verbose=true, sobolev_alpha=0.05,
)

println("\n--- LBFGS result ---")
@printf "  converged=%s  last_step=%d\n" r.converged r.last_step
@printf "  grad_norm reported = %.6e\n" r.grad_norm
@printf "  energy reported    = %.6f\n" r.energy

# Compare against fresh re-eval
println("\n--- Independent fresh re-eval (separate ws, same disk ψ) ---")
ws2 = make_workspace(;
    grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
    zeeman, potential=TW.potential, sim_params=sp,
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
)
copyto!(ws2.state.psi, psi)
grad = similar(ws2.state.psi); fill!(grad, 0)
E_re = SpinorBEC.energy_gradient!(grad, ws2.state.psi, ws2)
SpinorBEC._project_constraints!(grad, ws2.state.psi, ws2.grid, nothing,
    ws2.spin_matrices.system.F)
dV = SpinorBEC.cell_volume(TW.grid)
gn_re = sqrt(sum(abs2, grad) * dV)
@printf "  fresh re-eval ‖∇E‖ = %.6e   E = %.6f\n" gn_re Float64(E_re)

println("\n--- Verdict ---")
if isapprox(gn_re, r.grad_norm; rtol=1e-3)
    println("  fresh re-eval ≈ LBFGS final-eval (both ~$(round(gn_re; sigdigits=3)))")
    if isapprox(gn_re, disk_grad; rtol=1e-2)
        println("  → All three (fresh, LBFGS-final-eval, disk) agree")
        println("  → No drift; original disk value is consistent. Reaudit must")
        println("    have had a separate bug.")
    else
        println("  → fresh + LBFGS-final agree BUT disk disagrees by ~$(round(gn_re/disk_grad; sigdigits=3))×")
        println("  → SAVE BUG (B): sweep recorded grad_norm at some ψ_in-loop")
        println("    that wasn't the ψ that got saved. Driver bug in convergence-exit")
        println("    save path. CONDITIONING NOT THE PROBLEM for this cell.")
        println("  → Implications: 13 demoted cells may be recoverable via save fix.")
    end
else
    println("  fresh re-eval ($(round(gn_re; sigdigits=3))) ≠ LBFGS final-eval ($(round(r.grad_norm; sigdigits=3)))")
    println("  → Fresh re-eval and LBFGS rerun disagree on SAME loaded ψ!")
    println("  → workspace-state dependence: rerunning LBFGS has side effects on ws")
    println("    that my fresh re-eval doesn't reproduce.")
end
