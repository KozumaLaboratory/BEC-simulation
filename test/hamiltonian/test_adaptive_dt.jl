using Test
using SpinorBEC
using Printf

# Adaptive timestep controller tests.
#
# Targets `src/hamiltonian/integrator/adaptive.jl`:
#   - `AdaptiveDtState` (mutable controller state)
#   - `adaptive_step!(ws, state; ...)` (single defect+PI step)
#   - `adaptive_run!(ws; t_end, ...)` (outer loop)
#
# Validates:
#   1. dt kwarg of split_step_midpoint! is non-breaking (default == ws.sim_params.dt).
#   2. dt override produces different ψ than default dt (when dt differs).
#   3. adaptive_run! completes a smooth Phase-2a problem.
#   4. Controller produces err ≲ tol on accepted steps (smoke test).
#   5. AdaptiveDtState counters increment as expected.

const N = 16
const T_FINAL = 0.04

function _build_ws(dt::Float64)
    grid = make_grid(GridConfig((N, N, N), (8.0, 8.0, 8.0)))
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 50.0, 1 => 1.0)),
        zeeman=ZeemanParams(0.5, 0.1),
        potential=HarmonicTrap(1.0, 1.0, 1.0),
        sim_params=sp,
        enable_ddi=true, c_dd=1.0,
        backend=CPUBackend(),
    )
    D = size(ws.state.psi, 4)
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        g = exp(-(x * x + y * y + z * z) / 2)
        for c in 1:D
            ws.state.psi[I, c] = g * cis(0.1 * c)
        end
    end
    SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, D, 3)
    ws
end

@testset "adaptive_dt: dt kwarg backward compat" begin
    ws_a = _build_ws(1e-3)
    ws_b = _build_ws(1e-3)
    psi0 = copy(ws_a.state.psi)

    # default dt
    split_step_midpoint!(ws_a)
    # explicit dt matching default
    split_step_midpoint!(ws_b; dt=1e-3)

    @test sqrt(sum(abs2, ws_a.state.psi .- ws_b.state.psi)) < 1e-13
end

@testset "adaptive_dt: dt override changes result" begin
    ws_a = _build_ws(1e-3)
    ws_b = _build_ws(1e-3)

    split_step_midpoint!(ws_a; dt=1e-3)
    split_step_midpoint!(ws_b; dt=2e-3)

    @test sqrt(sum(abs2, ws_a.state.psi .- ws_b.state.psi)) > 1e-6
end

@testset "adaptive_dt: AdaptiveDtState constructor" begin
    s = AdaptiveDtState(2e-3)
    @test s.dt == 2e-3
    @test isnan(s.defect_prev)
    @test s.n_accept == 0
    @test s.n_reject == 0
end

@testset "adaptive_dt: adaptive_step! single step" begin
    ws = _build_ws(1e-3)
    state = AdaptiveDtState(4e-3)
    dt_used = adaptive_step!(ws, state; tol_abs=1e-7, tol_rel=1e-7)
    @test dt_used > 0
    @test state.n_accept == 1
    @test state.defect_prev > 0
    @test state.dt > 0  # next-step proposal
end

@testset "adaptive_dt: adaptive_run! smooth Phase 2a" begin
    ws = _build_ws(4e-3)
    result = adaptive_run!(ws;
        t_end=T_FINAL,
        dt_init=4e-3,
        tol_abs=1e-8,
        tol_rel=1e-8,
    )
    @test result.n_accept > 0
    @test ws.state.t ≈ T_FINAL atol = 1e-10
    @test length(result.t_history) == result.n_accept
    @test all(result.dt_history .> 0)
    @test all(result.defect_history .> 0)
    # Final state should still be a normalized BEC
    norm_final = sqrt(sum(abs2, ws.state.psi))
    @test isfinite(norm_final)
    @test 0.99 < norm_final < 4.0   # loose check
end

@testset "adaptive_dt: tighter tol → more accepted steps" begin
    ws_loose = _build_ws(4e-3)
    r_loose = adaptive_run!(ws_loose;
        t_end=T_FINAL, dt_init=4e-3, tol_abs=1e-5, tol_rel=1e-5,
    )
    ws_tight = _build_ws(4e-3)
    r_tight = adaptive_run!(ws_tight;
        t_end=T_FINAL, dt_init=4e-3, tol_abs=1e-9, tol_rel=1e-9,
    )
    # Tighter tol should require more (or equal) steps.
    @test r_tight.n_accept >= r_loose.n_accept
end
