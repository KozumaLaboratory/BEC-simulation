#!/usr/bin/env julia
# scripts/m1_demoted_cell_continuation.jl
#
# Continuation discriminator for the 2026-06-05 (B) save-bug verdict.
#
# Hypothesis (B): sweep saw grad_norm=9.988e-6 at ψ_true; saved a different ψ.
# If well-conditioned, LBFGS from saved ψ should re-converge to ~9.988e-6
# within a few hundred steps, with E re-landing at ~2.691303.
#
# Signatures:
#   re-converges (grad → 9.988e-6, E → 2.691303)  →  (B) confirmed, cell is
#     well-conditioned, save fix recovers thesis cells (cheap rerun, not free)
#   stalls at 2.56e-4  →  (A) hybrid: in-loop metric was real but conditioning
#     prevents true descent — cell needs preconditioning after all
#
# Same target as the 3-step diagnostic. Continue from saved ψ for 5000 steps,
# match the sweep's per-cell LBFGS budget regime.

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
disk_n_steps_so_far = get(d, "n_lbfgs_steps_so_far", "?")

@printf "Continuation test on demoted cell: %s\n" TARGET
@printf "  disk-reported: E=%.6f  ‖∇E‖=%.3e  conv=%s  n_lbfgs_so_far=%s\n\n" disk_E disk_grad result["conv_lbfgs"] string(disk_n_steps_so_far)

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

# Continuation: 5000 LBFGS steps with same Sobolev α as the sweep.
# Verbose at every step to track ‖∇E‖ trajectory.
println("--- LBFGS continuation, n_steps=5000, sobolev_alpha=0.05, tol=1e-5 ---")
t0 = time()
r = SpinorBEC.find_ground_state_lbfgs(;
    ws_init=ws, n_steps=5000, tol=1e-5,
    verbose=true, sobolev_alpha=0.05,
)
elapsed = time() - t0

println()
@printf "--- Continuation result (%.1f min) ---\n" (elapsed/60)
@printf "  converged       = %s\n" r.converged
@printf "  last_step       = %d\n" r.last_step
@printf "  final ‖∇E‖      = %.6e\n" r.grad_norm
@printf "  final E         = %.10f\n" r.energy
@printf "  disk-reported   = E=%.10f ‖∇E‖=%.6e\n" disk_E disk_grad
@printf "  ΔE  vs disk     = %+.3e\n" (r.energy - disk_E)
@printf "  Δ‖∇E‖ vs disk    = %+.3e\n" (r.grad_norm - disk_grad)

println()
println("--- Verdict ---")
if r.converged && abs(r.energy - disk_E) < 1e-3
    println("  ✅ Re-converged to ~disk-reported E AND below gate.")
    println("  → (B) save-bug CONFIRMED. Cell is well-conditioned.")
    println("  → disk E and disk grad_norm BOTH from ψ_true (real iterate);")
    println("    saved ψ was a different iterate. The discrepancy is ONE")
    println("    save bug, not two.")
    println("  → 13 demoted cells likely recoverable via cheap continuation")
    println("    from saved ψ + driver save-path fix (atomic {ψ,E,grad,gate}).")
elseif r.grad_norm < 1e-5
    println("  ✅ Converged to gate, but at different E than disk.")
    println("  → (B) save-bug confirmed in structure. Disk E was from a")
    println("    different iterate than ψ_true now.")
elseif r.grad_norm > 1e-4
    println("  ⚠ Stalled around saved-ψ regime (∇E ~$(round(r.grad_norm; sigdigits=3))).")
    println("  → (A) hybrid: in-loop metric of 9.988e-6 was an artifact;")
    println("    cell IS conditioning-limited from saved ψ.")
    println("  → Save-bug fix alone won't recover this cell — needs")
    println("    preconditioning AND probably a different starting ψ.")
else
    println("  ◆ Partial progress (∇E ~$(round(r.grad_norm; sigdigits=3))).")
    println("  → Need more iterations or finer Sobolev α to discriminate.")
end
