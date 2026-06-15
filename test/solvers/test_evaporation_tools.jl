# Evaporation OPTIMIZATION/SCAN tools — these run the (scalar) model in loops
# (optimizer, parameter scans, K3 fit), so they live in the ci tier, not fast.
# The model's unit + agreement gates stay in test/solvers/test_evaporation.jl.

using Test
using SpinorBEC
using SpinorBEC: Eu151, EvapTrap, EvapParams, FortRamp, run_evaporation,
    optimize_evaporation_ramp, scan_ramp_param, scan_ramp_2d, fit_euv3_K3,
    optimize_euv3_evaporation, run_euv3_evaporation

const _as_t = Eu151.a_s

_eu_trap_t() = EvapTrap(;
    wavelength=1064e-9, alpha=2.0e-36, waists=[30e-6, 30e-6, 30e-6],
    directions=[(1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)],
    positions=[(0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)],
    mass=Eu151.mass, gravity_axis=3)

_euv3_ramp_t() = FortRamp(
    [0.0, 0.6, 1.5, 2.1, 2.7],
    [6.0 2.0 0.56 0.16 0.099;
        0.0 1.8 1.6 1.0 0.09;
        0.0 0.0 0.0 0.0 0.0])

@testset "Evaporation optimization tools (ci)" begin
    @testset "optimize_evaporation_ramp improves N_BEC (stub optimizer)" begin
        trap = _eu_trap_t()
        p = EvapParams(; a_s=_as_t, tau_bg=10.0, K3=0.0)
        base = _euv3_ramp_t()
        # deterministic grid-search stub matching the bayesian_optimize contract
        function grid_opt(obj, bounds; n_init, n_iter, minimise, n_grid=0)
            best_p = [(lo + hi) / 2 for (lo, hi) in bounds]
            best_y = obj(best_p)
            for x1 in range(bounds[1]...; length=2), x2 in range(bounds[2]...; length=2),
                x3 in range(bounds[3]...; length=2)

                y = obj([x1, x2, x3])
                if (minimise && y < best_y) || (!minimise && y > best_y)
                    best_y = y
                    best_p = [x1, x2, x3]
                end
            end
            (best_p=best_p, best_y=best_y, X_history=Float64[], y_history=Float64[])
        end
        out = optimize_evaporation_ramp(trap, p, base; N0=2e6, T0=40e-6,
            n_init=2, n_iter=2, optimizer=grid_opt)
        @test out.result.reached_bec
        @test out.bo.best_y > 1                         # a real BEC atom number
        @test out.result.N_BEC == out.bo.best_y
    end

    @testset "scan_ramp_param 1-D landscape" begin
        trap = _eu_trap_t()
        p = EvapParams(; a_s=_as_t, tau_bg=10.0, K3=0.0)
        scan = scan_ramp_param(trap, p, _euv3_ramp_t(); index=1, values=[1.0, 2.0, 3.0],
            N0=2e6, T0=40e-6)
        @test length(scan) == 3
        @test all(s -> haskey(s, :N_BEC) && haskey(s, :reached), scan)
        @test scan[1].value == 1.0
        @test scan[1].reached                           # unmodified ramp reaches BEC
    end

    @testset "scan_ramp_2d landscape matrix" begin
        trap = _eu_trap_t()
        p = EvapParams(; a_s=_as_t, tau_bg=10.0, K3=0.0)
        M = scan_ramp_2d(trap, p, _euv3_ramp_t(); index1=1, values1=[1.0, 2.0],
            index2=2, values2=[0.5, 1.0, 1.5], N0=2e6, T0=40e-6)
        @test size(M) == (2, 3)
        @test all(x -> isnan(x) || x > 0, M)
    end

    @testset "fit_euv3_K3 hits a target N_BEC" begin
        # N_BEC decreasing in K3 ⇒ bisection recovers the K3 reproducing a target.
        fit = fit_euv3_K3(; target_N_BEC=5.0e4, K3_lo=1e-41, K3_hi=1e-39, rtol=0.05)
        @test fit.converged
        @test 0.95 < fit.N_BEC / 5.0e4 < 1.05
        @test 1e-41 < fit.K3 < 1e-39                     # ≈ the default 1e-40
        hi = fit_euv3_K3(; target_N_BEC=1e8, K3_lo=1e-41, K3_hi=1e-39)
        @test !hi.converged                              # unreachable target clamps
    end

    @testset "real bayesian_optimize end-to-end (regression: verbose/n_grid)" begin
        # Exercises the actual bayesian_optimize path — guards two bugs this caught:
        # _default_solver_verbose not imported into module Optimization, and the
        # n_grid^d candidate mesh OOM at the default n_grid=100 for d=3.
        out = optimize_euv3_evaporation(; n_init=3, n_iter=3)
        @test out.result.reached_bec
        # the optimum is ≥ the unmodified lab ramp (bounds bracket the baseline [1,1,1])
        base = run_euv3_evaporation()
        @test out.result.N_BEC >= 0.95 * base.N_BEC
    end
end
