# Unified integrator benchmark v2 — FG/Thalhammer on Problem B (lab path).
#
# v1 had FG/Thalhammer SKIPPED on Problem B due to _assert_forcegrad_diagonal_only.
# v2 monkey-patches the assert → no-op, then runs FG with c1=1, DDI on.
#
# WHAT FG DOES with the assert disabled:
#   - Inner Strang substeps (V-half, K, V-half) handle c0 + c1 + DDI correctly
#   - FG correction term (-dt²/48)|∇V_eff|² uses ONLY c0 — c1 and DDI contributions
#     to V_eff are NOT captured. Per Track C v4/v5 derivation
#     (docs/design/integrator_track_c_derivation.md §5.2-5.3), the full extension
#     adds spinor-matrix and DDI ∇ψ derivative terms — NOT implemented yet.
#
# Expected lab-path behavior:
#   - FG correction catches c0 force-gradient → c0 sector accurate to order ~3-4
#   - c1, DDI sectors: only the Strang predictor accuracy = order 2
#   - Net global order: 2 (bottlenecked by missing c1/DDI in fg correction)
#
# This is the "what if FG ran on lab path with v1 implementation" diagnostic.
# Production FG needs the v4/v5 extension (= post-修論 task).

using SpinorBEC
using Printf

# Monkey-patch: disable the diagonal-only assertion
@eval SpinorBEC begin
    function _assert_forcegrad_diagonal_only(ws::Workspace)
        # disabled for v2 bench: test what FG does on lab path with c1/DDI present
        # (c1/DDI handled by inner Strang substep, but FG correction is c0-only)
        nothing
    end
end
@info "Patched _assert_forcegrad_diagonal_only to no-op (bench v2 mode)"

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

# Y4 driver (drop-in from v1)
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

function evolve!(label::String, ws, n_steps::Int)
    if label == "Strang"
        for _ in 1:n_steps; SpinorBEC.split_step!(ws); end
    elseif label == "Strang-mid"
        for _ in 1:n_steps; SpinorBEC.split_step_midpoint!(ws); end
    elseif label == "Y4-plain"
        for _ in 1:n_steps; _y4_step!(ws, SpinorBEC._half_potential_step!); end
    elseif label == "Y4-mid"
        for _ in 1:n_steps; _y4_step!(ws, SpinorBEC._half_potential_step_midpoint!); end
    elseif label == "Force-Gradient"
        for _ in 1:n_steps; SpinorBEC.split_step_forcegrad!(ws); end
    elseif label == "Thalhammer"
        for _ in 1:n_steps; SpinorBEC.split_step_thalhammer!(ws); end
    end
end

function _bench_run(label::String, dt::Float64; c1, c_dd, enable_ddi)
    n_steps = Int(round(T_FINAL / dt))
    ws = _build_ws(dt; c1, c_dd, enable_ddi)
    # Warmup
    evolve!(label, _build_ws(dt; c1, c_dd, enable_ddi), 1)
    t_start = time()
    evolve!(label, ws, n_steps)
    elapsed = time() - t_start
    (psi=ws.state.psi, wall=elapsed, per_step=elapsed / n_steps)
end

function _problem_table(label::String, c1::Float64, c_dd::Float64, enable_ddi::Bool,
                        schemes::Vector{String}, dts::Vector{Float64})
    @printf("\n%s\n", "═"^85)
    @printf("Problem %s: c0=50, c1=%.1f, c_dd=%.1f, DDI=%s, T=%.3f, %d³ Rb87 F=1\n",
        label, c1, c_dd, enable_ddi, T_FINAL, N)
    @printf("%s\n", "═"^85)

    @printf("Building reference (split_step! @ dt=2e-5)...\n")
    ws_ref = _build_ws(2e-5; c1, c_dd, enable_ddi)
    t0 = time()
    for _ in 1:Int(round(T_FINAL / 2e-5))
        SpinorBEC.split_step!(ws_ref)
    end
    @printf("  ref wall = %.1fs, ‖ψ_ref‖ = %.10f\n", time() - t0, sqrt(sum(abs2, ws_ref.state.psi)))
    psi_ref = copy(ws_ref.state.psi)

    @printf("\n%-18s  %-11s  %-11s  %-11s  %-6s %-6s  %-9s\n",
        "scheme", "err@h₁", "err@h₂", "err@h₃", "o12", "o23", "ms/step")
    results = Dict{String, NamedTuple}()
    for scheme in schemes
        errs = Float64[]
        per_steps = Float64[]
        ok = true
        for h in dts
            try
                r = _bench_run(scheme, h; c1, c_dd, enable_ddi)
                push!(errs, sqrt(sum(abs2, r.psi - psi_ref)))
                push!(per_steps, r.per_step)
            catch e
                @printf("%-18s  [ERROR: %s]\n", scheme, sprint(showerror, e)[1:min(end, 60)])
                ok = false
                break
            end
        end
        if !ok
            results[scheme] = (errs=Float64[NaN, NaN, NaN], per_steps=Float64[NaN], o12=NaN, o23=NaN)
            continue
        end
        o12 = log2(errs[1] / errs[2])
        o23 = log2(errs[2] / errs[3])
        results[scheme] = (errs=errs, per_steps=per_steps, o12=o12, o23=o23)
        @printf("%-18s  %-11.3e  %-11.3e  %-11.3e  %-6.2f %-6.2f  %-9.3f\n",
            scheme, errs[1], errs[2], errs[3], o12, o23, 1000 * per_steps[2])
    end
    return results
end

const SCHEMES_LAB = ["Strang", "Strang-mid", "Y4-plain", "Y4-mid",
                     "Force-Gradient", "Thalhammer"]
const DTS = [4e-3, 2e-3, 1e-3]

@printf("=== Unified integrator bench v2: Problem B with FG/Thalhammer ===\n")
@printf("dt sweep: %s\n", DTS)
@printf("FG correction TERM uses c0 ONLY; c1/DDI captured only by Strang substep.\n")
@printf("Result is intentionally 'partial FG on lab path' — diagnostic, not production.\n")

results_B = _problem_table("B (lab path)", 1.0, 1.0, true, SCHEMES_LAB, DTS)

@printf("\n--- Verdict ---\n")
@printf("Strang baseline order:  %.2f (= reference)\n", results_B["Strang"].o12)
@printf("Y4-mid order:           %.2f (= practical optimum, Track A1)\n", results_B["Y4-mid"].o12)
fg_o = results_B["Force-Gradient"].o12
@printf("Force-Gradient order:   %.2f   ", fg_o)
if fg_o > 2.5
    println("← unexpectedly high; c0-only FG correction provides some benefit on lab path")
elseif fg_o > 1.5
    println("← order ~2 = Strang-bottlenecked (c1/DDI sectors limit overall order)")
else
    println("← collapse below order 2 — FG correction perturbs lab-path dynamics")
end
@printf("Thalhammer order:       %.2f (= FG alias, identical)\n", results_B["Thalhammer"].o12)
@printf("Y4-mid vs FG err ratio: %.1f×\n",
    results_B["Force-Gradient"].errs[2] / results_B["Y4-mid"].errs[2])
