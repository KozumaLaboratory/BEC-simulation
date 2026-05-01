# Overnight bench — R32 through R39 on small (laptop-grade) configs.
# Each section saves results to /tmp/bench_*.jld2 + appends to summary.

using SpinorBEC
using JLD2
using Printf
using Dates: now
using LinearAlgebra: norm

const SUMMARY_PATH = "/tmp/bench_overnight_summary.md"
const RESULTS = Dict{String, Any}()

println("=" ^ 70)
println("Overnight bench — R32-R39, $(now())")
println("=" ^ 70)

function _section(f::Function, name::String)
    println()
    println("─" ^ 70)
    println("[$name] starting at $(round(time(); digits=0))")
    println("─" ^ 70)
    flush(stdout)
    t0 = time()
    try
        result = f()
        elapsed = time() - t0
        result_with_time = merge(result, Dict("wall_s" => elapsed, "status" => "ok"))
        RESULTS[name] = result_with_time
        @printf "[%s] DONE in %.1fs\n" name elapsed
        return result_with_time
    catch e
        elapsed = time() - t0
        RESULTS[name] = Dict("status" => "failed", "error" => sprint(showerror, e),
            "wall_s" => elapsed)
        @printf "[%s] FAILED in %.1fs: %s\n" name elapsed sprint(showerror, e)
    finally
        # Save intermediate
        @save "/tmp/bench_overnight_intermediate.jld2" RESULTS
    end
end

# ===== R33 — MFBO Eu phase (F=1, 2-D) =====
_section("R33") do
    F = 1
    atom = AtomSpecies("test", 2.5e-25, F, 50e-10, 60e-10, 6.977e-23)
    function _gs_energy(p::Vector{Float64}; n_pts::Int, n_steps::Int)
        n_z = max(4, (n_pts ÷ 2 ÷ 2) * 2)
        grid = make_grid(GridConfig((n_pts, n_pts, n_z), (8.0, 8.0, 4.0)))
        r = find_ground_state(;
            grid, atom,
            interactions=InteractionParams(20.0, p[1]),
            potential=HarmonicTrap((1.0, 1.0, 2.0)),
            enable_ddi=(p[2] > 0), c_dd=p[2],
            dt=0.005, n_steps,
            tol=1.0e-7, initial_state=:polar, verbose=false,
        )
        Float64(r.energy)
    end
    eval_low(p) = _gs_energy(p; n_pts=10, n_steps=200)
    eval_high(p) = _gs_energy(p; n_pts=20, n_steps=1500)
    bounds = [(-0.5, 0.5), (0.0, 50.0)]

    # Warmup
    eval_low([0.0, 10.0])
    eval_high([0.0, 10.0])
    GC.gc()

    t_l = @elapsed eval_low([0.0, 20.0])
    GC.gc()
    t_h = @elapsed eval_high([0.0, 20.0])
    cost_ratio = t_h / t_l

    GC.gc()
    t_sf = @elapsed sf = bayesian_optimize(eval_high, bounds;
        n_init=4, n_iter=8, minimise=true, seed=42, verbose=false)
    GC.gc()
    t_mf = @elapsed mf = multi_fidelity_optimize_2tier(
        eval_low, eval_high, bounds;
        cost_ratio, n_init_low=10, n_init_high=2, n_iter=10,
        budget_high=3, minimise=true, seed=42, verbose=false)

    Dict(
        "cost_ratio" => cost_ratio,
        "t_low_s" => t_l, "t_high_s" => t_h,
        "sf_best_y" => sf.best_y, "sf_wall_s" => t_sf,
        "mf_best_y" => mf.best_y, "mf_wall_s" => t_mf,
        "speedup" => t_sf / t_mf,
        "sf_high_calls" => 12, "mf_high_calls" => mf.n_evals_high,
        "mf_low_calls" => mf.n_evals_low,
    )
end

# ===== R35 — B-1 boundary trace (F=1, 2-D) =====
_section("R35") do
    F = 1
    atom = AtomSpecies("test", 2.5e-25, F, 50e-10, 60e-10, 6.977e-23)
    grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))

    # Build F closure: c0=20, scan (c1, c_dd_proxy)
    Fboundary = make_phase_diff_eval(grid, atom;
        parameter_setter=θ -> (
            interactions=InteractionParams(20.0, θ[1]),
            potential=HarmonicTrap((1.0, 1.0)),
        ),
        phase_A_init=:m_plus_F,
        phase_B_init=:polar,
        n_steps=200, tol=1.0e-6,
        verbose=false,
    )

    # F=1 polar↔FM transition is at c₁=0. Start there with a vertical tangent.
    θ_init = [0.0, 0.0]
    t_init = [0.0, 1.0]    # try moving in θ₂

    t_trace = @elapsed trace = trace_phase_boundary(Fboundary, θ_init, t_init;
        arc_step=0.05, max_steps=20,
        newton_tol=1.0e-5, finite_diff_h=1.0e-3,
        verbose=false,
    )

    Dict(
        "n_points" => size(trace.points, 1),
        "n_converged" => sum(trace.converged),
        "max_residual" => maximum(trace.residuals),
        "wall_s" => t_trace,
        "first_point" => trace.points[1, :],
        "last_point" => trace.points[end, :],
    )
end

# ===== R36 — Active learning on F=1 phase (synthetic + real) =====
_section("R36") do
    F = 1
    atom = AtomSpecies("test", 2.5e-25, F, 50e-10, 60e-10, 6.977e-23)
    grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
    sm = SpinorBEC.spin_matrices(F)

    # eval_fn: at θ = (c1, ?), compute GS, classify, return scores
    function eval_fn(θ::AbstractVector)
        r = find_ground_state(;
            grid, atom,
            interactions=InteractionParams(20.0, θ[1]),
            potential=HarmonicTrap((1.0, 1.0)),
            dt=0.005, n_steps=150, tol=1.0e-5,
            initial_state=:polar, verbose=false,
        )
        psi = r.workspace.state.psi
        details = SpinorBEC.classify_phase_detailed(psi, F, grid, sm)
        ranking = SpinorBEC.classify_phase_distance(details, F; threshold=0.5)
        (scores=ranking.scores,)
    end

    bounds = [(-1.0, 1.0), (0.0, 1.0)]   # (c1, dummy axis)

    t_al = @elapsed al = active_learn_phase_scan(eval_fn, bounds;
        n_init=4, n_iter=10,
        temperature=0.1, seed=42, verbose=false,
    )

    # Boundary concentration metric: fraction of post-init samples
    # within 0.2 of c1=0 (the polar↔FM transition).
    post_init = al.X_history[(end - 9):end, :]
    on_boundary = sum(abs.(post_init[:, 1]) .< 0.2) / 10

    Dict(
        "n_evals" => length(al.y_history),
        "best_entropy" => al.best_y,
        "best_p" => al.best_p,
        "boundary_concentration" => on_boundary,
        "wall_s" => t_al,
    )
end

# ===== R39 — BdG along R35 boundary curve =====
_section("R39") do
    haskey(RESULTS, "R35") && RESULTS["R35"]["status"] == "ok" ||
        error("R35 result missing — cannot run R39")

    F = 1
    atom = AtomSpecies("test", 2.5e-25, F, 50e-10, 60e-10, 6.977e-23)
    grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))

    # Reconstruct trace points (we saved last_point; for R39 use a 3-point synthetic curve)
    points = Float64[
        -0.1   0.0
         0.0   0.0
         0.1   0.0
    ]

    t_bdg = @elapsed samples = bogoliubov_along_boundary_curve(
        points,
        θ -> (interactions=InteractionParams(20.0, θ[1]),
            potential=HarmonicTrap((1.0, 1.0))),
        grid, atom;
        phase_init=:m_plus_F,
        k_max=5.0, n_k=30, n_steps=100, tol=1.0e-5,
        verbose=false,
    )

    Dict(
        "n_samples" => length(samples),
        "max_growth_rates" => [s.bdg.max_growth_rate for s in samples],
        "n0_values" => [s.n0 for s in samples],
        "wall_s" => t_bdg,
    )
end

# ===== R32 — Sobolev sweep (F=1 contact-only, 5 alphas) =====
_section("R32") do
    F = 1
    atom = AtomSpecies("test", 2.5e-25, F, 50e-10, 60e-10, 6.977e-23)

    function bench_alpha(alpha::Float64)
        grid = make_grid(GridConfig((10, 10, 6), (6.0, 6.0, 4.0)))
        GC.gc()
        t = @elapsed r = find_ground_state_lbfgs(;
            grid, atom,
            interactions=InteractionParams(50.0, 0.0),
            potential=HarmonicTrap((1.0, 1.0, 1.5)),
            n_steps=300, tol=1.0e-7,
            initial_state=:m_plus_F,
            sobolev_alpha=alpha,
            verbose=false,
        )
        (energy=r.energy, last_step=r.last_step, conv=r.converged, wall=t)
    end

    # Warmup
    bench_alpha(0.0)

    sweep_results = Dict{String, Any}()
    for α in (0.0, 0.05, 0.1, 0.2, 0.5)
        r = bench_alpha(α)
        sweep_results["alpha_$α"] = Dict(
            "energy" => r.energy,
            "last_step" => r.last_step,
            "converged" => r.conv,
            "wall_s" => r.wall,
        )
    end
    sweep_results
end

# Final summary
println()
println("=" ^ 70)
println("Bench summary")
println("=" ^ 70)

@save "/tmp/bench_overnight_results.jld2" RESULTS

# Markdown summary
open(SUMMARY_PATH, "w") do io
    println(io, "# Overnight bench results — $(now())")
    println(io)
    for (name, r) in sort(collect(RESULTS); by=first)
        println(io, "## $name")
        println(io)
        if get(r, "status", "") == "failed"
            println(io, "**FAILED** in $(round(get(r, "wall_s", 0); digits=1))s")
            println(io)
            println(io, "```")
            println(io, get(r, "error", ""))
            println(io, "```")
        else
            for (k, v) in sort(collect(r); by=first)
                k == "status" && continue
                println(io, "- `$k` = `$v`")
            end
        end
        println(io)
    end
end

println("Summary written: $SUMMARY_PATH")
println("Results: /tmp/bench_overnight_results.jld2")
flush(stdout)
