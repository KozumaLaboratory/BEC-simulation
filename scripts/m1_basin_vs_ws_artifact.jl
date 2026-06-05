#!/usr/bin/env julia
# scripts/m1_basin_vs_ws_artifact.jl
#
# Discriminate (I) two basins vs (II) ws-dependent energy artifact for the
# 2.6940 vs 2.6913 energy gap at cell B=10/Ω=0.0:
#
# Test: take a converged ψ (from continuation), compute total_energy in
# (a) make_workspace direct path  — gives E_fresh
# (b) find_ground_state(n_steps>0) path — same path the sweep took
#
# (a) ≈ (b) → energy is ws-independent → 2.6913 is a DIFFERENT critical
#            point in a different basin → ψ_true lost permanently.
# (a) ≠ (b) → ws-energy artifact (II), same precedent as 7.61/9.04 →
#            same basin, energy gap is artifact → ψ_true == continuation ψ.

using SpinorBEC
using SpinorBEC: energy_decomposition, energy_gradient!
using JLD2
using LinearAlgebra
using Printf

const SWEEP_DIR = "runs/sprint5_M1_ITP_omega_sweep_converged"
const TARGET = "cell_B10.0_Om0.00.jld2"
const TW = eu151_preset()

cell_path = joinpath(SWEEP_DIR, TARGET)
d = JLD2.load(cell_path)
psi_disk = d["psi"]
result = d["result"]
B_nT = Float64(result["B_nT"])
Ω = Float64(result["omega"])
disk_E = Float64(result["E"])
disk_grad = Float64(result["grad_norm"])

@printf "Cell %s\n" TARGET
@printf "  disk:  E=%.10f  ‖∇E‖=%.6e\n\n" disk_E disk_grad

p_lab = B_nT * TW.p_per_nT
zeeman = TimeDependentZeeman(
    ConstantWaveform(0.0), ConstantWaveform(0.0),
    ConstantWaveform(p_lab), ConstantWaveform(0.0),
)
sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
    normalize_every=1, rotating_frame_omega=Ω)

# 1. Build via make_workspace direct (fresh path)
@info "Path A: make_workspace direct, then continuation to find ψ_cont"
ws_A_start = make_workspace(;
    grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
    zeeman, potential=TW.potential, sim_params=sp,
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
)
copyto!(ws_A_start.state.psi, psi_disk)
r = SpinorBEC.find_ground_state_lbfgs(;
    ws_init=ws_A_start, n_steps=1000, tol=1e-5,
    verbose=false, sobolev_alpha=0.05,
)
psi_cont = Array(r.workspace.state.psi)
E_cont_in_A_ws = r.energy
@printf "  ψ_cont reached: E=%.10f  ‖∇E‖=%.6e  conv=%s  steps=%d\n\n" E_cont_in_A_ws r.grad_norm r.converged r.last_step

# 2. Compute total_energy of ψ_cont in a fresh make_workspace
@info "Eval-A: total_energy(ψ_cont) via fresh make_workspace"
ws_eval_A = make_workspace(;
    grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
    zeeman, potential=TW.potential, sim_params=sp,
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
)
copyto!(ws_eval_A.state.psi, psi_cont)
E_A = SpinorBEC.total_energy(ws_eval_A)

# 3. Compute total_energy of ψ_cont in a workspace built via find_ground_state
#    (the sweep's path) — with n_steps≥1 to ensure full setup
@info "Eval-B: total_energy(ψ_cont) via find_ground_state(n_steps=10) path"
r_FGS = find_ground_state(;
    grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
    zeeman, potential=TW.potential,
    dt=0.005, n_steps=10, tol=1e-12,
    initial_state=:polar, verbose=false,
    psi_init=psi_cont,
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
    rotating_frame_omega=Ω,
)
# r_FGS already evolved ψ by 10 ITP steps so its ψ differs slightly.
# Restore ψ_cont and compute total_energy in that ws.
ws_eval_B = r_FGS.workspace
copyto!(ws_eval_B.state.psi, psi_cont)
E_B = SpinorBEC.total_energy(ws_eval_B)

# 4. Compare
println()
println("=== Same ψ_cont, two ws construction paths ===")
@printf "  E_A (make_workspace direct):       %.10f\n" Float64(E_A)
@printf "  E_B (find_ground_state n_steps=10): %.10f\n" Float64(E_B)
@printf "  ΔE (B - A):                         %+.6e\n" (Float64(E_B) - Float64(E_A))
@printf "\n  for reference:\n"
@printf "    disk-reported E (sweep, ψ_true):  %.10f\n" disk_E
@printf "    continuation E (in ws_A):         %.10f\n" E_cont_in_A_ws

# Also compare per-term breakdowns
ed_A = energy_decomposition(ws_eval_A)
copyto!(ws_eval_B.state.psi, psi_cont)
ed_B = energy_decomposition(ws_eval_B)
println("\n  per-term:")
for f in propertynames(ed_A)
    a = Float64(getproperty(ed_A, f))
    b = Float64(getproperty(ed_B, f))
    Δ = b - a
    flag = abs(Δ) > 1e-4 ? "  ←" : ""
    @printf "    %-20s  A=%+.10f  B=%+.10f  Δ=%+.3e %s\n" string(f) a b Δ flag
end

println()
println("=== Verdict ===")
if isapprox(Float64(E_A), Float64(E_B); atol=1e-6)
    println("  ✅ E_A ≈ E_B (ws-independent).")
    println("  → (I) basins: 2.6913 (disk) is a DIFFERENT critical point;")
    println("     ψ_true is permanently lost in save bug.")
    println("  → Recovery strategy: multi-start + lowest-E winner for each cell.")
else
    println("  ⚠ E_A ≠ E_B by $(round(Float64(E_B) - Float64(E_A); sigdigits=3)).")
    println("  → (II) ws-energy artifact (same basin, energy depends on ws path).")
    println("  → 2.6913 IS the same state as 2.6940; the gap is artifact.")
    println("  → ψ_true == continuation ψ. Recovery: fix ws-energy + simple continuation.")
    println("  → Per-term ← markers above show which term has the ws-dependent drift.")
end
