# Unified integrator benchmark — all schemes, order + cost + drift on same footing.
#
# Two test problems:
#
#   Problem A (FG-eligible): Rb87 F=1, c0=50, c1=0, no DDI
#     → ALL schemes can run, including Force-Gradient / Thalhammer
#
#   Problem B (lab path):    Rb87 F=1, c0=50, c1=1, c_dd=1
#     → FG/Thalhammer skipped (diagonal-only constraint), Y4-mid only path to order 4
#
# Schemes (matrix):
#                          Plain   Mid     Trap    FG/Thalhammer
#   Strang        (2)        ✓      ✓        ✓         —
#   Yoshida-4     (4)        ✓      ✓        ✓         —
#   Yoshida-6     (6)        ✓      ✓        —         —
#   MPS-4         (≤1)       ✓      ✓        —         —
#   Force-Grad    (3-4)      —      —        —         ✓ (A only)
#
# Measurements per (scheme, dt):
#   - global error vs reference (split_step! at dt=2e-5)
#   - convergence order (log2 ratio across dt)
#   - wall-clock per step (CPU)
#   - norm drift
#
# Output:
#   - Per-problem comparison table
#   - Cost-per-accuracy Pareto data printed for plotting
#
# Run: julia --project=. scripts/bench/unified_integrator_bench.jl

using SpinorBEC
using Printf

const N = 16
const T_FINAL = 0.04
const ATOM = Rb87

function _make_grid()
    make_grid(GridConfig((N, N, N), (8.0, 8.0, 8.0)))
end

function _seed_psi!(ws)
    psi = ws.state.psi
    D = size(psi, 4)
    grid = ws.grid
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        g = exp(-(x * x + y * y + z * z) / 2)
        for c in 1:D
            psi[I, c] = g * cis(0.1 * c)
        end
    end
    SpinorBEC._normalize_psi!(psi, ws.grid, D, 3)
    nothing
end

function _build_ws(dt::Float64; c1::Float64, c_dd::Float64, enable_ddi::Bool=false)
    grid = _make_grid()
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=ATOM,
        interactions=InteractionParams(50.0, c1),
        zeeman=ZeemanParams(0.5, 0.1),
        potential=HarmonicTrap(1.0, 1.0, 1.0),
        sim_params=sp,
        enable_ddi=enable_ddi, c_dd=c_dd,
        backend=CPUBackend(),
    )
    _seed_psi!(ws)
    ws
end

# --- Schemes (drop-in pattern from Phase 2a) ---

const _Y4_W1 = 1.0 / (2.0 - 2.0^(1.0/3.0))
const _Y4_W0 = 1.0 - 2.0 * _Y4_W1
const _Y4_WM = (_Y4_W1 + _Y4_W0) / 2.0

function _y4_step!(ws::SpinorBEC.Workspace{N}, V_half!::Function) where {N}
    dt = ws.sim_params.dt
    n_comp = ws.spin_matrices.system.n_components
    omega = ws.sim_params.rotating_frame_omega
    t_base = ws.state.t
    w1 = _Y4_W1; w0 = _Y4_W0; wm = _Y4_WM
    V_half!(ws, w1 * dt / 2, n_comp, N, false;
        t_eval=t_base + w1 * dt / 4, t_start=t_base)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    t_v2 = t_base + w1 * dt / 2
    V_half!(ws, wm * dt, n_comp, N, false; t_eval=t_v2 + wm * dt / 2, t_start=t_v2)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w0 * dt / 2, false, ws.coriolis_cache)
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w0 * dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w0 * dt / 2, false, ws.coriolis_cache)
    t_v3 = t_base + w1 * dt / 2 + wm * dt
    V_half!(ws, wm * dt, n_comp, N, false; t_eval=t_v3 + wm * dt / 2, t_start=t_v3)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    V_half!(ws, w1 * dt / 2, n_comp, N, false;
        t_eval=t_base + dt - w1 * dt / 4, t_start=t_base + dt - w1 * dt / 2)
    ws.state.t += dt
    ws.state.step += 1
    nothing
end

# --- Scheme dispatch ---

function evolve!(label::String, ws, n_steps::Int; ws_half=nothing)
    if label == "Strang"
        for _ in 1:n_steps; SpinorBEC.split_step!(ws); end
    elseif label == "Strang-mid"
        for _ in 1:n_steps; SpinorBEC.split_step_midpoint!(ws); end
    elseif label == "Y4-plain"
        for _ in 1:n_steps; _y4_step!(ws, SpinorBEC._half_potential_step!); end
    elseif label == "Y4-mid"
        for _ in 1:n_steps; _y4_step!(ws, SpinorBEC._half_potential_step_midpoint!); end
    elseif label == "MPS-4-plain"
        psi_in = similar(ws.state.psi)
        for _ in 1:n_steps
            copyto!(psi_in, ws.state.psi)
            SpinorBEC.split_step!(ws)
            psi_h = copy(ws.state.psi)
            copyto!(ws.state.psi, psi_in)
            copyto!(ws_half.state.psi, psi_in)
            SpinorBEC.split_step!(ws_half)
            SpinorBEC.split_step!(ws_half)
            @. ws.state.psi = (4/3) * ws_half.state.psi - (1/3) * psi_h
        end
    elseif label == "MPS-4-mid"
        psi_in = similar(ws.state.psi)
        for _ in 1:n_steps
            copyto!(psi_in, ws.state.psi)
            SpinorBEC.split_step_midpoint!(ws)
            psi_h = copy(ws.state.psi)
            copyto!(ws.state.psi, psi_in)
            copyto!(ws_half.state.psi, psi_in)
            SpinorBEC.split_step_midpoint!(ws_half)
            SpinorBEC.split_step_midpoint!(ws_half)
            @. ws.state.psi = (4/3) * ws_half.state.psi - (1/3) * psi_h
        end
    elseif label == "Force-Gradient"
        for _ in 1:n_steps; SpinorBEC.split_step_forcegrad!(ws); end
    elseif label == "Thalhammer"
        for _ in 1:n_steps; SpinorBEC.split_step_thalhammer!(ws); end
    else
        error("unknown scheme $label")
    end
end

function _bench_run(label::String, dt::Float64; c1, c_dd, enable_ddi)
    n_steps = Int(round(T_FINAL / dt))
    ws = _build_ws(dt; c1, c_dd, enable_ddi)
    ws_half = nothing
    if occursin("MPS", label)
        ws_half = _build_ws(dt / 2; c1, c_dd, enable_ddi)
    end
    # Warmup (JIT)
    evolve!(label, _build_ws(dt; c1, c_dd, enable_ddi), 1;
        ws_half=(occursin("MPS", label) ? _build_ws(dt / 2; c1, c_dd, enable_ddi) : nothing))
    # Timed run
    t_start = time()
    evolve!(label, ws, n_steps; ws_half=ws_half)
    elapsed = time() - t_start
    (psi=ws.state.psi, wall=elapsed, per_step=elapsed / n_steps)
end

function _problem_table(label::String, c1::Float64, c_dd::Float64, enable_ddi::Bool,
                        schemes::Vector{String}, dts::Vector{Float64})
    @printf("\n%s\n", "═"^85)
    @printf("Problem %s: c0=50, c1=%.1f, c_dd=%.1f, DDI=%s, T=%.3f, %d³ Rb87 F=1\n",
        label, c1, c_dd, enable_ddi, T_FINAL, N)
    @printf("%s\n", "═"^85)

    # Reference
    @printf("Building reference (split_step! @ dt=2e-5)...\n")
    ws_ref = _build_ws(2e-5; c1, c_dd, enable_ddi)
    t0 = time()
    for _ in 1:Int(round(T_FINAL / 2e-5))
        SpinorBEC.split_step!(ws_ref)
    end
    @printf("  ref wall = %.1fs, ‖ψ_ref‖ = %.10f\n", time() - t0, sqrt(sum(abs2, ws_ref.state.psi)))
    psi_ref = copy(ws_ref.state.psi)

    @printf("\n%-18s  %-11s  %-11s  %-11s  %-6s %-6s  %-9s  %-12s\n",
        "scheme", "err@h₁", "err@h₂", "err@h₃", "o12", "o23", "ms/step", "cost·err@h₂")
    results = Dict{String, NamedTuple}()
    for scheme in schemes
        try
            errs = Float64[]
            per_steps = Float64[]
            for h in dts
                r = _bench_run(scheme, h; c1, c_dd, enable_ddi)
                push!(errs, sqrt(sum(abs2, r.psi - psi_ref)))
                push!(per_steps, r.per_step)
            end
            o12 = log2(errs[1] / errs[2])
            o23 = log2(errs[2] / errs[3])
            cost_err = per_steps[2] * errs[2]  # Pareto metric: ms × err
            results[scheme] = (errs=errs, per_steps=per_steps, o12=o12, o23=o23, cost_err=cost_err)
            @printf("%-18s  %-11.3e  %-11.3e  %-11.3e  %-6.2f %-6.2f  %-9.3f  %-12.3e\n",
                scheme, errs[1], errs[2], errs[3], o12, o23, 1000 * per_steps[2], cost_err)
        catch e
            @printf("%-18s  [SKIP: %s]\n", scheme, sprint(showerror, e)[1:min(end, 60)])
            results[scheme] = (errs=Float64[NaN, NaN, NaN], per_steps=Float64[NaN], o12=NaN, o23=NaN, cost_err=NaN)
        end
    end
    return results
end

# Schemes
const SCHEMES_FG = ["Strang", "Strang-mid", "Y4-plain", "Y4-mid",
                    "MPS-4-plain", "MPS-4-mid", "Force-Gradient", "Thalhammer"]
const SCHEMES_LAB = ["Strang", "Strang-mid", "Y4-plain", "Y4-mid", "MPS-4-plain", "MPS-4-mid"]

# dt sweep
const DTS = [4e-3, 2e-3, 1e-3]

@printf("Unified integrator benchmark — Rb87 F=1, %d³, T=%.3f, ref dt=2e-5\n", N, T_FINAL)
@printf("dt sweep: %s\n", DTS)

results_A = _problem_table("A (FG-eligible)", 0.0, 0.0, false, SCHEMES_FG, DTS)
results_B = _problem_table("B (lab path)",    1.0, 1.0, true,  SCHEMES_LAB, DTS)

# Final Pareto summary (cost-per-accuracy)
@printf("\n%s\n", "═"^85)
@printf("=== Pareto: cost (ms/step) × err@h₂ — lower is better ===\n")
@printf("%s\n", "═"^85)
@printf("Problem A (FG-eligible):\n")
sorted_A = sort(collect(results_A); by = kv -> kv[2].cost_err)
for (lbl, r) in sorted_A
    isnan(r.cost_err) && continue
    @printf("  %-18s  cost·err = %-10.3e  (%6.2f ms/step × %8.3e err)\n",
        lbl, r.cost_err, 1000 * r.per_steps[2], r.errs[2])
end
@printf("\nProblem B (lab path):\n")
sorted_B = sort(collect(results_B); by = kv -> kv[2].cost_err)
for (lbl, r) in sorted_B
    isnan(r.cost_err) && continue
    @printf("  %-18s  cost·err = %-10.3e  (%6.2f ms/step × %8.3e err)\n",
        lbl, r.cost_err, 1000 * r.per_steps[2], r.errs[2])
end

@printf("\n--- Verdict (matches Ch.3 §3.8 narrative) ---\n")
y4mid_A = results_A["Y4-mid"]
y4mid_B = results_B["Y4-mid"]
fg_A = results_A["Force-Gradient"]
@printf("Y4-mid (Problem A): order = %.2f, err = %.3e at dt=2e-3\n", y4mid_A.o12, y4mid_A.errs[2])
@printf("Y4-mid (Problem B): order = %.2f, err = %.3e at dt=2e-3  ← lab path practical optimum\n",
    y4mid_B.o12, y4mid_B.errs[2])
@printf("Force-Gradient (Problem A): order = %.2f, err = %.3e at dt=2e-3\n",
    fg_A.o12, fg_A.errs[2])
@printf("Force-Gradient eligible? Problem B requires c1≠0 + DDI → DIAGONAL-ONLY violated → SKIPPED\n")
