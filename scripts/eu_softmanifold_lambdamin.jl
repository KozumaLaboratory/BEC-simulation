# Weak-field Eu DDI ground state: does the symmetry-broken cascade avoid the
# :polar saddle, and is the result a true (soft) minimum?
#
# For a soft B->0 degenerate manifold, |grad E|->0 is NOT convergence: the
# symmetric :polar stationary point is a SADDLE (lambda_min < 0) that gradient
# methods fall into, while the true broken-symmetry GS is a soft minimum
# (lambda_min ~ 0+, Goldstone). Energy selects the basin; the trapped-BdG
# lambda_min certifies minimum-vs-saddle.
#
# Conditions:
#   A polar_trap : init :polar -> LBFGS (no ITP)           expect high E, lambda_min < 0
#   B..D cascade : :m_plus_F + white_noise(seed) -> ITP -> LBFGS warm-start
#                                                          expect low  E, lambda_min ~ 0+
#
# Env (all optional):
#   SM_GRID=48  SM_BOX=24.0  SM_B_UG=10.0  SM_DT=0.002
#   SM_ITP=8000 SM_LBFGS=400 SM_NITER=400 SM_NOISE=0.02 SM_SEEDS=1,2,3
#   SM_SMOKE=1  -> grid 16, itp 200, lbfgs 40, niter 60, seeds 1
#
#   julia --project=. scripts/eu_softmanifold_lambdamin.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
    find_ground_state_lbfgs, init_psi, add_white_noise!, SpinSystem,
    trapped_bdg_lowest_eigenvalue, CUDABackend, CPUBackend
using Printf

geti(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
gets(k, d) = get(ENV, k, d)
const SMOKE = get(ENV, "SM_SMOKE", "") == "1"

const NX     = SMOKE ? 16 : Int(geti("SM_GRID", 48))
const BOX    = geti("SM_BOX", 24.0)
const B_UG   = geti("SM_B_UG", 10.0)
const DT     = geti("SM_DT", 0.002)
const ITP    = SMOKE ? 200 : Int(geti("SM_ITP", 8000))
const LBFGS  = SMOKE ? 40 : Int(geti("SM_LBFGS", 400))
const NITER  = SMOKE ? 60 : Int(geti("SM_NITER", 400))
const NOISE  = geti("SM_NOISE", 0.02)
const SEEDS  = SMOKE ? [1] : parse.(Int, split(gets("SM_SEEDS", "1,2,3"), ","))

# Backend: guard against silent CPU fallback (no CUDA driver => CPU, looks fine
# but is 100x slower). Require GPU unless explicitly on a CPU box.
const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
if !HAS_GPU && !SMOKE
    @warn "CUDA not functional -> CPU run. This is SLOW at 48^3; intended for TSUBAME GPU."
end

const PRESET = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, 1.1818))
const ATOM = PRESET.atom
const SYS = SpinSystem(ATOM.F)
const P_ZEE = Units.bfield_to_p(B_UG * 1e-6, ATOM.g_F, PRESET.omega_ref)
const ZEE = ZeemanParams(P_ZEE, 0.0)   # q = 0

const COMMON = (;
    grid=PRESET.grid, atom=ATOM, interactions=PRESET.interactions,
    potential=PRESET.potential, zeeman=ZEE,
    enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND,
)

@printf("Eu soft-manifold GS: grid=%d^3 box=%.1f B=%.1f uG p=%.3e backend=%s%s\n",
    NX, BOX, B_UG, P_ZEE, HAS_GPU ? "CUDA" : "CPU", SMOKE ? " [SMOKE]" : "")
@printf("c0=%.1f c1=%.3f c_dd=%.3f  ITP=%d LBFGS=%d niter=%d seeds=%s\n",
    PRESET.interactions[0], PRESET.interactions[1], PRESET.c_dd, ITP, LBFGS, NITER, SEEDS)
flush(stdout)

# (E, grad_norm, ψ, ws)
function run_polar_trap()
    r = find_ground_state_lbfgs(; COMMON..., initial_state=:polar,
        n_steps=LBFGS, tol=1e-12, m_lbfgs=10, verbose=false)
    (r.energy, r.grad_norm, r.workspace.state.psi, r.workspace)
end

function run_cascade(seed)
    psi0 = init_psi(PRESET.grid, SYS; state=:m_plus_F)
    add_white_noise!(psi0, NOISE, seed, PRESET.grid)
    gs = find_ground_state(; COMMON..., psi_init=psi0, dt=DT, n_steps=ITP,
        tol=1e-12, save_every=max(1, ITP ÷ 20), verbose=false)
    # newton_polish: append a 2nd-order Newton-CG pass to push the cascade
    # toward genuine stationarity. The soft-manifold LBFGS grad floors high
    # (~2e-2); a valid lambda_min certificate needs a stationary psi.
    gl = find_ground_state_lbfgs(; COMMON...,
        psi_init=Array{ComplexF64}(gs.workspace.state.psi),
        n_steps=LBFGS, tol=1e-12, m_lbfgs=10, newton_polish=true, verbose=false)
    (gl.energy, gl.grad_norm, gl.workspace.state.psi, gl.workspace)
end

function certify(ws, psi)
    HAS_GPU && CUDA.synchronize()
    trapped_bdg_lowest_eigenvalue(ws, psi; niter=NITER, atol=1e-6)
end

rows = Tuple{String, Float64, Float64, Float64, Bool, Bool, Float64}[]
function record!(label, res)
    E, g, psi, ws = res
    c = certify(ws, psi)
    push!(rows, (label, E, g, c.λ_min, c.converged, c.goldstone, c.gap))
    @printf("  %-12s E=%.4f  |gradE|=%.3e  lambda_min=%+.4e conv=%s gold=%s gap=%.3e\n",
        label, E, g, c.λ_min, c.converged, c.goldstone, c.gap)
    flush(stdout)
end

println("\n--- running conditions ---")
record!("polar_trap", run_polar_trap())
for s in SEEDS
    record!("cascade_s$s", run_cascade(s))
end

println("\n================ SUMMARY ================")
@printf("%-12s %9s %11s %12s %5s %5s\n", "cond", "E", "|gradE|", "lambda_min", "conv", "gold")
for (l, E, g, lm, cv, go, gp) in rows
    @printf("%-12s %9.4f %11.2e %+12.4e %5s %5s\n", l, E, g, lm, cv, go)
end
best = rows[argmin([r[2] for r in rows])]
@printf("\nlowest-E: %s  E=%.4f  lambda_min=%+.4e (%s)\n", best[1], best[2], best[4],
    best[4] >= -1e-6 ? "MINIMUM/soft" : "SADDLE")
println("DONE")
