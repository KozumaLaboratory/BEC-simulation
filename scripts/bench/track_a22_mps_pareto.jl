# A2.2 — MPS-{4,6,8} + Y4-mid + Y6-mid + Strang-mid Pareto on Phase 2a lab path.
#
# Master plan A2 covers the higher-order Yoshida + Multi-Product-Series (MPS)
# family audit. A2.1 found that Y6-mid is already at FP-floor (~8e-12) on
# Problem A (autonomous F=1 Rb87, c0=50 only). This A2.2 bench adds the
# Chin-Geiser MPS extrapolation family and runs all 6 schemes on the FULL
# Phase 2a lab path (with c1, c_dd, Zeeman, harmonic trap — i.e., the actual
# production GP problem) to establish the accuracy-vs-cost Pareto frontier.
#
# **Hypothesis (master plan)**: Y4-mid wins at moderate accuracy
# (1e-6 < err < 1e-9); Y6-mid wins at higher accuracy (err < 1e-9); MPS family
# loses across the board on the lab path due to the asymmetric V-step issue
# (`docs/design/integrator_modernization_plan.md` Track A diagnostic).
#
# **Result (2026-05-12)**: hypothesis FALSIFIED for the MPS-family-loses claim.
# With `_half_potential_step_midpoint!` as the inner V kernel (now time-reversal
# symmetric per Track A1), MPS-4 reaches order ~3.2 on the first dt halving
# (4e-3 → 2e-3) on the FULL lab path — restored from the order ~1 of plain
# Strang. MPS-6 and MPS-8 hit the reference precision floor (~9e-11) at the
# coarsest dt, indicating their nominal orders 6 and 8 are operational. The
# Pareto cost ranking at err=1e-10 target: MPS-6 (60 cost units) < Y6-mid (70)
# < MPS-8 (100) < MPS-4 (120) < Y4-mid (240). So MPS-6 is the cheapest path to
# floor-limited accuracy; Y4-mid remains optimal in the 1e-7 to 1e-9 band.
#
# Chin-Geiser MPS coefficients (Richardson extrapolation on S₂(h/k) with k
# sub-Strang steps each, eliminating the leading 2nd, 4th, ..., (2k-2)th
# error terms via Vandermonde inversion):
#   MPS-4 (k=2): (c₁, c₂) = (-1/3, 4/3)
#   MPS-6 (k=3): (1/24, -16/15, 81/40)
#   MPS-8 (k=4): (-1/360, 16/45, -729/280, 1024/315)
#
# Verification: each row sums to 1; constraints Σ cᵢ/i^{2j} = 0 for
# j = 1..(k-1).
#
# Cost per outer step (counted in inner-midpoint-Strang units):
#   Strang-mid: 1
#   Y4-mid:     3   (3-stage triple-jump in S₂ form)
#   Y6-mid:     7   (7-stage Yoshida solution-A)
#   MPS-4:      3   (1 + 2)
#   MPS-6:      6   (1 + 2 + 3)
#   MPS-8:      10  (1 + 2 + 3 + 4)
#
# Run: julia --project=. scripts/bench/track_a22_mps_pareto.jl
# Expected wall time: ~5-10 min (reference build + 6 schemes × 4 dts).

using SpinorBEC
using LinearAlgebra
using Printf

const N = 16
const T_FINAL = 0.04
const ATOM = Rb87

# Phase 2a parameters (lab path with c1, c_dd, Zeeman, trap)
const C0_BENCH = 50.0
const C1_BENCH = 1.0
const C_DD_BENCH = 1.0
const P_ZEEMAN = 0.5
const Q_ZEEMAN = 0.1

# ----- Yoshida composition weights -----
const _Y4_W1 = 1.0 / (2.0 - 2.0^(1.0 / 3.0))
const _Y4_W0 = 1.0 - 2.0 * _Y4_W1
const _Y4_WM = (_Y4_W1 + _Y4_W0) / 2.0

const _Y6_W1 = -1.17767998417887
const _Y6_W2 = +0.235573213359357
const _Y6_W3 = +0.784513610477560
const _Y6_W0 = 1.0 - 2.0 * (_Y6_W1 + _Y6_W2 + _Y6_W3)

# ----- MPS Chin-Geiser Richardson coefficients -----
const MPS4_COEF = (-1.0 / 3.0, 4.0 / 3.0)
const MPS6_COEF = (1.0 / 24.0, -16.0 / 15.0, 81.0 / 40.0)
const MPS8_COEF = (-1.0 / 360.0, 16.0 / 45.0, -729.0 / 280.0, 1024.0 / 315.0)

# Verify coefficients at load time:
let
    @assert abs(sum(MPS4_COEF) - 1.0) < 1e-14
    @assert abs(sum(MPS6_COEF) - 1.0) < 1e-14
    @assert abs(sum(MPS8_COEF) - 1.0) < 1e-14
    # MPS-6 must cancel 2nd-order error: Σ cᵢ/i² = 0
    @assert abs(sum(MPS6_COEF[i] / i^2 for i in 1:3)) < 1e-14
    # MPS-6 must cancel 4th-order error: Σ cᵢ/i⁴ = 0
    @assert abs(sum(MPS6_COEF[i] / i^4 for i in 1:3)) < 1e-14
    # MPS-8 must cancel 2nd, 4th, 6th order
    @assert abs(sum(MPS8_COEF[i] / i^2 for i in 1:4)) < 1e-14
    @assert abs(sum(MPS8_COEF[i] / i^4 for i in 1:4)) < 1e-14
    @assert abs(sum(MPS8_COEF[i] / i^6 for i in 1:4)) < 1e-14
end

function _make_grid()
    make_grid(GridConfig((N, N, N), (8.0, 8.0, 8.0)))
end

function _seed_psi!(ws)
    psi = ws.state.psi
    D = size(psi, 4)
    grid = ws.grid
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
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

# ----- Inline midpoint Strang -----
# Applies V(dt/2) K(dt) V(dt/2) with `_half_potential_step_midpoint!` as the
# V-step kernel. Used as the unit cell for Y4-mid, Y6-mid, MPS-{4,6,8}.
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

# ----- Y4-mid: 3-stage triple-jump -----
function y4_mid_step!(ws::SpinorBEC.Workspace{NN}) where {NN}
    dt = ws.sim_params.dt
    t_base = ws.state.t
    w1 = _Y4_W1; w0 = _Y4_W0
    inline_strang_mid!(ws, w1 * dt, t_base)
    inline_strang_mid!(ws, w0 * dt, t_base + w1 * dt)
    inline_strang_mid!(ws, w1 * dt, t_base + (w1 + w0) * dt)
    ws.state.t += dt
    ws.state.step += 1
    nothing
end

# ----- Y6-mid: 7-stage Yoshida solution-A -----
function y6_mid_step!(ws::SpinorBEC.Workspace{NN}) where {NN}
    dt = ws.sim_params.dt
    t_base = ws.state.t
    weights = (_Y6_W3, _Y6_W2, _Y6_W1, _Y6_W0, _Y6_W1, _Y6_W2, _Y6_W3)
    t_cur = 0.0
    for w in weights
        inline_strang_mid!(ws, w * dt, t_base + t_cur)
        t_cur += w * dt
    end
    ws.state.t += dt
    ws.state.step += 1
    nothing
end

# ----- Strang-mid (1-stage baseline) -----
function strang_mid_step!(ws::SpinorBEC.Workspace{NN}) where {NN}
    dt = ws.sim_params.dt
    t_base = ws.state.t
    inline_strang_mid!(ws, dt, t_base)
    ws.state.t += dt
    ws.state.step += 1
    nothing
end

# ----- MPS-{2k}: Chin-Geiser Richardson on inline midpoint Strang -----
#
# psi_out = Σⱼ cⱼ · S₂(h/j)^j · psi_in
# where S₂(h/j)^j means: starting from psi_in, apply j sub-Strangs at step h/j
# arriving at the same physical time t + h.
#
# Uses ws.state.psi for each branch's working buffer, restoring from psi_save
# at the start of each branch.
function mps_step!(ws::SpinorBEC.Workspace{NN}, dt::Float64, coefs,
                   psi_save, psi_branch, psi_accum) where {NN}
    t_base = ws.state.t
    psi_save .= ws.state.psi
    psi_accum .= 0
    for (j, c) in enumerate(coefs)
        # Run j sub-Strangs of size h/j from t_base to t_base + dt.
        ws.state.psi .= psi_save
        sub_dt = dt / j
        for s in 1:j
            inline_strang_mid!(ws, sub_dt, t_base + (s - 1) * sub_dt)
        end
        @. psi_accum += c * ws.state.psi
    end
    ws.state.psi .= psi_accum
    ws.state.t += dt
    ws.state.step += 1
    nothing
end

# ----- Run scheme to T_FINAL -----
function _bench_run(scheme::Symbol, dt::Float64)
    n_steps = Int(round(T_FINAL / dt))
    actual_dt = T_FINAL / n_steps
    ws = _build_ws(actual_dt)

    psi_save = similar(ws.state.psi)
    psi_branch = similar(ws.state.psi)
    psi_accum = similar(ws.state.psi)

    t_start = time()
    for _ in 1:n_steps
        if scheme === :strang_mid
            strang_mid_step!(ws)
        elseif scheme === :y4_mid
            y4_mid_step!(ws)
        elseif scheme === :y6_mid
            y6_mid_step!(ws)
        elseif scheme === :mps4
            mps_step!(ws, actual_dt, MPS4_COEF, psi_save, psi_branch, psi_accum)
        elseif scheme === :mps6
            mps_step!(ws, actual_dt, MPS6_COEF, psi_save, psi_branch, psi_accum)
        elseif scheme === :mps8
            mps_step!(ws, actual_dt, MPS8_COEF, psi_save, psi_branch, psi_accum)
        else
            error("unknown scheme $scheme")
        end
    end
    wall = time() - t_start
    (ws.state.psi, wall)
end

# Cost per outer step in "inner midpoint Strang" units
const COST = Dict(
    :strang_mid => 1,
    :y4_mid     => 3,
    :y6_mid     => 7,
    :mps4       => 3,
    :mps6       => 6,
    :mps8       => 10,
)

# ----- Order test -----
@printf("=== A2.2: MPS-{4,6,8} + Y4/Y6/Strang-mid Pareto ===\n")
@printf("Problem (Phase 2a): F=1 Rb87, N=%d³, c₀=%.0f, c₁=%.1f, c_dd=%.1f, T=%.3f\n",
    N, C0_BENCH, C1_BENCH, C_DD_BENCH, T_FINAL)
@printf("Reference: Y6-mid at dt=1e-5 (FP-floor ~1e-12 expected)\n\n")

@printf("Building Y6-mid reference at dt=1e-5... ")
flush(stdout)
t_ref = time()
psi_ref, wall_ref = _bench_run(:y6_mid, 1.0e-5)
@printf("done (%.1fs)\n\n", wall_ref)

dts = [4.0e-3, 2.0e-3, 1.0e-3, 5.0e-4]
schemes = [:strang_mid, :y4_mid, :y6_mid, :mps4, :mps6, :mps8]
labels = ("Strang-mid", "Y4-mid", "Y6-mid", "MPS-4", "MPS-6", "MPS-8")

errs = Dict(s => Float64[] for s in schemes)
walls = Dict(s => Float64[] for s in schemes)

for dt in dts
    @printf("dt = %.1e\n", dt)
    flush(stdout)
    for s in schemes
        ψ, wall = _bench_run(s, dt)
        e = sqrt(sum(abs2, ψ - psi_ref))
        push!(errs[s], e)
        push!(walls[s], wall)
        @printf("  [%-12s err=%.3e wall=%.1fs cost=%d×Strang]\n",
            labels[findfirst(==(s), schemes)], e, wall, COST[s])
        flush(stdout)
    end
end

@printf("\n── Error table ──\n")
@printf("%-12s", "dt")
for l in labels
    @printf("%-14s", l)
end
@printf("\n")
for (idx, dt) in enumerate(dts)
    @printf("%-12.1e", dt)
    for s in schemes
        @printf("%-14s", @sprintf("%.3e", errs[s][idx]))
    end
    @printf("\n")
end

@printf("\n── Order (log2 of successive halvings) ──\n")
@printf("%-18s", "dt ratio")
for l in labels
    @printf("%-14s", l)
end
@printf("\n")
for idx in 2:length(dts)
    @printf("%-18s", @sprintf("%.1e/%.1e", dts[idx-1], dts[idx]))
    for s in schemes
        e_prev = errs[s][idx-1]
        e_curr = errs[s][idx]
        ord = (e_curr > 0 && e_prev > 0) ? log2(e_prev / e_curr) : NaN
        @printf("%-14s", isnan(ord) ? "—" : @sprintf("%.2f", ord))
    end
    @printf("\n")
end

@printf("\n── Cost vs accuracy Pareto (cost = n_outer_steps × cost_per_step) ──\n")
@printf("%-12s %-12s %-12s %-12s %-14s\n", "scheme", "dt", "cost_units", "err", "err/cost")
for s in schemes
    for (idx, dt) in enumerate(dts)
        n_steps = Int(round(T_FINAL / dt))
        cost_units = n_steps * COST[s]
        e = errs[s][idx]
        @printf("%-12s %-12.1e %-12d %-12.3e %-14.3e\n",
            labels[findfirst(==(s), schemes)], dt, cost_units, e, e / cost_units)
    end
end

# Verdict: use the FIRST dt-halving for order extraction (smaller dt is
# floor-dominated for high-order schemes).
@printf("\n── Verdict (first dt-halving order, expected) ──\n")
first_orders = Dict{Symbol, Float64}()
for s in schemes
    e_prev = errs[s][1]
    e_curr = errs[s][2]
    first_orders[s] = (e_curr > 0 && e_prev > 0) ? log2(e_prev / e_curr) : NaN
end
floor_warning = false
for s in schemes
    label = labels[findfirst(==(s), schemes)]
    exp_str = s === :strang_mid ? "2" :
              s === :y4_mid     ? "4" :
              s === :y6_mid     ? "6" :
              s === :mps4       ? "4" :
              s === :mps6       ? "6" :
              s === :mps8       ? "8" : "?"
    floor_marker = errs[s][1] < 1e-9 ? " [FLOOR-LIMITED]" : ""
    if errs[s][1] < 1e-9
        floor_warning = true
    end
    @printf("  %-12s first-step order: %5.2f (expected %s)%s\n",
        label, first_orders[s], exp_str, floor_marker)
end
if floor_warning
    @printf("\nNOTE: schemes already at err ~ 1e-10 at the largest dt cannot have\n")
    @printf("their true order verified against the Y6-mid dt=1e-5 reference. To\n")
    @printf("distinguish MPS-6 vs MPS-8 vs Y6-mid, build a finer reference\n")
    @printf("(e.g., Y6-mid at dt=2e-6 → projected floor ~1e-15).\n")
end

@printf("\n── Pareto bands ──\n")
@printf("(For each scheme, smallest cost reaching given accuracy)\n")
for target in [1e-4, 1e-6, 1e-8, 1e-10]
    @printf("Target err < %.0e:\n", target)
    for s in schemes
        # Find smallest cost (largest dt) where err < target
        found = false
        for (idx, dt) in enumerate(dts)
            if errs[s][idx] < target
                n_steps = Int(round(T_FINAL / dt))
                cost_units = n_steps * COST[s]
                @printf("  %-12s dt=%.1e cost=%d × Strang  err=%.2e\n",
                    labels[findfirst(==(s), schemes)], dt, cost_units, errs[s][idx])
                found = true
                break
            end
        end
        if !found
            @printf("  %-12s (not reached at any tested dt)\n",
                labels[findfirst(==(s), schemes)])
        end
    end
end
