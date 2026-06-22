# Regression: split_step! must stay 2nd-order in dt WITH DDI active.
#
# The plain inner-V evaluates each substep's mean field (Φ_DDI, c₀|ψ|²,
# c₁⟨F⟩, …) at that substep's ENTRY ψ. With DDI the central DDI substep's
# one-sided O(τ) mean-field error does not cancel and Strang collapses from
# order 2 to ~1 (Eu F=6 + DDI measured ~1.0–1.5; the c_dd=0 control stays 2).
# `split_step!` auto-routes to the midpoint mean-field scheme when DDI is on
# (`MEANFIELD_MIDPOINT_ENABLED`), restoring slope-2. This trips if that
# routing regresses (ratio → ~2) or the toggle defaults off.
#
# Method: consecutive-difference convergence at fixed grid,
# ‖ψ(dt)-ψ(dt/2)‖ / ‖ψ(dt/2)-ψ(dt/4)‖ → 2^p. Slope-2 ⇒ ratio ~4.

using SpinorBEC
using Test

@testset "DDI Strang order (split_step! 2nd order with DDI)" begin
    n = 8
    L = 9.0
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    atom = Eu151   # F=6, D=13 — the production case the order drop was found on
    T = 0.03

    function _run(dt; c_dd=100.0)
        n_steps = Int(round(T / dt))
        sp = SimParams(; dt=dt, n_steps=n_steps, imaginary_time=false, normalize_every=0)
        ws = make_workspace(; grid, atom,
            interactions=InteractionParams(Dict(0 => 200.0, 1 => 2.0)),
            potential=HarmonicTrap(1.0, 1.0, 1.0),
            zeeman=ZeemanParams(1.0, 0.05),
            sim_params=sp, enable_ddi=(c_dd > 0), c_dd=c_dd)
        psi0 = zeros(ComplexF64, n, n, n, 13)
        for I in CartesianIndices((n, n, n))
            r2 = grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2 + grid.x[3][I[3]]^2
            psi0[I, 1] = exp(-r2 / 2)
            psi0[I, 3] = 0.15 * exp(-r2 / 2)
            psi0[I, 7] = 0.08 * exp(-r2 / 2)
        end
        dV = cell_volume(grid)
        psi0 ./= sqrt(sum(abs2, psi0) * dV)
        copyto!(ws.state.psi, psi0)
        for _ in 1:n_steps
            split_step!(ws)
        end
        return Array(ws.state.psi)
    end

    conv_ratio(; c_dd=100.0) = begin
        ψ1 = _run(0.002; c_dd)
        ψ2 = _run(0.001; c_dd)
        ψ4 = _run(0.0005; c_dd)
        maximum(abs, ψ1 .- ψ2) / maximum(abs, ψ2 .- ψ4)
    end

    @testset "DDI on: slope-2 restored" begin
        @test 3.0 < conv_ratio(; c_dd=100.0) < 5.5
    end

    @testset "c_dd=0 control: slope-2" begin
        @test 3.0 < conv_ratio(; c_dd=0.0) < 5.5
    end

    @testset "toggle off → reverts to ~1st order (mechanism check)" begin
        SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = false
        try
            r = conv_ratio(; c_dd=100.0)
            @test r < 3.0           # 1st order ⇒ ratio ~2
        finally
            SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true
        end
    end
end
