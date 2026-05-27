# A3 production validation — adaptive_run! on Eu151 F=6 post-quench.
#
# Design-doc §4.2 specifies an Eu post-quench problem (F=6, T=1.0) to test
# whether the adaptive controller actually wins over fixed dt. The
# T=1.0 version costs ~30 min of fixed-dt baseline; this bench uses
# T=0.05 with a Zeeman quench (p: 1 → 100 ramp over Δt=0.002 at t=0.02)
# which exposes the same fast/slow scale separation in a tractable
# 5-15 minute budget.
#
# Uses the production API from `src/hamiltonian/integrator/adaptive.jl`:
#   `adaptive_run!(ws; t_end, tol_abs, tol_rel, step!=split_step_midpoint!)`
#
# Run: julia --project=. scripts/bench/track_a3_eu_postquench.jl

using SpinorBEC
using LinearAlgebra
using Printf

const N = 16
const T_FINAL = 0.05
const ATOM = Eu151

# Eu standard scales: c_total ≈ 4689, c1_ratio ≈ 0.028, c_dd ≈ 7647
# Use scaled-down values for the 16³ bench (full Eu would need >32³).
const C0_BENCH = 200.0
const C1_BENCH = 5.0       # ≈ 0.025 × c0
const C_DD_BENCH = 100.0
# Zeeman quench: p_low=1 (smooth Larmor) → p_high=100 (fast Larmor)
# Ramp center 0.025, ramp width 0.002 (sharp).
const P_LOW = 1.0
const P_HIGH = 100.0
const QUENCH_T_CENTER = 0.025
const QUENCH_WIDTH = 0.002
const Q_ZEEMAN = 0.1

# Time-dependent Zeeman via PiecewiseLinearWaveform:
#   p(t) = P_LOW  for t < t_c - w/2
#        = linear in [t_c-w/2, t_c+w/2]
#        = P_HIGH for t > t_c + w/2
function _make_td_zeeman()
    t_c = QUENCH_T_CENTER
    w = QUENCH_WIDTH
    p_wf = PiecewiseLinearWaveform(
        [0.0, t_c - w / 2, t_c + w / 2, T_FINAL + 1.0],
        [P_LOW, P_LOW, P_HIGH, P_HIGH],
    )
    q_wf = ConstantWaveform(Q_ZEEMAN)
    TimeDependentZeeman(p_wf, q_wf)
end

function _build_ws(dt::Float64)
    grid = make_grid(GridConfig((N, N, N), (10.0, 10.0, 10.0)))
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
    # Initialize: spin-coherent state along x-axis (perpendicular to B || z)
    psi = ws.state.psi
    D = size(psi, 4)
    grid_cur = ws.grid
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid_cur.x[1][I[1]];
        y = grid_cur.x[2][I[2]];
        z = grid_cur.x[3][I[3]]
        g = exp(-(x * x + y * y + z * z) / 4)
        # Spin-coherent state along +x for F=6: components c[m] proportional to
        # binomial coefficients in (cos(π/4), sin(π/4))^{2F}
        # Simplified: just put weight on m=±F and 0 components.
        for c in 1:D
            psi[I, c] = g * cis(0.05 * c) / sqrt(D)
        end
    end
    SpinorBEC._normalize_psi!(psi, ws.grid, D, 3)
    ws
end

function fixed_run(dt::Float64)
    n_steps = Int(round(T_FINAL / dt))
    actual_dt = T_FINAL / n_steps
    ws = _build_ws(actual_dt)
    t_start = time()
    for _ in 1:n_steps
        split_step_midpoint!(ws)
    end
    wall = time() - t_start
    (ws.state.psi, wall, n_steps)
end

function adaptive_run(; dt_init::Float64, tol_rel::Float64, tol_abs::Float64=tol_rel)
    ws = _build_ws(dt_init)
    t_start = time()
    result = adaptive_run!(ws;
        t_end=T_FINAL, dt_init=dt_init,
        tol_abs=tol_abs, tol_rel=tol_rel,
    )
    wall = time() - t_start
    (ws.state.psi, wall, result)
end

# ===== Run =====
@printf("=== A3 production validation: Eu151 F=6 post-quench ===\n")
@printf("Atom: %s (F=%d, D=%d)\n", ATOM.name,
    Int(ATOM.F), Int(2 * ATOM.F + 1))
@printf("Grid: N=%d³, box=10³, T_FINAL=%.3f\n", N, T_FINAL)
@printf("Interactions: c₀=%.1f, c₁=%.2f, c_dd=%.1f, q=%.2f\n",
    C0_BENCH, C1_BENCH, C_DD_BENCH, Q_ZEEMAN)
@printf("Zeeman quench: p: %.1f → %.1f over Δt=%.3f at t_c=%.3f\n",
    P_LOW, P_HIGH, QUENCH_WIDTH, QUENCH_T_CENTER)
@printf("Pre-quench Larmor period: 2π/p_low = %.4f (T_FINAL/period = %.1f)\n",
    2π / P_LOW, T_FINAL * P_LOW / (2π))
@printf("Post-quench Larmor period: 2π/p_high = %.4f\n", 2π / P_HIGH)
@printf("\n")

@printf("Building Y4-mid reference at dt=2e-5... ")
flush(stdout)
t_ref = time()
psi_ref, wall_ref, _ = fixed_run(2e-5)
@printf("done (%.1fs)\n\n", wall_ref)

# Fixed-dt sweep
@printf("── Fixed-dt split_step_midpoint! baseline ──\n")
@printf("%-12s %-14s %-14s %-12s\n",
    "dt", "err vs ref", "wall", "n_steps")
fixed_results = NamedTuple[]
for dt in [4e-3, 1e-3, 5e-4, 2e-4, 1e-4]
    psi, wall, n = fixed_run(dt)
    err = sqrt(sum(abs2, psi .- psi_ref))
    push!(fixed_results, (dt=dt, err=err, wall=wall, n_steps=n))
    @printf("%-12.1e %-14.3e %-14.2fs %-12d\n", dt, err, wall, n)
    flush(stdout)
end

# Adaptive sweep
@printf("\n── Adaptive split_step_midpoint! (production API) ──\n")
@printf("%-10s %-12s %-12s %-12s %-12s %-14s %-14s\n",
    "tol_rel", "wall", "n_accept", "n_reject", "dt_min", "dt_max", "err vs ref")
adaptive_results = Dict{Float64, NamedTuple}()
for tol_rel in [1e-5, 1e-7, 1e-9]
    psi, wall, res = adaptive_run(; dt_init=4e-3, tol_rel=tol_rel)
    err = sqrt(sum(abs2, psi .- psi_ref))
    adaptive_results[tol_rel] = (
        wall=wall, n_acc=res.n_accept, n_rej=res.n_reject,
        dt_min=minimum(res.dt_history), dt_max=maximum(res.dt_history),
        err=err, dt_history=res.dt_history, t_history=res.t_history,
        defect_history=res.defect_history,
    )
    r = adaptive_results[tol_rel]
    @printf("%-10.0e %-12.2f %-12d %-12d %-12.3e %-12.3e %-14.3e\n",
        tol_rel, r.wall, r.n_acc, r.n_rej, r.dt_min, r.dt_max, r.err)
    flush(stdout)
end

# Pareto analysis
@printf("\n── Pareto: cost to match adaptive err ──\n")
for tol_rel in [1e-5, 1e-7, 1e-9]
    r = adaptive_results[tol_rel]
    # Find cheapest fixed dt reaching err ≤ r.err
    best_wall = Inf
    best_dt = NaN
    for fr in fixed_results
        if fr.err ≤ r.err && fr.wall < best_wall
            best_wall = fr.wall
            best_dt = fr.dt
        end
    end
    @printf("Adaptive tol=%.0e: err=%.2e wall=%.2fs (%d acc + %d rej)\n",
        tol_rel, r.err, r.wall, r.n_acc, r.n_rej)
    if isfinite(best_wall)
        ratio = r.wall / best_wall
        verdict = if ratio < 0.5
            "✓ WINS (< 50%)"
        elseif ratio < 1.0
            "△ marginal (50-100%)"
        elseif ratio < 2.0
            "△ slight loss"
        else
            "✗ LOSES (≥ 2×)"
        end
        @printf("  Fixed match dt=%.1e wall=%.2fs → adaptive ratio = %.0f%% [%s]\n",
            best_dt, best_wall, 100 * ratio, verdict)
    else
        @printf("  No fixed-dt reaches this accuracy in the tested range\n")
    end
end

# Quench-region dt analysis
@printf("\n── dt trajectory at tol=1e-7 (pre-quench, quench, post-quench) ──\n")
r7 = adaptive_results[1e-7]
@printf("Pre-quench  (t < %.3f):   %d steps, mean dt = %.3e\n",
    QUENCH_T_CENTER - QUENCH_WIDTH,
    count(t -> t < QUENCH_T_CENTER - QUENCH_WIDTH, r7.t_history),
    let times = r7.t_history, dts = r7.dt_history, mask = times .< QUENCH_T_CENTER - QUENCH_WIDTH

        sum(dts[mask]) / max(count(mask), 1)
    end,
)
@printf("Quench region:            %d steps, mean dt = %.3e\n",
    count(t -> QUENCH_T_CENTER - QUENCH_WIDTH ≤ t ≤ QUENCH_T_CENTER + QUENCH_WIDTH,
        r7.t_history),
    let times = r7.t_history, dts = r7.dt_history,
        mask = (QUENCH_T_CENTER - QUENCH_WIDTH) .≤ times .≤ (QUENCH_T_CENTER + QUENCH_WIDTH)

        sum(dts[mask]) / max(count(mask), 1)
    end,
)
@printf("Post-quench (t > %.3f):   %d steps, mean dt = %.3e\n",
    QUENCH_T_CENTER + QUENCH_WIDTH,
    count(t -> t > QUENCH_T_CENTER + QUENCH_WIDTH, r7.t_history),
    let times = r7.t_history, dts = r7.dt_history, mask = times .> QUENCH_T_CENTER + QUENCH_WIDTH

        sum(dts[mask]) / max(count(mask), 1)
    end,
)

@printf("\n%s\n", "═"^60)
@printf("Eu post-quench summary:\n")
@printf("  Reference build: %.0fs (Y4-mid dt=2e-5, %d steps)\n",
    wall_ref, Int(round(T_FINAL / 2e-5)))
@printf("  Adaptive @ tol=1e-7: %d total steps, dt span [%.2e, %.2e] (%.0f× range)\n",
    r7.n_acc, r7.dt_min, r7.dt_max, r7.dt_max / r7.dt_min)
@printf("  Production API call: adaptive_run!(ws; t_end=%.3f, dt_init=4e-3, tol_rel=1e-7)\n",
    T_FINAL)
@printf("%s\n", "═"^60)
