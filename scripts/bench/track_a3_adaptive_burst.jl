# A3 — Adaptive Y4-mid on a multi-scale near-instability problem.
#
# Test 4.2 from `docs/design/integrator_A3_adaptive_control_design.md`.
# Original spec: Eu post-quench (F=6 16³, T=1.0) too expensive to validate
# the controller in a single bench session (~30 min for fixed-dt baseline).
# Synthetic substitute: Phase 2a base + a Gaussian pulse on the linear
# Zeeman `p(t)` centered at t=0.02 with amplitude 50 and σ=0.002. The pulse
# drives a stiff burst around t=0.02 where the natural timescale ~ 1/|p| =
# 1/50 = 0.02 ≈ σ. Outside the burst the dynamics returns to smooth-Phase-2a
# (p_base=0.5).
#
# Acceptance (per design doc §5): adaptive at < 50% fixed-dt cost reaching
# the same accuracy as the burst-resolved fixed dt.
#
# Run: julia --project=. scripts/bench/track_a3_adaptive_burst.jl

using SpinorBEC
using LinearAlgebra
using Printf

const N = 16
const T_FINAL = 0.04
const ATOM = Rb87

const C0_BENCH = 50.0
const C1_BENCH = 1.0
const C_DD_BENCH = 1.0
const P_BASE = 0.5
# Peak Larmor period at peak amplitude must be << pulse width σ so that
# integrating across the pulse requires many sub-σ steps. With P_BURST_AMP=5000
# and σ=2e-3, peak Larmor period = 2π/5000 ≈ 1.3e-3, so σ spans ~ 1.6 peak
# periods → fixed dt must be ≪ 1e-3 inside pulse, dt ~ 5e-3 outside.
# Adaptive should refine 50-100× across the pulse boundary.
const P_BURST_AMP = 5000.0
const P_BURST_TC = 0.020      # pulse center (mid-simulation)
const P_BURST_SIGMA = 0.002   # pulse width — burst timescale ~ σ
const Q_ZEEMAN = 0.1

const _Y4_W1 = 1.0 / (2.0 - 2.0^(1.0 / 3.0))
const _Y4_W0 = 1.0 - 2.0 * _Y4_W1
const _Y6_W1 = -1.17767998417887
const _Y6_W2 = +0.235573213359357
const _Y6_W3 = +0.784513610477560
const _Y6_W0 = 1.0 - 2.0 * (_Y6_W1 + _Y6_W2 + _Y6_W3)

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

# Time-dependent Zeeman: p(t) = base + Gaussian pulse, q(t) = constant.
function _make_td_zeeman()
    p_wf = GaussianPulseWaveform(;
        center=P_BASE, amplitude=P_BURST_AMP,
        t_center=P_BURST_TC, sigma=P_BURST_SIGMA,
    )
    q_wf = ConstantWaveform(Q_ZEEMAN)
    TimeDependentZeeman(p_wf, q_wf)
end

function _build_ws(dt::Float64)
    grid = _make_grid()
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=ATOM,
        interactions=InteractionParams(Dict(0 => C0_BENCH, 1 => C1_BENCH)),
        zeeman=_make_td_zeeman(),
        potential=HarmonicTrap(1.0, 1.0, 1.0),
        sim_params=sp,
        enable_ddi=true, c_dd=C_DD_BENCH,
        backend=CPUBackend(),
    )
    _seed_psi!(ws)
    ws
end

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

function y4_mid_step!(ws::SpinorBEC.Workspace{NN}, dt::Float64, t_base::Float64) where {NN}
    w1 = _Y4_W1;
    w0 = _Y4_W0
    inline_strang_mid!(ws, w1 * dt, t_base)
    inline_strang_mid!(ws, w0 * dt, t_base + w1 * dt)
    inline_strang_mid!(ws, w1 * dt, t_base + (w1 + w0) * dt)
    nothing
end

function y6_mid_step!(ws::SpinorBEC.Workspace{NN}, dt::Float64, t_base::Float64) where {NN}
    weights = (_Y6_W3, _Y6_W2, _Y6_W1, _Y6_W0, _Y6_W1, _Y6_W2, _Y6_W3)
    t_cur = 0.0
    for w in weights
        inline_strang_mid!(ws, w * dt, t_base + t_cur)
        t_cur += w * dt
    end
    nothing
end

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

function adaptive_y4_step!(
    ws::SpinorBEC.Workspace{NN}, dt_try::Float64, t_curr::Float64,
    defect_prev::Float64;
    tol_abs::Float64=1e-9, tol_rel::Float64=1e-7,
    safety::Float64=0.9, p::Int=4,
    max_factor::Float64=5.0, min_factor::Float64=0.05,
    max_rejects::Int=12,
    pi_alpha::Float64=0.7 / p, pi_beta::Float64=-0.4 / p,
    psi_backup, psi_full, psi_half) where {NN}

    # Söderlind PI3.4: α=0.7/p, β=-0.4/p (negative β for smooth dt sequence).
    α = pi_alpha
    β = pi_beta
    n_rejects = 0
    dt = dt_try

    while n_rejects ≤ max_rejects
        psi_backup .= ws.state.psi
        y4_mid_step!(ws, dt, t_curr)
        psi_full .= ws.state.psi
        ws.state.psi .= psi_backup
        y4_mid_step!(ws, dt / 2, t_curr)
        y4_mid_step!(ws, dt / 2, t_curr + dt / 2)
        psi_half .= ws.state.psi
        defect = sqrt(sum(abs2, psi_full .- psi_half))
        normψ = sqrt(sum(abs2, psi_half))
        tol = tol_abs + tol_rel * normψ
        if defect ≤ tol
            if isnan(defect_prev) || defect_prev == 0.0
                factor = safety * (tol / defect)^α
            else
                factor = safety * (tol / defect)^α * (defect_prev / defect)^β
            end
            factor = clamp(factor, min_factor, max_factor)
            dt_new = dt * factor
            return (dt_used=dt, dt_new=dt_new, defect=defect,
                accepted=true, n_rejects=n_rejects)
        else
            ws.state.psi .= psi_backup
            factor = clamp(safety * (tol / defect)^α, min_factor, 0.5)
            dt *= factor
            n_rejects += 1
        end
    end
    error("adaptive_y4_step!: too many rejections at dt=$dt, t=$t_curr")
end

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

# ===== Run =====
@printf("=== A3 test 4.2: adaptive Y4-mid on Gaussian-pulse burst ===\n")
@printf("Problem: Phase 2a + Zeeman Gaussian pulse p(t) = %.2f + %.0f·N(t=%.3f, σ=%.4f)\n",
    P_BASE, P_BURST_AMP, P_BURST_TC, P_BURST_SIGMA)
@printf("Natural burst timescale ~ 1/|p_peak| ~ %.4f (≈ σ)\n", 1.0 / (P_BASE + P_BURST_AMP))
@printf("T_FINAL = %.3f.\n\n", T_FINAL)

# Show p(t) profile at a few times
@printf("p(t) profile: ")
for t in [0.0, 0.01, 0.018, 0.020, 0.022, 0.03, 0.04]
    p_val = P_BASE + P_BURST_AMP * exp(-0.5 * ((t - P_BURST_TC) / P_BURST_SIGMA)^2)
    @printf("p(%.3f)=%.2f  ", t, p_val)
end
@printf("\n\n")

@printf("Building Y6-mid reference at dt=2e-5... ")
flush(stdout)
t1 = time()
psi_ref = build_y6_reference(2.0e-5)
@printf("done (%.1fs)\n\n", time() - t1)

# Fixed-dt baseline — peak Larmor period 1.3e-3 → dts down to 1e-5 needed
@printf("── Fixed-dt Y4-mid baseline (peak Larmor period ≈ 1.3e-3) ──\n")
@printf("%-12s %-14s %-14s %-12s %-12s\n",
    "dt", "err vs ref", "wall", "n_steps", "err/wall")
fixed_results = NamedTuple[]
for dt in [4e-3, 1e-3, 5e-4, 1e-4, 5e-5, 2e-5]
    psi, wall, n_steps = fixed_y4_run(dt)
    err = sqrt(sum(abs2, psi .- psi_ref))
    push!(fixed_results, (dt=dt, err=err, wall=wall, n_steps=n_steps))
    @printf("%-12.1e %-14.3e %-14.2fs %-12d %-12.3e\n",
        dt, err, wall, n_steps, err / wall)
    flush(stdout)
end

# Adaptive at several tolerances
@printf("\n── Adaptive Y4-mid (defect + Söderlind PI) ──\n")
@printf("%-10s %-12s %-12s %-14s %-12s %-12s %-12s %-12s\n",
    "tol_rel", "wall", "n_accept", "n_reject", "dt_min", "dt_max", "dt_mean", "err vs ref")
adapt_results = Dict{Float64, NamedTuple}()
for tol_rel in [1e-5, 1e-7, 1e-9]
    tol_abs = tol_rel
    psi_adap, wall, n_acc, n_rej, t_hist, dt_hist, def_hist = adaptive_y4_run(;
        dt_init=4e-3, tol_abs, tol_rel
    )
    err = sqrt(sum(abs2, psi_adap .- psi_ref))
    adapt_results[tol_rel] = (
        wall=wall, n_acc=n_acc, n_rej=n_rej,
        dt_min=minimum(dt_hist), dt_max=maximum(dt_hist),
        dt_mean=sum(dt_hist) / length(dt_hist),
        err=err, t_hist=t_hist, dt_hist=dt_hist, def_hist=def_hist,
    )
    r = adapt_results[tol_rel]
    @printf("%-10.0e %-12.2f %-12d %-14d %-12.3e %-12.3e %-12.3e %-12.3e\n",
        tol_rel, r.wall, r.n_acc, r.n_rej, r.dt_min, r.dt_max, r.dt_mean, r.err)
end

# Pareto: find fixed-dt cost to match adaptive at tol=1e-7
@printf("\n── Pareto (cost to match err=adaptive@tol=1e-7) ──\n")
function find_fixed_match(target_err::Float64)
    best_wall = Inf
    best_dt = NaN
    best_n = -1
    for r in fixed_results
        if r.err ≤ target_err && r.wall < best_wall
            best_wall = r.wall
            best_dt = r.dt
            best_n = r.n_steps
        end
    end
    (best_wall, best_dt, best_n)
end

ad_r7 = adapt_results[1e-7]
fixed_wall, fixed_dt, fixed_n = find_fixed_match(ad_r7.err)
@printf("Adaptive tol=1e-7: err=%.2e wall=%.2fs n_acc=%d n_rej=%d\n",
    ad_r7.err, ad_r7.wall, ad_r7.n_acc, ad_r7.n_rej)
if isfinite(fixed_wall)
    ratio = ad_r7.wall / fixed_wall
    @printf("Cheapest fixed Y4-mid reaching err ≤ %.2e: dt=%.1e wall=%.2fs n=%d\n",
        ad_r7.err, fixed_dt, fixed_wall, fixed_n)
    if ratio < 0.5
        @printf("✓ ✓ ✓ Acceptance §5 #2 (< 50%% fixed cost): PASS (%.0f%% of fixed)\n",
            100 * ratio)
    elseif ratio < 1.0
        @printf("△ Acceptance §5 #2 (< 50%% fixed): NEAR PASS at %.0f%% — adaptive wins\n",
            100 * ratio)
    elseif ratio < 2.0
        @printf("△ Smooth-problem-like result: %.0f%% — modest adaptive overhead\n",
            100 * ratio)
    else
        @printf("✗ Adaptive %.1f× SLOWER than cheapest fixed — burst not stiff enough\n",
            ratio)
    end
else
    @printf("No fixed-dt reached err ≤ %.2e — need finer dt range\n", ad_r7.err)
end

# Print adaptive dt trajectory in detail to show burst response
@printf("\n── dt trajectory at tol=1e-7 (all steps, 'burst' region: t ∈ [%.3f, %.3f]) ──\n",
    P_BURST_TC - 3 * P_BURST_SIGMA, P_BURST_TC + 3 * P_BURST_SIGMA)
@printf("%-6s %-12s %-12s %-12s %-10s\n", "step", "t", "dt_used", "defect", "regime")
for i in 1:length(ad_r7.t_hist)
    in_burst = abs(ad_r7.t_hist[i] - P_BURST_TC) < 3 * P_BURST_SIGMA
    regime = in_burst ? "BURST" : "smooth"
    @printf("%-6d %-12.6f %-12.3e %-12.3e %-10s\n",
        i, ad_r7.t_hist[i], ad_r7.dt_hist[i], ad_r7.def_hist[i], regime)
end

# Statistics on burst response
n_burst = count(t -> abs(t - P_BURST_TC) < 3 * P_BURST_SIGMA, ad_r7.t_hist)
dt_burst =
    sum(
        ad_r7.dt_hist[i] for i in 1:length(ad_r7.t_hist)
        if abs(ad_r7.t_hist[i] - P_BURST_TC) < 3 * P_BURST_SIGMA
    ) / max(n_burst, 1)
n_smooth = length(ad_r7.t_hist) - n_burst
dt_smooth =
    sum(
        ad_r7.dt_hist[i] for i in 1:length(ad_r7.t_hist)
        if abs(ad_r7.t_hist[i] - P_BURST_TC) ≥ 3 * P_BURST_SIGMA
    ) / max(n_smooth, 1)

@printf("\n── Burst-vs-smooth dt adaptation ──\n")
@printf("Burst region (|t - %.3f| < 3σ):  %d steps, mean dt = %.3e\n",
    P_BURST_TC, n_burst, dt_burst)
@printf("Smooth region:                    %d steps, mean dt = %.3e\n",
    n_smooth, dt_smooth)
@printf("Adaptation ratio (smooth/burst):  %.1f×\n", dt_smooth / max(dt_burst, 1e-12))

@printf("\n%s\n", "═"^60)
@printf("A3 test 4.2 verdict:\n")
@printf("  - Burst region dt %s than smooth region dt by %.1f×\n",
    dt_burst < dt_smooth ? "SMALLER" : "LARGER", dt_smooth / max(dt_burst, 1e-12))
if isfinite(fixed_wall)
    ratio = ad_r7.wall / fixed_wall
    @printf("  - Pareto: adaptive vs cheapest fixed = %.0f%%\n", 100 * ratio)
    @printf("  - Acceptance §5 #2 (< 50%% fixed): %s\n",
        if ratio < 0.5
            "PASS"
        elseif ratio < 1.0
            "NEAR"
        else
            "FAIL"
        end)
end
@printf("  - Rejection rate at tol=1e-7: %.1f%%\n",
    100 * ad_r7.n_rej / max(ad_r7.n_acc, 1))
@printf("%s\n", "═"^60)
