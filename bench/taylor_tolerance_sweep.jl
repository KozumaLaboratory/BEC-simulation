# What accuracy does the Taylor spin rotation actually need, and what does it
# cost?
#
# `SPIN_TAYLOR_TOL` was inherited from the CUDA kernel, where it was justified by
# a measurement on that device (1e-9 → 1e-13 cost 1.088× at 64³ and 1.024× at
# 128³ — the degree is nearly free when the kernel is memory-bound). The CPU
# Horner is a different realization on different hardware and that justification
# does NOT carry over. This script is the missing measurement.
#
# Two questions, deliberately separated:
#
#   COST    step time and mean Horner degree vs tol. If cost is flat, there is
#           no decision to make: pin at machine precision and delete the knob.
#
#   ANSWER  |E(tol) − E(exact Euler)| vs tol, put NEXT TO the splitting error
#           |E(dt) − E(dt/2)| for the same config. That second number is the
#           error the user already accepted when they chose dt. A truncation
#           error far below it changes nothing anyone can observe; one above it
#           is the tolerance doing damage.
#
# The point of the ratio is that it turns `tol` from a judgement into a derived
# quantity. Nobody has to know what 1e-13 means — they have to know that the
# rotation must not be the dominant error, which is a statement about the
# integrator they already chose.

using Printf
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_ENABLED, SPIN_TAYLOR_TOL, SPIN_TAYLOR_RK_MAX,
    _taylor_rot_schedule, _cpu_spin_rk, _compute_spin_density!

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
const N_STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 200

function run_itp(; dt, n_steps, taylor::Bool, tol_taylor=nothing)
    old_en = SPIN_TAYLOR_ENABLED[]
    old_tol = SPIN_TAYLOR_TOL[]
    SPIN_TAYLOR_ENABLED[] = taylor
    tol_taylor === nothing || (SPIN_TAYLOR_TOL[] = tol_taylor)
    try
        grid = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))
        psi0 = init_psi(grid, SpinSystem(6); state=:spin_coherent,
            init_theta=π / 4, init_phi=0.3)
        t0 = time()
        gs = find_ground_state(;
            grid, atom=Eu151,
            interactions=eu_interaction_params(0.05),
            zeeman=ZeemanParams(EU_p_weak, 0.0),
            potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
            psi_init=psi0,
            dt, n_steps, tol=0.0,          # tol=0 ⇒ always runs all n_steps
            save_every=max(1, n_steps ÷ 2),
            enable_ddi=true, c_dd=EU_c_dd,
            ddi_padding=true, ddi_trunc_radius=-1.0,
            verbose=false,
        )
        (E=gs.energy, wall=time() - t0, psi=copy(gs.workspace.state.psi))
    finally
        SPIN_TAYLOR_ENABLED[] = old_en
        SPIN_TAYLOR_TOL[] = old_tol
    end
end

# Mean/max Horner degree actually taken at a given tol, over the DDI field of a
# converged-ish state. This is what the cost is a function of.
function degree_stats(psi, sm, dt, tol)
    n_pts = size(psi)[1:3]
    N = prod(n_pts)
    fx, fy, fz = (zeros(Float64, n_pts), zeros(Float64, n_pts), zeros(Float64, n_pts))
    _compute_spin_density!(fx, fy, fz, psi, sm, Val(13), 3, n_pts)
    rk = _cpu_spin_rk(Float64, dt)
    F2 = Float64(sm.system.F)^2
    tol2 = tol^2
    rsafe2 = 1.0
    tot = 0
    mx = 0
    @inbounds for i in 1:N
        g = (fx[i]^2 + fy[i]^2 + fz[i]^2) * F2
        _, _, kv = _taylor_rot_schedule(g, rk, SPIN_TAYLOR_RK_MAX, tol2, rsafe2)
        tot += kv
        mx = max(mx, kv)
    end
    (mean=tot / N, max=mx)
end

const DT = 0.002
const TOLS = [1e-5, 1e-7, 1e-9, 1e-11, 1e-13, 1e-15]

println("="^78)
println("Taylor tolerance sweep — Eu F=6 D=13, $(N_GRID)³, $(N_STEPS) ITP steps, dt=$DT")
println("threads=$(Threads.nthreads())")
println("="^78)

# Reference 1: the EXACT rotation. Any Taylor arm's deviation from this is
# truncation error and nothing else.
# Warm up BOTH realizations before anything is timed. The first version of this
# script timed the exact-Euler reference first and cold, which made its wall
# time absorb the whole JIT cascade and reported a "4×" whole-run speedup that
# was an artefact. Kernel-level A/B (bench/bench_itp_step.jl) said 2.19×.
println("\n[0/3] warm-up (both realizations)…")
run_itp(; dt=DT, n_steps=2, taylor=false)
run_itp(; dt=DT, n_steps=2, taylor=true)

println("[1/3] exact Euler reference…")
ref = run_itp(; dt=DT, n_steps=N_STEPS, taylor=false)
@printf("  E_exact   = %.15g   (%.1f s)\n", ref.E, ref.wall)

# Reference 2: the SPLITTING error the user already accepted by choosing dt.
# Same integrator, half the step, twice the steps — same physical time.
println("[2/3] splitting-error reference (dt/2, 2×steps, exact rotation)…")
ref_half = run_itp(; dt=DT / 2, n_steps=2N_STEPS, taylor=false)
split_err = abs(ref_half.E - ref.E)
@printf("  E(dt/2)   = %.15g\n", ref_half.E)
@printf("  |E(dt) − E(dt/2)| = %.3e   ← the error already present at dt=%g\n",
    split_err, DT)

println("[3/3] Taylor arms…")
@printf("\n  %-9s %12s %10s %10s %9s %8s %8s\n",
    "tol", "|ΔE| vs exact", "/split err", "wall (s)", "vs Euler", "deg avg", "deg max")
for tol in TOLS
    r = run_itp(; dt=DT, n_steps=N_STEPS, taylor=true, tol_taylor=tol)
    d = degree_stats(ref.psi, spin_matrices(6), DT, tol)
    dE = abs(r.E - ref.E)
    @printf("  %-9.0e %12.3e %10.2e %10.1f %9.3f %8.2f %8d\n",
        tol, dE, dE / max(split_err, eps()), r.wall, r.wall / ref.wall, d.mean, d.max)
end

println("""

Reading this table:
  * `/split err` < 1 means the rotation is NOT the dominant error at this dt —
    the answer is the same one the user would have got from the exact rotation,
    to within what they already accepted.
  * `vs Euler` is the whole-run cost. If it is flat across tol, the tolerance is
    free and should be pinned at machine precision rather than exposed.
  * `deg avg` explains the cost: the Horner degree grows like log(1/tol)/log(1/R),
    so tightening a decade adds well under one term at production R.
""")
