#!/usr/bin/env julia
# What does each pass of an L-BFGS iteration actually cost?
#
#   julia --project=. bench/probe_lbfgs_pass_costs.jl [cpu|gpu] [grid_n]
#
# The line search is now measured at 1.08-1.25 energy evaluations per useful
# iteration, so a CPU iteration is `n_ls` energy passes plus one gradient pass:
#
#   _line_search_energy_decrease -> total_energy(ws)              x n_ls
#   _lbfgs_grad!(E_known=...)    -> gradient_only!                x 1
#
# Fusing the accepted trial into one energy+gradient pass only pays if a fused
# pass costs less than the two separate ones. On the CPU `energy_gradient!`
# runs the registry TWICE by construction (gradient, then energy), so today it
# does not — the saving would have to come from deriving each term's energy
# from the `⟨ψ, H_term ψ⟩` the gradient traversal already forms, which is what
# the GPU path does. That is a real change to the term protocol, so size it
# before building it.
#
# Every point is timed for at least TARGET_SECONDS of repeats, not once: the
# quantities here are single-digit milliseconds and a one-shot measurement at
# that scale reads FFT planning and allocation, not the pass.
#
# The parts are reconciled against a measured iteration. If they do not close,
# the breakdown is wrong and nothing below it should be quoted.

const BACKEND_ARG = length(ARGS) >= 1 ? ARGS[1] : "cpu"
const GRID_N = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 24

if BACKEND_ARG == "gpu"
    @eval import CUDA
end

using SpinorBEC
using SpinorBEC: gradient_only!, energy_gradient!, total_energy, _lbfgs_direction,
    _realdot, _project_constraints!
using Printf

include(joinpath(@__DIR__, "eu151_params.jl"))

const BACKEND = BACKEND_ARG == "gpu" ? CUDABackend() : CPUBackend()
const SYNC = BACKEND_ARG == "gpu" ? () -> CUDA.synchronize() : () -> nothing
const TARGET = parse(Float64, get(ENV, "SBEC_PROBE_SECONDS", "3.0"))

"Median ms per call, over as many repeats as fit in TARGET seconds (min 5)."
function timed(f)
    f(); SYNC()                       # compile
    t1 = @elapsed (f(); SYNC())
    n = clamp(round(Int, TARGET / max(t1, 1.0e-6)), 5, 20_000)
    ts = Float64[]
    for _ in 1:n
        push!(ts, @elapsed (f(); SYNC()))
    end
    sort!(ts)
    (med=1000 * ts[(length(ts) + 1) ÷ 2], min=1000 * ts[1], n=n)
end

function build(; n::Int, enable_ddi::Bool)
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

println("LBFGS pass-cost probe — backend=$BACKEND_ARG, grid=$GRID_N^3, ",
    "threads=$(Threads.nthreads()), ",
    "OPENBLAS_NUM_THREADS=$(get(ENV, "OPENBLAS_NUM_THREADS", "unset"))")
println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
println("target per point: $(TARGET)s of repeats")
println()

for (label, ddi) in (("contact", false), ("+DDI", true))
    cell = build(; n=GRID_N, enable_ddi=ddi)
    # A converged-ish iterate, so the passes see production-shaped data rather
    # than the m=+F seed.
    r = find_ground_state_lbfgs(; cell..., n_steps=40, tol=1.0e-6, m_lbfgs=20)
    ws = r.workspace
    psi = copy(ws.state.psi)
    g = similar(psi)
    k2 = ws.grid.k_squared
    dV = cell_volume(ws.grid)

    t_E = timed(() -> total_energy(ws))
    t_G = timed(() -> gradient_only!(g, psi, ws))
    t_EG = timed(() -> energy_gradient!(g, psi, ws; k_squared_dev=k2))

    # The two-loop, at the default history depth, with a filled history.
    hist = r.lbfgs_history
    t_2L = if hist !== nothing && !isempty(hist[3])
        timed(() -> _lbfgs_direction(g, hist[1], hist[2], hist[3], dV))
    else
        (med=NaN, min=NaN, n=0)
    end
    t_P = timed(() -> _project_constraints!(g, psi, ws.grid, nothing, 6))

    @printf("Eu151 F=6 %d^3 %s   (history depth %d)\n", GRID_N, label,
        hist === nothing ? 0 : length(hist[3]))
    for (nm, t) in (("total_energy", t_E), ("gradient_only!", t_G),
        ("energy_gradient!", t_EG), ("two-loop", t_2L),
        ("project_constraints", t_P))
        @printf("  %-22s %8.3f ms   (min %7.3f, n=%d)\n", nm, t.med, t.min, t.n)
    end

    # Does a fused pass beat the two separate ones it would replace?
    @printf("  ---- fused vs separate: energy_gradient! %.3f  vs  E+G %.3f  => %s\n",
        t_EG.med, t_E.med + t_G.med,
        t_EG.med < t_E.med + t_G.med ? "fusing saves $(round(t_E.med + t_G.med - t_EG.med; digits=2)) ms" :
        "NO saving as built")

    # Reconcile against a measured iteration. n_ls energy passes + 1 gradient
    # + two-loop + projection, against the slope of wall vs n_steps.
    n_lo, n_hi = 25, 125
    t_lo = @elapsed find_ground_state_lbfgs(; cell..., n_steps=n_lo, tol=0.0, m_lbfgs=20)
    r_hi = nothing
    t_hi = @elapsed (r_hi = find_ground_state_lbfgs(; cell..., n_steps=n_hi, tol=0.0, m_lbfgs=20))
    per_iter = 1000 * (t_hi - t_lo) / (n_hi - n_lo)
    n_ls = r_hi.n_line_search_evals / max(r_hi.last_step, 1)
    parts = n_ls * t_E.med + t_G.med + (isnan(t_2L.med) ? 0.0 : t_2L.med) + t_P.med
    @printf("  ---- reconcile: measured %.2f ms/it  vs parts %.2f ms (n_ls=%.2f) => %.0f%%\n",
        per_iter, parts, n_ls, 100 * parts / per_iter)
    if !(0.7 < parts / per_iter < 1.15)
        @printf("  !! BREAKDOWN DOES NOT CLOSE — do not quote the rows above for %s\n", label)
    end
    println()
    flush(stdout)
end
