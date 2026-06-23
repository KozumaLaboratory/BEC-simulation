# scripts/edh_vs_flower/repolish_gs.jl
# ============================================================================
# Re-polish an OLD-scheme cached ground state with the CURRENT-main LBFGS.
#
# Rationale: the Tsubame b_sweep ground states (lbfgs_<B>uG_final_psi.jld2,
# N=5e4, box=18, git_sha 9925f41a) were converged under an older compute
# scheme. Verification shows they are NOT stationary under current main
# (grad_norm explodes). But they are EXCELLENT initial seeds: LBFGS from a
# near-correct density/spin profile converges far faster than ITP-from-scratch.
# Re-polishing each cached state under the current scheme yields the cleanest
# ground state with the latest method, WITHOUT recomputing the expensive ITP.
#
# Matches the cached run's physical parameters exactly (N, box, B, c_dd read
# from the file's metadata) so the re-polished state is a drop-in replacement.
#
# Usage:
#   julia --project=. scripts/edh_vs_flower/repolish_gs.jl <in.jld2> <out.jld2> \
#       [--steps 1500] [--tol 1e-7] [--newton] [--lhy] [--backend gpu]
#
# Default: no LHY (matches the original no-LHY b_sweep). Pass --lhy to add the
# scalar Lima-Pelster LHY (latest physics for Eu near the dipolar boundary).
using SpinorBEC
using SpinorBEC: eu151_preset, ZeemanParams, find_ground_state_lbfgs, Units,
                 CPUBackend, CUDABackend, InteractionParams
using JLD2, Printf, LinearAlgebra

const IN  = ARGS[1]
const OUT = ARGS[2]
_opt(flag, d) = (i = findfirst(==(flag), ARGS); (i === nothing || i == length(ARGS)) ? d : ARGS[i+1])
const STEPS  = parse(Int, _opt("--steps", "1500"))
const TOL    = parse(Float64, _opt("--tol", "1e-7"))
# Sobolev preconditioner exponent. The weak-field (≲10 mG) GS sits on a
# near-degenerate spin-orientation manifold where plain LBFGS stalls (the
# `spin_xy_anisotropy_diag.jl` / b_sweep "floor" effect). Tuning α (or :auto)
# changes the metric and can unstick it — exposed here for the convergence
# study. Higher α weights smooth (low-k) directions more heavily.
const SOBOLEV = let v = _opt("--sobolev", "0.5"); v == "auto" ? :auto : parse(Float64, v) end
const NEWTON = "--newton" in ARGS
const USELHY = "--lhy" in ARGS
const BK     = _opt("--backend", "cpu")

c = jldopen(IN, "r") do f
    (psi = ComplexF64.(f["psi"]), B = Float64(f["B_gauss"]),
     n = Tuple(Int.(f["grid_n"])), box = Tuple(Float64.(f["grid_box"])),
     N = Int(f["n_atoms"]), cdd = Float64(f["c_dd"]),
     E0 = Float64(f["E"]), g0 = Float64(f["grad_norm"]))
end
@printf("[repolish] seed: B=%.4g G  N=%d  grid=%s box=%s  E0=%.6g grad0=%.2e\n",
    c.B, c.N, string(c.n), string(c.box), c.E0, c.g0)

backend = (BK == "gpu") ? CUDABackend() : CPUBackend()
preset = eu151_preset(; n_atoms=c.N, n_pts=c.n, box=c.box,
    trap_ratios=(1.0, 1.0, 1.181818), omega_ref=691.1504)
inter = USELHY ? InteractionParams(preset.interactions.c; c_lhy=:scalar) : preset.interactions
p = Units.bfield_to_p(c.B * 1e-4, preset.atom.g_F, preset.omega_ref)

gl = find_ground_state_lbfgs(;
    grid=preset.grid, atom=preset.atom, interactions=inter,
    zeeman=ZeemanParams(p, 0.0), potential=preset.potential,
    psi_init=c.psi, n_steps=STEPS, tol=TOL, m_lbfgs=10, sobolev_alpha=0.5,
    newton_polish=NEWTON, enable_ddi=true, c_dd=c.cdd, secular_ddi=false,
    backend=backend, verbose=true,
)
@printf("[repolish] result: E=%.6g  grad_norm=%.3e  (seed grad was %.2e)\n",
    gl.energy, gl.grad_norm, c.g0)

psi_out = Array{ComplexF64}(gl.workspace.state.psi)
jldsave(OUT; psi=psi_out, B_gauss=c.B, grid_n=collect(c.n), grid_box=collect(c.box),
    n_atoms=c.N, c_dd=c.cdd, F=6, E=gl.energy, grad_norm=gl.grad_norm,
    method="repolish(new-scheme LBFGS $(STEPS), newton=$(NEWTON), lhy=$(USELHY)) from $(basename(IN))",
    secular_ddi=0, lhy=USELHY ? "scalar" : "none")
@printf("[repolish] wrote %s\n", OUT)
