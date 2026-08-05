#!/usr/bin/env julia
# Does the L-BFGS history need to be 20 deep?
#
#   julia --project=. bench/probe_lbfgs_history_depth.jl [cpu|gpu] [grid_n]
#
# With the line search now measured at ~1.1 energy evaluations per USEFUL
# iteration (bench/probe_lbfgs_line_search.jl), the two-loop recursion is the
# largest remaining item: 9.8 ms of a ~31 ms iteration at 24^3, and it is pure
# history traffic — 2m psi-sized arrays, read twice each — so it scales
# linearly in `m_lbfgs`.
#
# Halving `m` therefore halves that term, but only pays if the search does not
# then need proportionally more iterations. Both are measured here: iterations
# to a REACHABLE tolerance, and wall per iteration. The product is the number
# that matters, so it is what the last column reports.
#
# `m_lbfgs = 20` carries the comment "measured ~9x lower grad_norm floor" — the
# attained `|grad|` is printed so that a cheaper `m` cannot be adopted while
# quietly landing somewhere worse.

const BACKEND_ARG = length(ARGS) >= 1 ? ARGS[1] : "cpu"
const GRID_N = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 24

if BACKEND_ARG == "gpu"
    @eval import CUDA
end

using SpinorBEC
using Printf

include(joinpath(@__DIR__, "eu151_params.jl"))

const BACKEND = BACKEND_ARG == "gpu" ? CUDABackend() : CPUBackend()
const SYNC = BACKEND_ARG == "gpu" ? () -> CUDA.synchronize() : () -> nothing
const MS = [20]
const MAX_STEPS = parse(Int, get(ENV, "SBEC_PROBE_MAX_STEPS", "4000"))

function build_cell(; n::Int, enable_ddi::Bool, c1_ratio::Float64=0.05)
    grid = make_grid(GridConfig((n, n, n), (12.0, 12.0, 12.0)))
    atom = AtomSpecies("Eu151", 1.0, 6, EU_a_s_dl, 0.0)
    ip = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio, F=6)
    (;
        grid, atom, interactions=ip,
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        enable_ddi, c_dd=enable_ddi ? EU_c_dd : NaN,
        backend=BACKEND, initial_state=:m_plus_F, verbose=false,
    )
end

println("LBFGS history-depth probe — backend=$BACKEND_ARG, grid=$GRID_N^3, ",
    "threads=$(Threads.nthreads()), ",
    "OPENBLAS_NUM_THREADS=$(get(ENV, "OPENBLAS_NUM_THREADS", "unset"))")
println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
println("driver loaded from: ", first(methods(find_ground_state_lbfgs)).file, ":",
    first(methods(find_ground_state_lbfgs)).line)
println()

# A tolerance both cells reach without stalling — see the line-search probe.
const TOL = 1.0e-6

# Three c1_ratio values, not repeats: `find_ground_state_lbfgs` from
# `:m_plus_F` is DETERMINISTIC, so re-running the same problem returns the same
# iteration count and adds no information. The question is whether the
# iteration-count-vs-m pattern is a property of the method or of one problem,
# and only a different problem can answer that.
for (label, ddi) in (("contact", false), ("+DDI", true)), c1r in (0.03, 0.05, 0.08),
    HP in (Float64, Float32)
    cell = build_cell(; n=GRID_N, enable_ddi=ddi, c1_ratio=c1r)
    find_ground_state_lbfgs(; cell..., n_steps=3, tol=0.0, m_lbfgs=first(MS),
        history_precision=HP)
    SYNC()
    @printf("Eu151 F=6 %d^3 %s c1_ratio=%.2f history=%s, tol=%.0e\n",
        GRID_N, label, c1r, HP, TOL)
    @printf("  %-8s %6s %9s %9s %10s %-20s %s\n",
        "m_lbfgs", "iters", "evals/it", "ms/it", "|grad|", "stop_reason", "total wall")
    for m in MS
        r = nothing
        t = @elapsed (r = find_ground_state_lbfgs(; cell..., n_steps=MAX_STEPS, tol=TOL,
            m_lbfgs=m, history_precision=HP))
        SYNC()
        it = max(r.last_step, 1)
        # Report what came back rather than assuming: a run that returns the
        # bare atomic tuple has taken some path other than the main loop, and
        # `getproperty` would kill the whole table saying only "no such field".
        ev = hasproperty(r, :n_line_search_evals) ? r.n_line_search_evals / it : NaN
        sr = hasproperty(r, :stop_reason) ? string(r.stop_reason) : "keys=$(keys(r))"
        @printf("  %-8d %6d %9.2f %9.1f %10.3e %-20s %8.2fs\n",
            m, r.last_step, ev, 1000t / it, r.grad_norm, sr, t)
        flush(stdout)
    end
    println()
end
