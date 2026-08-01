#!/usr/bin/env julia
# Time to solution at fixed accuracy — both halves measured on the SAME problem.
#
#     julia --project=. scripts/validation/rk4ip_time_to_solution_gpu.jl [n]
#
# The first pass at this divided a step-size ratio measured on a 12^3 CPU config
# by a cost ratio measured on a 128^3 GPU config. Those do not compose. The
# step size an integrator holds at a fixed error budget is hardware-independent
# but strongly SIZE-dependent: Strang's leading error carries [K,[K,V]], which
# grows with k_max^2, so at fixed box a 12 -> 128 refinement multiplies it by
# ~1e2 while RK4IP's 4th-order constant moves differently. With
#   dt_strang ~ (eps/C2)^(1/2),  dt_rk4ip ~ (eps/C4)^(1/4)
# the RATIO of the two is not a constant of the method. It has to be measured
# where the cost is measured.
#
# So this measures, at ONE n on ONE device:
#   * error vs dt for both integrators, against a common fine reference
#   * ms/step for both
#   * the largest dt each holds per error budget, and the resulting
#     time-to-solution ratio
#
# It also reports the comparison at FIXED dt, which is the one that matters when
# the accuracy axis is already saturated — as it is for the Matsui Fig. 4B
# observable, where dt = 1e-3 is converged to 1e-4 nT and any extra accuracy is
# unspendable.

import CUDA
using SpinorBEC
using LinearAlgebra
using Printf

const N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 64
const T = 0.05
const PRODUCTION_DT = 1e-3

function build(dt::Float64)
    grid = make_grid(GridConfig(ntuple(_ -> N, 3), ntuple(_ -> 16.0, 3)))
    make_workspace(;
        grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 4687.2663 / 50, 1 => -0.5)),
        zeeman=ZeemanParams(0.4, 0.02),
        potential=HarmonicTrap((1.0, 1.0, 1.181818)),
        sim_params=SimParams(; dt=dt, n_steps=max(1, round(Int, T / dt)), save_every=10^9),
        enable_ddi=true, c_dd=147.715012, secular_ddi=false, ddi_padding=true,
        backend=CUDABackend(),
    )
end

psi0(ws) = init_psi(ws.grid, ws.spin_matrices.system;
    state=:spin_coherent, init_theta=0.35, init_phi=0.2)

function evolve(stepper, p0, dt)
    ws = build(dt)
    copyto!(ws.state.psi, p0)
    ws.state.t = 0.0
    for _ in 1:(ws.sim_params.n_steps)
        stepper(ws)
    end
    CUDA.synchronize()
    Array(ws.state.psi)
end

function ms_per_step(stepper, dt, reps)
    ws = build(dt)
    copyto!(ws.state.psi, psi0(ws))
    for _ in 1:3
        stepper(ws)
    end
    CUDA.synchronize()
    best = Inf
    for _ in 1:3
        CUDA.synchronize()
        t = @elapsed begin
            for _ in 1:reps
                stepper(ws)
            end
            CUDA.synchronize()
        end
        best = min(best, t / reps)
    end
    CUDA.reclaim()
    1e3 * best
end

# Largest dt holding `budget`, interpolated between the two bracketing samples.
# Refuses to extrapolate past the sampled range.
function crossing(dts, errs, budget)
    ok = [i for i in eachindex(errs) if isfinite(errs[i])]
    length(ok) >= 2 || return (NaN, :nodata)
    lo = findlast(i -> errs[i] <= budget, ok)
    lo === nothing && return (NaN, :budget_below_every_sample)
    i = ok[lo]
    # Under budget even at the COARSEST sample: the true crossing is somewhere
    # past the sweep, so this is a LOWER BOUND, not a measurement. Reporting it
    # as a crossing silently turns "we did not look far enough" into a number.
    lo == length(ok) && return (dts[i], :capped)
    j = ok[lo + 1]
    p = log(errs[j] / errs[i]) / log(dts[j] / dts[i])
    (dts[i] * (budget / errs[i])^(1 / p), :interpolated)
end

function main()
    CUDA.functional() || error("CUDA not functional")
    @printf("device: %s\n", CUDA.name(CUDA.device()))
    @printf("Eu F=6 D=13, %d^3 box 16, DDI on + padded, T = %.3f\n\n", N, T)

    p0 = ComplexF64.(psi0(build(PRODUCTION_DT)))

    ref = evolve(rk4ip_step!, p0, T / 4096)
    ref_half = evolve(rk4ip_step!, p0, T / 2048)
    ref_err = norm(ref .- ref_half) / norm(ref) / 15
    @printf("reference RK4IP at dt = %.2e; Richardson bound on its own error %.2e\n\n",
        T / 4096, ref_err)

    steps = [T / k for k in (512, 256, 128, 64, 32, 16, 8, 4)]
    errs = Dict(:rk4ip => Float64[], :strang => Float64[])
    @printf("%12s %16s %16s\n", "dt", "rk4ip err", "split_step! err")
    for dt in steps
        row = Any[@sprintf("%12.2e", dt)]
        for (k, st) in ((:rk4ip, rk4ip_step!), (:strang, split_step!))
            e = try
                v = norm(evolve(st, p0, dt) .- ref) / norm(ref)
                isfinite(v) && v >= 10 * ref_err ? v : NaN
            catch
                NaN
            end
            push!(errs[k], e)
            push!(row, isfinite(e) ? @sprintf("%16.3e", e) : rpad("   <ref / diverged", 16))
        end
        println(join(row, " "))
        CUDA.reclaim()
    end

    reps = N >= 128 ? 6 : 20
    c_rk = ms_per_step(rk4ip_step!, PRODUCTION_DT, reps)
    c_ss = ms_per_step(split_step!, PRODUCTION_DT, reps)
    @printf("\nms/step at this n:  split_step! %.2f   rk4ip %.2f   (rk4ip / split = %.2fx)\n",
        c_ss, c_rk, c_rk / c_ss)

    println("\n--- AXIS 1: fixed dt. Relevant when the accuracy needed is already met. ---")
    i = argmin(abs.(steps .- PRODUCTION_DT))
    @printf("at dt = %.2e (nearest sampled to production's %.0e):\n", steps[i], PRODUCTION_DT)
    @printf("  rk4ip is %.1fx more accurate and %.2fx the cost per step\n",
        errs[:strang][i] / errs[:rk4ip][i], c_rk / c_ss)
    println("  If that accuracy is not needed, this is a pure loss.")

    println("\n--- AXIS 2: fixed accuracy. Time to solution. ---")
    @printf("%12s %14s %14s %14s   %s\n",
        "budget", "rk4ip dt", "split dt", "time ratio", "quality")
    for b in (1e-3, 1e-4, 1e-5, 1e-6, 1e-7)
        a, qa = crossing(steps, errs[:rk4ip], b)
        s, qs = crossing(steps, errs[:strang], b)
        r = (a / s) / (c_rk / c_ss)
        q = (qa === :interpolated && qs === :interpolated) ? "measured" :
            (qa === :capped || qs === :capped) ? "LOWER BOUND ($qa/$qs)" : "$qa/$qs"
        @printf("%12.0e %14.3e %14.3e %14s   %s\n", b, a, s,
            isfinite(r) ? @sprintf("%.2fx", r) : "—", q)
    end
    println("\n>1 means rk4ip reaches that accuracy sooner. Both columns are measured")
    println("HERE, at this n on this device — the previous write-up divided a 12^3 CPU")
    println("step ratio by a 128^3 GPU cost ratio, which does not compose.")
end

main()
