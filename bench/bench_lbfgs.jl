#!/usr/bin/env julia
# L-BFGS ground-state solver benchmark.
#
#   julia --project=. bench/bench_lbfgs.jl [cpu|gpu] [grid_n]
#
# Reports, per cell (Eu151 F=6, D=13, 3D):
#   - end-to-end cost per L-BFGS iteration (slope of wall vs n_steps, so
#     setup / JIT / finalize drop out)
#   - the per-iteration components: energy_gradient!, constraint projection,
#     Sobolev preconditioner, two-loop direction, one line-search energy eval
#
# The components are reconciled against the end-to-end slope; the residual is
# the extra line-search energy evaluations (>=1 per iteration), so the implied
# eval count is printed rather than assumed.

const BACKEND_ARG = length(ARGS) >= 1 ? ARGS[1] : "cpu"
const GRID_ARG = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 0

if BACKEND_ARG == "gpu"
    @eval import CUDA
end

using SpinorBEC
using LinearAlgebra
using Printf

include(joinpath(@__DIR__, "reconcile.jl"))
include(joinpath(@__DIR__, "eu151_params.jl"))

const BACKEND = BACKEND_ARG == "gpu" ? CUDABackend() : CPUBackend()
const SYNC = BACKEND_ARG == "gpu" ? () -> CUDA.synchronize() : () -> nothing

println("LBFGS benchmark — backend=$(BACKEND_ARG), Julia $(VERSION), threads=$(Threads.nthreads())")
println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
println()

# ----------------------------------------------------------------------------
# Cell construction
# ----------------------------------------------------------------------------

function build_cell(; n::Int, enable_ddi::Bool)
    grid = make_grid(GridConfig((n, n, n), (12.0, 12.0, 12.0)))
    atom = AtomSpecies("Eu151", 1.0, 6, EU_a_s_dl, 0.0)
    ip = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=0.05, F=6)
    (;
        grid, atom,
        interactions=ip,
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        enable_ddi, c_dd=enable_ddi ? EU_c_dd : NaN,
        backend=BACKEND,
        # `:m_plus_F`, not `:ferromagnetic` — the latter is not a state the
        # `init_psi` dispatch knows (bench/eu151_setup.jl passes it and would
        # throw too). With p > 0 the Zeeman term prefers m = +F, so this is the
        # aligned, well-conditioned start.
        initial_state=:m_plus_F,
        verbose=false,
    )
end

# ----------------------------------------------------------------------------
# End-to-end: per-iteration slope
# ----------------------------------------------------------------------------

# Wall-clock budget for the long arm of the slope. The original 4-vs-20-step
# form put ~1 s on each arm and differenced two run minima: at that scale the
# estimator is measuring startup and its own noise, and the baseline cells moved
# up to 20 % between jobs. `n_lo` also has to clear `m_lbfgs` — below it the
# two-loop is still filling its history, so the differenced steps cost less than
# a steady-state iteration and the component breakdown cannot close.
const TARGET_SECONDS = parse(Float64, get(ENV, "SBEC_BENCH_SECONDS", "300"))

function iteration_slope(cell; n_lo::Int=25, n_probe::Int=60)
    run(n) = begin
        r = find_ground_state_lbfgs(; cell..., n_steps=n, tol=0.0)
        SYNC()
        r
    end
    run(n_lo)                                   # compile
    # Size the long arm from a SLOPE, not from a single short run. A single
    # `n_lo`-step run averages in the steps before the history reaches
    # `m_lbfgs`, which are cheaper: probing that way underestimated the
    # steady-state iteration by 2x (116 ms vs 245 ms measured), so a "5 minute"
    # point ran for 11.
    t_probe_lo = @elapsed run(n_lo)
    t_probe_hi = @elapsed run(n_probe)
    per_probe = max((t_probe_hi - t_probe_lo) / (n_probe - n_lo), 1.0e-6)
    n_hi = clamp(round(Int, TARGET_SECONDS / per_probe) + n_lo, 4 * n_lo, 500_000)
    t_lo = @elapsed run(n_lo)
    r_hi = nothing
    t_hi = @elapsed (r_hi = run(n_hi))
    # `n_line_search_evals` only exists on revisions that report it; keep the
    # bench file identical across A/B arms by degrading to NaN rather than
    # erroring on the older one.
    ls = hasproperty(r_hi, :n_line_search_evals) ?
         r_hi.n_line_search_evals / max(r_hi.last_step, 1) : NaN
    fails = hasproperty(r_hi, :n_line_search_failures) ?
            r_hi.n_line_search_failures / max(r_hi.last_step, 1) : NaN
    (per_iter=(t_hi - t_lo) / (n_hi - n_lo), n_hi=n_hi, t_hi=t_hi, t_lo=t_lo,
        ls_evals=ls, ls_fail_frac=fails, energy=r_hi.energy,
        grad_norm=r_hi.grad_norm, converged=r_hi.converged)
end

# ----------------------------------------------------------------------------
# Components
# ----------------------------------------------------------------------------

function components(cell)
    # A converged-ish workspace + iterate, so densities/DDI are representative.
    r = find_ground_state_lbfgs(; cell..., n_steps=8, tol=0.0)
    ws = r.workspace
    grid = ws.grid
    F = ws.spin_matrices.system.F
    dV = cell_volume(grid)

    psi = copy(ws.state.psi)
    grad = similar(psi)
    k2 = SpinorBEC._to_device(ws.backend, grid.k_squared)
    α_sob = 1.0 / Float64(maximum(grid.k_squared))

    fill!(grad, zero(eltype(grad)))
    SpinorBEC.energy_gradient!(grad, psi, ws; k_squared_dev=k2)

    t_grad = timed(() -> (SpinorBEC.energy_gradient!(grad, psi, ws; k_squared_dev=k2); SYNC())).t
    t_proj = timed(
        () -> (SpinorBEC._project_constraints!(grad, psi, grid, nothing, F); SYNC())
    ).t
    t_sob = timed(
        () -> (SpinorBEC._sobolev_precondition!(grad, ws, k2, α_sob); SYNC())
    ).t
    t_energy = timed(() -> (total_energy(ws); SYNC())).t

    # Two-loop direction with a full m=20 history.
    m = 20
    s_hist = [similar(psi) for _ in 1:m]
    y_hist = [similar(psi) for _ in 1:m]
    for i in 1:m
        copyto!(s_hist[i], grad)
        s_hist[i] .*= 1.0e-3 * i
        copyto!(y_hist[i], grad)
        y_hist[i] .*= 1.0e-2 / i
    end
    rho_hist = [1.0 / (real(dot(s_hist[i], y_hist[i])) * dV) for i in 1:m]
    t_dir = timed(
        () -> (SpinorBEC._lbfgs_direction(grad, s_hist, y_hist, rho_hist, dV); SYNC())
    ).t

    # Retraction cost (the line search does one per trial, on top of the energy).
    psi_t = similar(psi)
    dirn = copy(grad)
    t_retract = timed(
        () -> begin
            psi_t .= psi .+ 0.5 .* dirn
            psi_t ./= sqrt(sum(abs2, psi_t) * dV)
            SYNC()
        end
    ).t

    (; t_grad, t_proj, t_sob, t_energy, t_dir, t_retract)
end

# ----------------------------------------------------------------------------
# Driver
# ----------------------------------------------------------------------------

ms(x) = @sprintf("%8.3f ms", x * 1e3)

grids = GRID_ARG > 0 ? (GRID_ARG,) : (16, 24)
# `SBEC_BENCH_CELLS` trims the sweep. A question about a CPU reduction does not
# need the DDI cell, and each cell is a full measurement budget.
const CELLS = get(ENV, "SBEC_BENCH_CELLS", "both")
ddi_cases = CELLS == "contact" ? (false,) : CELLS == "ddi" ? (true,) : (false, true)

for n in grids, ddi in ddi_cases
    label = "Eu151 F=6 $(n)³ " * (ddi ? "+DDI" : "contact")
    println("=== $label ===")
    cell = build_cell(; n, enable_ddi=ddi)

    c = components(cell)
    s = iteration_slope(cell)
    per_iter = s.per_iter
    # Print what the estimator actually did, so a point that silently ran for a
    # second instead of the budget cannot be read as a 5-minute measurement.
    @printf("  measured over %d steps in %.1f s (short arm %d steps, %.1f s)\n",
        s.n_hi, s.t_hi, 25, s.t_lo)

    # One gradient (grad + 2 projections + sobolev) + direction + >=1 line-search
    # energy evaluation (retraction + total_energy) per iteration.
    parts = [
        "energy_gradient!" => c.t_grad,
        "project x2" => 2 * c.t_proj,
        "sobolev precond" => c.t_sob,
        "two-loop dir" => c.t_dir,
        "line-search eval x1" => c.t_energy + c.t_retract,
    ]
    println("  per-iteration (slope): ", ms(per_iter))
    for (k, v) in parts
        @printf("    %-22s %s  (%4.1f%%)\n", k, ms(v), 100v / per_iter)
    end
    # Reconcile against the MEASURED number of line-search energy evaluations,
    # not an inferred one. The earlier form solved the residual for the count,
    # which makes the breakdown close by construction and can therefore never
    # report that it does not.
    ls_cost = s.ls_evals * (c.t_energy + c.t_retract)
    @printf("    %-22s %s  (%4.1f%%)  [measured %.2f evals/iter, %.1f%% of steps found no step]\n",
        "line search TOTAL", ms(ls_cost), 100ls_cost / per_iter,
        s.ls_evals, 100 * s.ls_fail_frac)
    # Whether the solve is going anywhere at all. A cost measured on a solve
    # that is not descending is a cost measured on the wrong problem.
    @printf("  end state: E=%.10g  |grad|=%.3e  converged=%s\n",
        s.energy, s.grad_norm, s.converged)
    resid = per_iter - sum(last, parts) - (ls_cost - (c.t_energy + c.t_retract))
    @printf("    %-22s %s  (%4.1f%%)\n", "residual", ms(resid), 100resid / per_iter)
    println()
end
