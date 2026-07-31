#!/usr/bin/env julia
# How much does a USEFUL L-BFGS iteration cost in energy evaluations?
#
#   julia --project=. bench/probe_lbfgs_line_search.jl [cpu|gpu] [grid_n]
#
# `bench/bench_lbfgs.jl` runs with `tol = 0.0` so that `n_steps` is exact for
# its slope estimate. That is the right choice for a slope and the wrong one
# for this question: with an unreachable tolerance most of the measured
# iterations are POST-CONVERGENCE ones, where every line search backtracks its
# full 30 halvings and finds nothing. The 29.4 evals/iteration measured that
# way is dominated by them.
#
# So sweep the tolerance instead. Each row is a complete solve, and
# `n_line_search_evals / last_step` is the mean cost of an iteration that is
# actually making progress at that tolerance. If that number is ~1, the line
# search accepts alpha = 1 and there is nothing to win there. If it is ~5 or
# more, the initial step or the acceptance test is the lever, not any kernel.
#
# `stop_reason` and `floor_limited` say which rows are floor-limited and should
# not be read as the useful regime.

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
const MAX_STEPS = parse(Int, get(ENV, "SBEC_PROBE_MAX_STEPS", "2000"))
const TOLS = [1.0e-4, 1.0e-5, 1.0e-6, 5.0e-7, 1.0e-8]

function build_cell(; n::Int, enable_ddi::Bool)
    grid = make_grid(GridConfig((n, n, n), (12.0, 12.0, 12.0)))
    atom = AtomSpecies("Eu151", 1.0, 6, EU_a_s_dl, 0.0)
    ip = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=0.05, F=6)
    (;
        grid, atom, interactions=ip,
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        enable_ddi, c_dd=enable_ddi ? EU_c_dd : NaN,
        backend=BACKEND, initial_state=:m_plus_F, verbose=false,
    )
end

println("LBFGS line-search probe — backend=$BACKEND_ARG, grid=$GRID_N^3, ",
    "Julia $(VERSION), threads=$(Threads.nthreads()), ",
    "OPENBLAS_NUM_THREADS=$(get(ENV, "OPENBLAS_NUM_THREADS", "unset"))")
println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
println()

for (label, ddi) in (("contact", false), ("+DDI", true))
    cell = build_cell(; n=GRID_N, enable_ddi=ddi)
    find_ground_state_lbfgs(; cell..., n_steps=3, tol=0.0)   # compile
    SYNC()
    @printf("%s %d^3 %s\n", "Eu151 F=6", GRID_N, label)
    @printf("  %-9s %6s %8s %9s %9s %10s %-20s %s\n",
        "tol", "iters", "evals", "evals/it", "fails/it", "|grad|", "stop_reason", "wall")
    for tol in TOLS
        r = nothing
        t = @elapsed (r = find_ground_state_lbfgs(; cell..., n_steps=MAX_STEPS, tol))
        SYNC()
        it = max(r.last_step, 1)
        @printf("  %-9.1e %6d %8d %9.2f %9.2f %10.3e %-20s %6.1fs (%.1f ms/it)\n",
            tol, r.last_step, r.n_line_search_evals,
            r.n_line_search_evals / it, r.n_line_search_failures / it,
            r.grad_norm, string(r.stop_reason), t, 1000t / it)
        flush(stdout)
    end
    println()
end
