# Evaporation OPTIMIZATION/SCAN tools — these run the (scalar) model in loops
# (optimizer, parameter scans, K3 fit), so they live in the ci tier, not fast.
# The model's unit + agreement gates stay in test/solvers/test_evaporation.jl.

using Test
using SpinorBEC
using SpinorBEC: Eu151, EvapTrap, EvapParams, FortRamp, run_evaporation,
    optimize_evaporation_ramp, scan_ramp_param, scan_ramp_2d, fit_euv3_K3,
    optimize_euv3_evaporation, run_euv3_evaporation,
    ramp_scale_powers, optimize_ramp_coordinate, optimize_ramp_monotone,
    param_uncertainty_ensemble,
    EvapScenario, robustness_scenarios, optimize_ramp_robust, robustness_report

const _as_t = Eu151.a_s

_eu_trap_t() = EvapTrap(;
    wavelength=1064e-9, alpha=2.0e-36, waists=[30e-6, 30e-6, 30e-6],
    directions=[(1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)],
    positions=[(0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)],
    mass=Eu151.mass, gravity_axis=3)

# from the loaded crossed trap (both FORTs on); ω̄ decreases monotonically.
_euv3_ramp_t() = FortRamp(
    [0.0, 0.9, 1.5, 2.1],
    [2.0 0.56 0.16 0.099;
        1.8 1.6 1.0 0.09;
        0.0 0.0 0.0 0.0])

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

    @testset "ramp_scale_powers + coordinate-descent optimizer" begin
        base = _euv3_ramp_t()
        s = ramp_scale_powers([1.0, 2.0, 0.5, 1.0], base)
        @test s.times == base.times
        @test s.powers_W[:, 2] ≈ 2.0 .* base.powers_W[:, 2]
        @test s.powers_W[:, 3] ≈ 0.5 .* base.powers_W[:, 3]
        @test_throws ArgumentError ramp_scale_powers([1.0, 2.0], base)
        # coordinate descent starts from the baseline (all 1s) and never regresses
        trap = _eu_trap_t()
        p = EvapParams(; a_s=_as_t, tau_bg=10.0, K3=0.0)
        baseN = run_evaporation(trap, base, p; N0=2e6, T0=40e-6).N_BEC
        out = optimize_ramp_coordinate(trap, p, base; N0=2e6, T0=40e-6,
            free=2:3, n_sweeps=1, n_line=3)
        @test length(out.mults) == length(base.times)
        @test out.result.reached_bec
        @test out.N_BEC >= baseN * 0.999          # ≥ baseline (descent can't worsen it)

        # multi-start (restarts>0) never does worse than the single baseline descent
        single = optimize_ramp_coordinate(trap, p, base; N0=2e6, T0=40e-6,
            free=2:4, n_sweeps=2, n_line=5)
        multi = optimize_ramp_coordinate(trap, p, base; N0=2e6, T0=40e-6,
            free=2:4, n_sweeps=2, n_line=5, restarts=3, seed=11)
        @test multi.score >= single.score - 1e-9   # extra starts can only help
        @test multi.result.reached_bec
        # seeded ⇒ deterministic
        multi2 = optimize_ramp_coordinate(trap, p, base; N0=2e6, T0=40e-6,
            free=2:4, n_sweeps=2, n_line=5, restarts=3, seed=11)
        @test multi.mults == multi2.mults
    end

    @testset "monotone-constrained ramp optimizer" begin
        trap = _eu_trap_t()
        p = EvapParams(; a_s=_as_t, tau_bg=10.0, K3=0.0)
        base = _euv3_ramp_t()
        baseN = run_evaporation(trap, base, p; N0=2e6, T0=40e-6).N_BEC
        out = optimize_ramp_monotone(trap, p, base; N0=2e6, T0=40e-6,
            n_sweeps=3, n_line=9, restarts=2, seed=4)
        @test out.result.reached_bec
        @test size(out.fracs) == (size(base.powers_W, 1), length(base.times) - 1)
        @test all(0.0 .< out.fracs .<= 1.0)                # drop fractions in (0,1]
        # the produced ramp is monotone-decreasing per beam (the physical constraint)
        for b in 1:size(out.ramp.powers_W, 1)
            @test all(diff(out.ramp.powers_W[b, :]) .<= 1e-12)
        end
        # the lab ramp is in the family (its own ratios) and is the warm start, so the
        # monotone optimum is never worse than the (already monotone) baseline
        @test out.N_BEC >= baseN * 0.999
        # seeded ⇒ deterministic
        out2 = optimize_ramp_monotone(trap, p, base; N0=2e6, T0=40e-6,
            n_sweeps=3, n_line=9, restarts=2, seed=4)
        @test out.fracs == out2.fracs
    end

    @testset "robust (worst-case ensemble) monotone optimizer" begin
        trap = _eu_trap_t()
        p = EvapParams(; a_s=_as_t, tau_bg=10.0, K3=1e-40)   # nonzero ⇒ K3 scaling differs
        base = _euv3_ramp_t()
        # ensemble over α and K3 uncertainty; nominal (1,1) omitted, added internally
        ens = param_uncertainty_ensemble(trap, p; alpha_factors=(1.0, 1.1), K3_factors=(1.0, 2.0))
        @test all(m -> m isa Tuple{EvapTrap, EvapParams}, ens)
        @test !any(m -> m[1].alpha == trap.alpha && m[2].K3 == p.K3, ens)  # nominal omitted
        out = optimize_ramp_monotone(trap, p, base; N0=2e6, T0=40e-6,
            n_sweeps=3, n_line=9, restarts=1, seed=2, ensemble=ens)
        @test out.result.reached_bec                       # nominal reaches BEC
        # the chosen schedule reaches BEC for EVERY ensemble member (worst-case ≥ 1)
        for (t, pp) in ens
            @test run_evaporation(t, out.ramp, pp; N0=2e6, T0=40e-6).reached_bec
        end
    end

    @testset "robustness_scenarios builds the operational-error set" begin
        trap = _eu_trap_t()
        p = EvapParams(; a_s=_as_t, tau_bg=10.0, K3=1e-40)
        scs = robustness_scenarios(trap, p; N0=2e6, T0=40e-6,
            power_frac=0.1, imbalance_frac=0.05, T0_frac=0.1, N0_frac=0.1,
            time_frac=0.05, K3_hi_factor=2.0)
        @test all(s -> s isa EvapScenario, scs)
        # power/α −10% ⇒ a shallower trap (lower α); adverse T0 is HOTTER, adverse N0 FEWER
        pw = only(filter(s -> occursin("power", s.label), scs))
        @test pw.trap.alpha ≈ trap.alpha * 0.9
        t0 = only(filter(s -> occursin("T₀", s.label), scs))
        @test t0.T0 ≈ 40e-6 * 1.1
        n0 = only(filter(s -> occursin("N₀", s.label), scs))
        @test n0.N0 ≈ 2e6 * 0.9
        # imbalance is opposite-signed per beam (aspect-ratio extremes)
        imb = filter(s -> occursin("imbalance", s.label), scs)
        @test length(imb) == 2
        @test imb[1].beam_factor[1] ≈ 1.05 && imb[1].beam_factor[2] ≈ 0.95
        # enabling nothing ⇒ empty set (nominal is added by the optimizer, not here)
        @test isempty(robustness_scenarios(trap, p; N0=2e6, T0=40e-6))
    end

    @testset "optimize_ramp_robust maximizes the worst case" begin
        trap = _eu_trap_t()
        p = EvapParams(; a_s=_as_t, tau_bg=10.0, K3=1e-40)
        base = _euv3_ramp_t()
        scs = robustness_scenarios(trap, p; N0=2e6, T0=40e-6,
            power_frac=0.1, imbalance_frac=0.05, T0_frac=0.1)
        out = optimize_ramp_robust(trap, p, base; N0=2e6, T0=40e-6, scenarios=scs,
            n_sweeps=3, n_line=9, restarts=1, seed=2)
        @test out.result.reached_bec                       # nominal reaches BEC
        @test out.worst > 1                                # every scenario reaches BEC (worst-case is an N_BEC)
        # the robust schedule reaches BEC for EVERY scenario, including the perturbed ramp/N0/T0
        rep = robustness_report(trap, p, out.ramp; N0=2e6, T0=40e-6, scenarios=scs)
        @test all(r -> r.reached_bec, rep)
        @test length(rep) == length(scs) + 1               # nominal prepended
        # worst-case of the report equals the returned worst (to the model's tolerance)
        @test minimum(r.N_BEC for r in rep) ≈ out.worst rtol = 1e-6
        # seeded ⇒ deterministic
        out2 = optimize_ramp_robust(trap, p, base; N0=2e6, T0=40e-6, scenarios=scs,
            n_sweeps=3, n_line=9, restarts=1, seed=2)
        @test out.fracs == out2.fracs
    end

    @testset "robust worst-case ≥ nominal-optimal worst-case" begin
        trap = _eu_trap_t()
        p = EvapParams(; a_s=_as_t, tau_bg=10.0, K3=1e-40)
        base = _euv3_ramp_t()
        scs = robustness_scenarios(trap, p; N0=2e6, T0=40e-6, power_frac=0.12, T0_frac=0.1)
        nom = optimize_ramp_monotone(trap, p, base; N0=2e6, T0=40e-6,
            n_sweeps=3, n_line=9, restarts=1, seed=2)
        rob = optimize_ramp_robust(trap, p, base; N0=2e6, T0=40e-6, scenarios=scs,
            n_sweeps=3, n_line=9, restarts=1, seed=2)
        # missed BEC ⇒ 0 atoms (NaN in the report), which is ≤ any positive worst-case N_BEC
        worst_nom = minimum(r -> r.reached_bec ? r.N_BEC : 0.0,
            robustness_report(trap, p, nom.ramp; N0=2e6, T0=40e-6, scenarios=scs))
        # robust optimum is never worse than the nominal optimum in the worst case
        @test rob.worst >= worst_nom - 1.0
    end

    @testset "summary exposes eta_start + cooled; N_BEC=NaN when not reached" begin
        trap = _eu_trap_t()
        p = EvapParams(; a_s=_as_t, tau_bg=10.0, K3=0.0)
        # deep static trap ⇒ no evaporation, no cooling, no BEC (only background N decay)
        deep = FortRamp([0.0, 1.0], [50.0 50.0; 50.0 50.0; 50.0 50.0])
        s = evaporation_summary(run_evaporation(trap, deep, p; N0=2e6, T0=40e-6, dt=1e-3))
        @test !s.reached_bec
        @test isnan(s.N_BEC)                               # no BEC ⇒ NaN, not leftover N
        @test !s.cooled                                    # T held (background loss ≠ cooling)
        @test s.eta_start > 4                              # deep trap ⇒ high η
        # a ramp that does reach BEC reports finite N_BEC + cooled
        s2 = evaporation_summary(run_evaporation(trap, _euv3_ramp_t(), p; N0=2e6, T0=40e-6))
        @test s2.reached_bec && isfinite(s2.N_BEC) && s2.cooled
    end
end
