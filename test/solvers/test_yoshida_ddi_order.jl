# Regression: the 4th-order Yoshida composition must stay 4th order WITH DDI.
#
# The plain composition `_aba_step!` evaluates the mean field at each inner-V
# substep entry; under DDI the central substep's one-sided O(τ) error breaks
# time symmetry and the composition collapses (~1st order). The fix composes
# the time-symmetric implicit-midpoint core as an UN-MERGED triple-jump
# (`_composition_midpoint_core!`) with enough Picard iterations (n_picard=3)
# that the base is time-symmetric to the order the 4th-order Richardson
# cancellation needs. Measured Y4 order vs n_picard (Eu F=6 + DDI, fine
# reference): np=1 → 3.85, np=2 → 3.8, np=3 → 3.99 (`bench/conv_order4c.jl`).
# The MERGED `_aba_step!` form caps at ~2.5 regardless of n_picard.
#
# Config = Eu F=6 production scale (c₀≈4687, λ_z≈1.18, weak field): the dt
# window 0.004–0.001 is asymptotic AND above the F64 round-off floor here
# (order-4 errors ~1e-7…1e-9). Method: consecutive-difference order,
# log2(‖ψ(dt)-ψ(dt/2)‖ / ‖ψ(dt/2)-ψ(dt/4)‖); Y4 ⇒ ~4.

using SpinorBEC
using Test

@testset "Yoshida-4 order with DDI (midpoint composition)" begin
    SB = SpinorBEC
    n = 6
    L = 8.0
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    atom = Eu151
    T = 0.02
    b = SB._COMP_YOSHIDA.b
    a = SB._COMP_YOSHIDA.a

    function _run(dt; c_dd, base)
        sp = SimParams(; dt=dt, n_steps=1, imaginary_time=false, normalize_every=0)
        ws = make_workspace(; grid, atom,
            interactions=InteractionParams(Dict(0 => 4687.0, 1 => 2.0)),
            potential=HarmonicTrap(1.0, 1.0, 1.18), zeeman=ZeemanParams(0.385, 0.05),
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
        for _ in 1:Int(round(T / dt))
            if base === :mid
                SB._composition_midpoint_core!(ws, dt, 13, b; t_base=ws.state.t, n_picard=3)
            else
                SB._aba_step!(ws, dt, 13, a, b; t_base=ws.state.t)
            end
            ws.state.t += dt
            ws.state.step += 1
        end
        Array(ws.state.psi)
    end

    # two consecutive-difference ratios (4 dt levels)
    ratios(; c_dd, base) = begin
        ψ = [_run(dt; c_dd, base) for dt in (0.004, 0.002, 0.001, 0.0005)]
        d = [maximum(abs, ψ[i] .- ψ[i + 1]) for i in 1:3]
        (log2(d[1] / d[2]), log2(d[2] / d[3]))
    end

    @testset "DDI midpoint triple-jump → 4th order" begin
        r1, r2 = ratios(; c_dd=100.0, base=:mid)
        @test r1 > 3.5
        @test r2 > 3.4   # finest level drifts toward round-off; looser bound
    end
    @testset "DDI plain merged composition → collapses (<2)" begin
        r1, _ = ratios(; c_dd=100.0, base=:plain)
        @test r1 < 2.0
    end
    @testset "c_dd=0 control → 4th order" begin
        r1, _ = ratios(; c_dd=0.0, base=:mid)
        @test r1 > 3.5
    end
end
