#!/usr/bin/env julia
# How far can RK4IP stretch the step, and where does it break?
#
#     julia --project=. scripts/validation/rk4ip_step_size_probe.jl [n]
#
# The Fig. 4B campaign established that `dt = 1e-3` is already converged for that
# observable (refining 4x moves the populations by 8e-5), so RK4IP's payoff there
# is NOT accuracy. The payoff on offer is step size: both integrators cost 4
# mean-field evaluations per step, so if RK4IP holds its error at a `dt` where
# Strang does not, it is that ratio faster for the same answer.
#
# This measures, against a common dt/64 reference, on an Eu-like dipolar config:
#   - relative L2 error in psi at T
#   - norm drift  (RK4IP is not norm-conserving; Strang is, to round-off, so a
#     norm check alone would flatter Strang and say nothing about accuracy)
#
# Reported as the largest dt each integrator holds under a fixed error budget.
# Anything that returns non-finite is a hard stability failure and says so.

using SpinorBEC
using LinearAlgebra
using Printf

const N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 16
const L = 12.0
const T = 0.2                       # ~0.3 ms at omega_ref = 691 rad/s
const ERR_BUDGET = 1e-4             # relative L2, the level Fig. 4B needed

function build(dt)
    grid = make_grid(GridConfig(ntuple(_ -> N, 3), ntuple(_ -> L, 3)))
    make_workspace(;
        grid,
        atom=Eu151,
        interactions=InteractionParams(Dict(0 => 4687.2663 / 50, 1 => -0.5)),
        zeeman=ZeemanParams(0.4, 0.02),
        potential=HarmonicTrap((1.0, 1.0, 1.181818)),
        sim_params=SimParams(; dt=dt, n_steps=max(1, round(Int, T / dt)), save_every=10^9),
        enable_ddi=true,
        c_dd=147.715012,
        secular_ddi=false,
        backend=CPUBackend(),
    )
end

function psi0(ws)
    ComplexF64.(
        init_psi(ws.grid, ws.spin_matrices.system; state=:spin_coherent,
            init_theta=0.35, init_phi=0.2)
    )
end

function evolve(stepper, p0, dt)
    ws = build(dt)
    copyto!(ws.state.psi, p0)
    ws.state.t = 0.0
    for _ in 1:(ws.sim_params.n_steps)
        stepper(ws)
    end
    Array(ws.state.psi)
end

# Largest dt holding `budget`, from a power law e = C dt^p fitted to the two
# sampled points that bracket the budget. Extrapolating a fitted order past the
# sampled range would be inventing data, so this refuses to.
function crossing(dts, errs, budget)
    ok = [i for i in eachindex(errs) if isfinite(errs[i])]
    length(ok) >= 2 || return (NaN, "no data")
    lo = findlast(i -> errs[i] <= budget, ok)
    lo === nothing && return (NaN, "budget below every sample")
    i = ok[lo]
    lo == length(ok) && return (dts[i], "at the coarse end of the sweep")
    j = ok[lo + 1]
    p = log(errs[j] / errs[i]) / log(dts[j] / dts[i])
    (dts[i] * (budget / errs[i])^(1 / p), @sprintf("order %.2f", p))
end

function main()
    p0 = psi0(build(1e-3))
    n0 = norm(p0)
    @printf("Eu-like %d^3, T = %.2f (omega_ref units), DDI on\n\n", N, T)

    # The reference is RK4IP at T/4096, and it has to be CHECKED or the fine end
    # of the table measures the reference rather than the integrators.
    #
    # The check must be Richardson on the reference's OWN method: comparing it
    # against Strang at the same dt would measure Strang's error, which is orders
    # larger and says nothing about the reference. (That was this script's first
    # version, and it duly fired a warning about a reference that was fine.)
    # At order 4, ||y(h) - y(2h)|| bounds y(h)'s own error by ~1/15 of itself.
    ref = evolve(rk4ip_step!, p0, T / 4096)
    ref_half = evolve(rk4ip_step!, p0, T / 2048)
    ref_err = norm(ref .- ref_half) / norm(ref) / 15
    @printf("reference: RK4IP at dt = %.2e; Richardson bound on its own error %.2e\n",
        T / 4096, ref_err)

    steps = [T / k for k in (1024, 512, 256, 128, 64, 32, 16, 8, 4)]
    errs = Dict(:rk4ip => Float64[], :strang => Float64[])

    @printf("%10s %14s %14s %14s %14s\n",
        "dt", "RK4IP err", "RK4IP |dnorm|", "Strang err", "Strang |dnorm|")
    for dt in steps
        row = Any[@sprintf("%10.2e", dt)]
        for (key, stepper) in ((:rk4ip, rk4ip_step!), (:strang, split_step!))
            local e, dn
            try
                psi = evolve(stepper, p0, dt)
                e = norm(psi .- ref) / norm(ref)
                dn = abs(norm(psi) - n0) / n0
                isfinite(e) || (e = NaN)
            catch err
                e = NaN
                dn = NaN
            end
            # Below the reference's own error the number is the reference, not
            # the integrator. Drop it rather than tabulate it as accuracy.
            isfinite(e) && e < 10 * ref_err && (e = NaN)
            push!(errs[key], e)
            push!(row, isfinite(e) ? @sprintf("%14.3e", e) :
                       rpad(isfinite(dn) ? "  <reference" : "  DIVERGED", 14))
            push!(row, isfinite(dn) ? @sprintf("%14.3e", dn) : rpad("       —", 14))
        end
        println(join(row, " "))
    end

    println("\nlargest dt holding a given error budget (interpolated between samples):")
    @printf("%12s %14s %14s %10s\n", "budget", "RK4IP dt", "Strang dt", "speedup")
    for budget in (1e-3, 1e-4, 1e-5, 1e-6)
        a, na = crossing(steps, errs[:rk4ip], budget)
        b, nb = crossing(steps, errs[:strang], budget)
        @printf("%12.0e %14.3e %14.3e %10s   (%s / %s)\n", budget, a, b,
            isfinite(a / b) ? @sprintf("%.1fx", a / b) : "—", na, nb)
    end

    println("\nCost is 4 mean-field evaluations per step for BOTH, so the dt ratio is")
    println("the wall-clock ratio. RK4IP is not norm-conserving; Strang is to round-off,")
    println("so the norm columns compare methods only within a row, not across.")
end

main()
