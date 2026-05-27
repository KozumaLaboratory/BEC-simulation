# A3 — Adaptive timestep control for Y4-midpoint via Hairer-Wanner defect
# estimator + Söderlind PI step-size controller.
#
# Master plan reference: `docs/design/integrator_architecture_completion_plan.md` §A3
# Design doc: `docs/design/integrator_A3_adaptive_control_design.md`
#
# Implementation choices (per design doc §3):
#   - Defect estimator: ψ_full = S(dt) ψ, ψ_half = S(dt/2)² ψ.
#       defect = ‖ψ_full - ψ_half‖.
#   - Step controller: PI form
#       dt_{n+1} = dt_n · safety · (tol/defect)^{1/(p+1)} · (defect_{n-1}/defect_n)^{1/(p+1)}
#     with α = β = 1/(p+1), p = 4 for Y4-mid.
#   - I-only (β=0) on the first step (no defect_{n-1} yet).
#
# Bench-only: this file does not modify src/. Production integration
# requires either Workspace.sim_params mutability or a step!-takes-dt
# refactor (design doc §3.1 "Caveat"); the dt-as-argument pattern below
# is the bench-side resolution.
#
# Run: julia --project=. scripts/bench/track_a3_adaptive_y4mid.jl

using SpinorBEC
using LinearAlgebra
using Printf

const N = 16
const T_FINAL = 0.04
const ATOM = Rb87

# Phase 2a parameters (lab path)
const C0_BENCH = 50.0
const C1_BENCH = 1.0
const C_DD_BENCH = 1.0
const P_ZEEMAN = 0.5
const Q_ZEEMAN = 0.1

const _Y4_W1 = 1.0 / (2.0 - 2.0^(1.0 / 3.0))
const _Y4_W0 = 1.0 - 2.0 * _Y4_W1

function _make_grid()
    make_grid(GridConfig((N, N, N), (8.0, 8.0, 8.0)))
end

function _seed_psi!(ws)
    psi = ws.state.psi
    D = size(psi, 4)
    grid = ws.grid
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        g = exp(-(x*x + y*y + z*z) / 2)
        for c in 1:D
            psi[I, c] = g * cis(0.1 * c)
        end
    end
    SpinorBEC._normalize_psi!(psi, ws.grid, D, 3)
    nothing
end

function _build_ws(dt::Float64)
    grid = _make_grid()
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=ATOM,
        interactions=InteractionParams(C0_BENCH, C1_BENCH),
        zeeman=ZeemanParams(P_ZEEMAN, Q_ZEEMAN),
        potential=HarmonicTrap(1.0, 1.0, 1.0),
        sim_params=sp,
        enable_ddi=true, c_dd=C_DD_BENCH,
        backend=CPUBackend(),
    )
    _seed_psi!(ws)
    ws
end

# ----- Inline midpoint Strang (same kernel as A2.2 bench) -----
function inline_strang_mid!(ws::SpinorBEC.Workspace{NN}, dt::Float64, t_base::Float64) where {NN}
    n_comp = ws.spin_matrices.system.n_components
    omega = ws.sim_params.rotating_frame_omega
    V_half! = SpinorBEC._half_potential_step_midpoint!

    V_half!(ws, dt / 2, n_comp, NN, false;
        t_eval=t_base + dt / 4, t_start=t_base)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, false, ws.coriolis_cache)
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, false, ws.coriolis_cache)
    V_half!(ws, dt / 2, n_comp, NN, false;
        t_eval=t_base + 3 * dt / 4, t_start=t_base + dt / 2)
    nothing
end

# ----- Y4-mid step with explicit dt argument (dt-parametric) -----
function y4_mid_step!(ws::SpinorBEC.Workspace{NN}, dt::Float64, t_base::Float64) where {NN}
    w1 = _Y4_W1;
    w0 = _Y4_W0
    inline_strang_mid!(ws, w1 * dt, t_base)
    inline_strang_mid!(ws, w0 * dt, t_base + w1 * dt)
    inline_strang_mid!(ws, w1 * dt, t_base + (w1 + w0) * dt)
    nothing
end

# ----- Fixed-dt run: y4_mid loop -----
function fixed_y4_run(dt::Float64)
    n_steps = Int(round(T_FINAL / dt))
    actual_dt = T_FINAL / n_steps
    ws = _build_ws(actual_dt)
    t = 0.0
    t_start = time()
    for _ in 1:n_steps
        y4_mid_step!(ws, actual_dt, t)
        t += actual_dt
    end
    wall = time() - t_start
    (ws.state.psi, wall, n_steps)
end

# ===== Adaptive step with defect estimator + PI controller =====
"""
Single adaptive Y4-mid step with defect-based error estimation and
Söderlind PI step-size update.

Inputs:
  ws        : Workspace at current state ψ_n, time t_n.
  dt_try    : Trial dt.
  t_curr    : Current physical time.
  defect_prev : Previous accepted defect (NaN on first step → I-only).
  tol_abs, tol_rel, safety, p, max_factor, min_factor, max_rejects

Returns: (dt_used, dt_new, defect, accepted_bool, n_rejects)

`dt_used` is the dt actually accepted for this step (may be smaller
than dt_try if rejections happened). `dt_new` is the proposed dt for
the next step. `defect` is the measured local error.
"""
function adaptive_y4_step!(
    ws::SpinorBEC.Workspace{NN}, dt_try::Float64, t_curr::Float64,
    defect_prev::Float64;
    tol_abs::Float64=1e-9, tol_rel::Float64=1e-7,
    safety::Float64=0.9, p::Int=4,
    max_factor::Float64=5.0, min_factor::Float64=0.2,
    max_rejects::Int=8,
    pi_alpha::Float64=0.7 / p, pi_beta::Float64=-0.4 / p,
    psi_backup, psi_full, psi_half) where {NN}

    # Söderlind PI3.4 controller: α=0.7/p, β=-0.4/p (β NEGATIVE).
    # Negative β dampens the trend amplification of basic α=β=1/(p+1)
    # which causes limit-cycle oscillations at loose tolerance.
    α = pi_alpha
    β = pi_beta
    n_rejects = 0
    dt = dt_try

    while n_rejects ≤ max_rejects
        # Save state at entry
        psi_backup .= ws.state.psi

        # Full step
        y4_mid_step!(ws, dt, t_curr)
        psi_full .= ws.state.psi

        # Restore and do two half-steps
        ws.state.psi .= psi_backup
        y4_mid_step!(ws, dt / 2, t_curr)
        y4_mid_step!(ws, dt / 2, t_curr + dt / 2)
        psi_half .= ws.state.psi

        # Defect from Richardson
        defect = sqrt(sum(abs2, psi_full .- psi_half))
        normψ = sqrt(sum(abs2, psi_half))
        tol = tol_abs + tol_rel * normψ

        if defect ≤ tol
            # Accept the more-accurate half-step result
            # (Richardson extrapolation could give one more order but
            # we stay conservative here.)
            # ws.state.psi is already psi_half from the two-half-step

            # PI step-size update
            if isnan(defect_prev) || defect_prev == 0.0
                # I-only on first accepted step
                factor = safety * (tol / defect)^α
            else
                factor = safety * (tol / defect)^α * (defect_prev / defect)^β
            end
            factor = clamp(factor, min_factor, max_factor)
            dt_new = dt * factor
            return (dt_used=dt, dt_new=dt_new, defect=defect,
                accepted=true, n_rejects=n_rejects)
        else
            # Reject: restore and shrink dt
            ws.state.psi .= psi_backup
            factor = clamp(safety * (tol / defect)^α, min_factor, 0.5)
            dt *= factor
            n_rejects += 1
        end
    end
    error("adaptive_y4_step!: too many rejections at dt=$dt")
end

# ----- Adaptive run: outer loop, returns trajectory of (t, dt, defect) -----
function adaptive_y4_run(; dt_init::Float64=4e-3,
    tol_abs::Float64=1e-9, tol_rel::Float64=1e-7,
    safety::Float64=0.9)
    ws = _build_ws(dt_init)
    psi_backup = similar(ws.state.psi)
    psi_full = similar(ws.state.psi)
    psi_half = similar(ws.state.psi)
    t = 0.0
    dt = dt_init
    defect_prev = NaN
    n_accept = 0
    n_reject = 0
    dt_history = Float64[]
    defect_history = Float64[]
    t_history = Float64[]

    t_start = time()
    while t < T_FINAL - 1e-12
        dt_try = min(dt, T_FINAL - t)
        result = adaptive_y4_step!(ws, dt_try, t, defect_prev;
            tol_abs, tol_rel, safety,
            psi_backup, psi_full, psi_half)
        t += result.dt_used
        push!(t_history, t)
        push!(dt_history, result.dt_used)
        push!(defect_history, result.defect)
        n_accept += 1
        n_reject += result.n_rejects
        dt = result.dt_new
        defect_prev = result.defect
    end
    wall = time() - t_start
    (ws.state.psi, wall, n_accept, n_reject, t_history, dt_history, defect_history)
end

# ===== Test 1: smooth Phase 2a (verify correctness) =====
@printf("=== A3: adaptive Y4-mid on Phase 2a (smooth dynamics) ===\n")
@printf("Problem: F=1 Rb87, N=%d³, c₀=%.0f, c₁=%.1f, c_dd=%.1f, T=%.3f\n",
    N, C0_BENCH, C1_BENCH, C_DD_BENCH, T_FINAL)
@printf("Reference: Y6-mid at dt=1e-5 (from A2.2)\n\n")

# Reference (Y6-mid) — reuse a small adapter
function _build_ws_y6(dt::Float64)
    _build_ws(dt)  # same workspace; only stepper changes
end

const _Y6_W1 = -1.17767998417887
const _Y6_W2 = +0.235573213359357
const _Y6_W3 = +0.784513610477560
const _Y6_W0 = 1.0 - 2.0 * (_Y6_W1 + _Y6_W2 + _Y6_W3)

function y6_mid_step!(ws::SpinorBEC.Workspace{NN}, dt::Float64, t_base::Float64) where {NN}
    weights = (_Y6_W3, _Y6_W2, _Y6_W1, _Y6_W0, _Y6_W1, _Y6_W2, _Y6_W3)
    t_cur = 0.0
    for w in weights
        inline_strang_mid!(ws, w * dt, t_base + t_cur)
        t_cur += w * dt
    end
    nothing
end

function build_y6_reference(ref_dt::Float64)
    n_ref = Int(round(T_FINAL / ref_dt))
    actual = T_FINAL / n_ref
    ws_ref = _build_ws(actual)
    t = 0.0
    for _ in 1:n_ref
        y6_mid_step!(ws_ref, actual, t)
        t += actual
    end
    copy(ws_ref.state.psi)
end

@printf("Building Y6-mid reference at dt=1e-5... ")
flush(stdout)
t1 = time()
psi_ref = build_y6_reference(1.0e-5)
@printf("done (%.1fs)\n\n", time() - t1)

# Fixed-dt baseline
@printf("── Fixed-dt Y4-mid baseline ──\n")
@printf("%-12s %-14s %-14s %-12s %-12s\n",
    "dt", "err vs ref", "wall", "n_steps", "err/wall")
for dt in [4e-3, 2e-3, 1e-3, 5e-4, 2.5e-4]
    psi, wall, n_steps = fixed_y4_run(dt)
    err = sqrt(sum(abs2, psi .- psi_ref))
    @printf("%-12.1e %-14.3e %-14.2fs %-12d %-12.3e\n",
        dt, err, wall, n_steps, err / wall)
end

# Adaptive at several tolerances
@printf("\n── Adaptive Y4-mid (defect + Söderlind PI) ──\n")
@printf("%-10s %-12s %-12s %-14s %-12s %-12s %-12s %-12s\n",
    "tol_rel", "wall", "n_accept", "n_reject", "dt_min", "dt_max", "dt_mean", "err vs ref")

results = Dict{Float64, NamedTuple}()
for tol_rel in [1e-5, 1e-7, 1e-9]
    tol_abs = tol_rel
    psi_adap, wall, n_acc, n_rej, t_hist, dt_hist, def_hist = adaptive_y4_run(;
        dt_init=4e-3, tol_abs, tol_rel
    )
    err = sqrt(sum(abs2, psi_adap .- psi_ref))
    results[tol_rel] = (
        wall=wall, n_acc=n_acc, n_rej=n_rej,
        dt_min=minimum(dt_hist), dt_max=maximum(dt_hist),
        dt_mean=sum(dt_hist) / length(dt_hist),
        err=err, t_hist=t_hist, dt_hist=dt_hist, def_hist=def_hist,
    )
    r = results[tol_rel]
    @printf("%-10.0e %-12.2f %-12d %-14d %-12.3e %-12.3e %-12.3e %-12.3e\n",
        tol_rel, r.wall, r.n_acc, r.n_rej, r.dt_min, r.dt_max, r.dt_mean, r.err)
end

# Order test for adaptive: tol → 0 should give err → 0 with effective order 4
@printf("\n── Adaptive convergence (tol_rel → 0) ──\n")
@printf("%-10s %-12s %-12s %-12s\n", "tol_rel", "err", "err/tol", "wall")
for tol_rel in [1e-5, 1e-7, 1e-9]
    r = results[tol_rel]
    @printf("%-10.0e %-12.3e %-12.3e %-12.2fs\n",
        tol_rel, r.err, r.err / tol_rel, r.wall)
end

# Acceptance check
@printf("\n── Acceptance per design doc §5 ──\n")
# Find fixed-dt cost reaching err matching adaptive at tol=1e-7
target_err = results[1e-7].err
adapt_wall = results[1e-7].wall

function find_cheapest_fixed_dt(target_err::Float64, ref)
    best_wall = Inf
    best_dt = NaN
    for dt in [4e-3, 2e-3, 1e-3, 5e-4, 2.5e-4]
        psi, wall, _ = fixed_y4_run(dt)
        err = sqrt(sum(abs2, psi .- ref))
        if err <= target_err && wall < best_wall
            best_wall = wall
            best_dt = dt
        end
    end
    (best_wall, best_dt)
end

fixed_wall_match, matched_dt = find_cheapest_fixed_dt(target_err, psi_ref)

@printf("Adaptive tol=1e-7: err=%.2e wall=%.2fs n_acc=%d\n",
    target_err, adapt_wall, results[1e-7].n_acc)
if isfinite(fixed_wall_match)
    @printf("Cheapest fixed Y4-mid reaching err ≤ %.2e: dt=%.1e wall=%.2fs\n",
        target_err, matched_dt, fixed_wall_match)
    ratio = adapt_wall / fixed_wall_match
    if ratio ≤ 2.0
        @printf("✓ Acceptance ≤ 2× fixed-dt cost: PASS (%.2f×)\n", ratio)
    else
        @printf("△ Acceptance ≤ 2× fixed-dt cost: %.2f× — adaptive overhead on smooth problem\n",
            ratio)
    end
else
    @printf("No fixed-dt run reached err ≤ %.2e (need finer dt)\n", target_err)
end

# Order preserved test: log-log of err vs tol should slope ≈ 1 (adaptive
# error ∝ tol if controller is well-calibrated)
tols = sort(collect(keys(results)))
errs = [results[t].err for t in tols]
slope = log(errs[end] / errs[1]) / log(tols[end] / tols[1])
@printf("\nAdaptive err-vs-tol slope: %.2f (expected ~1.0 for well-calibrated controller)\n",
    slope)

@printf("\n── dt trajectory at tol=1e-7 (first 10, last 5) ──\n")
r7 = results[1e-7]
@printf("%-6s %-12s %-12s %-12s\n", "step", "t", "dt_used", "defect")
for i in 1:min(10, length(r7.t_hist))
    @printf("%-6d %-12.6f %-12.3e %-12.3e\n",
        i, r7.t_hist[i], r7.dt_hist[i], r7.def_hist[i])
end
if length(r7.t_hist) > 15
    @printf("  ...\n")
    for i in (length(r7.t_hist) - 4):length(r7.t_hist)
        @printf("%-6d %-12.6f %-12.3e %-12.3e\n",
            i, r7.t_hist[i], r7.dt_hist[i], r7.def_hist[i])
    end
end

@printf("\n%s\n", "═"^60)
@printf("A3 smoke-test verdict:\n")
@printf("  - PI controller closed-loop convergence (tol → 0 → err → 0): %s\n",
    abs(slope - 1.0) < 0.5 ? "✓ slope ≈ 1" : "△ slope $(slope)")
@printf("  - Rejection rate (n_rej / n_acc) at tol=1e-7: %.1f%%\n",
    100 * results[1e-7].n_rej / max(results[1e-7].n_acc, 1))
@printf("  - dt span at tol=1e-7: [%.2e, %.2e] (ratio %.1f)\n",
    results[1e-7].dt_min, results[1e-7].dt_max,
    results[1e-7].dt_max / results[1e-7].dt_min)
@printf("%s\n", "═"^60)
