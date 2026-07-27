# SHOWS: dipole-mode ω̄ measurement precision — σ(ω̄)/ω̄ vs shots/noise; 1% is easily reachable.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Experimental campaign" — do-first: measure ω̄ to 1%).
# REPLACES: nothing (new; validates the K3 density-calibration unblocker).
# ω̄ measurement precision: dipole-mode spectroscopy. Displace a scalar GS by a small
# amount along one axis, evolve in the trap (ω known = 1 in internal units), record the
# center-of-mass x(t) at a finite set of imaging times with realistic per-shot noise, fit
# x(t)=A sin(ωt+φ), and report σ(ω)/ω vs {n_shots, noise, span}. This quantifies whether
# the "measure ω̄ to 1%" premise is achievable.

using SpinorBEC, Printf, Random, LinearAlgebra
const SB = SpinorBEC

const NPTS = (48, 24, 24)
const BOX = (24.0, 16.0, 16.0)
const OMEGA_TRUE = 1.0                     # internal units: ω_ref = 1 ⇒ trap ω = 1 exactly

# scalar (1-component) GS in an isotropic-ish harmonic trap
function ground_state()
    grid = SB.make_grid(SB.GridConfig(NPTS, BOX))
    pot = SB.HarmonicTrap{3}((OMEGA_TRUE, OMEGA_TRUE, OMEGA_TRUE))
    inter = SB.InteractionParams(Dict{Int,Float64}(0 => 50.0))   # modest MF, scalar
    res = SB.find_ground_state(; grid, atom=SB.Rb87, interactions=inter,
        potential=pot, dt=0.002, n_steps=1500, tol=1e-9,
        initial_state=:m_minus_F, verbose=false)
    grid, pot, inter, res.workspace.state.psi
end

# center-of-mass along x from a (spatial..., 1) field
function com_x(psi, grid)
    dV = prod(step.(grid.x))
    xs = grid.x[1]
    n = dropdims(sum(abs2, psi; dims=4); dims=4)   # spatial density
    N = sum(n) * dV
    num = 0.0
    @inbounds for I in CartesianIndices(n)
        num += xs[I[1]] * n[I]
    end
    (num * dV) / N
end
step(v) = length(v) > 1 ? v[2] - v[1] : 1.0

# displace the GS by dx along x (roll via phase-free spatial shift: interpolate)
function displaced(psi, grid, dx)
    xs = grid.x[1]; h = step(xs); shift = round(Int, dx / h)
    circshift(psi, (shift, 0, 0, 0))
end

# evolve, record COM at snapshot times
function trajectory(grid, pot, inter, psi0; n_steps, save_every, dt=0.01)
    sp = SB.SimParams(; dt, n_steps, imaginary_time=false, save_every, normalize_every=0)
    ws = SB.make_workspace(; grid, atom=SB.Rb87, interactions=inter,
        zeeman=SB.ZeemanParams(0.0, 0.0), potential=pot, sim_params=sp, psi_init=copy(psi0))
    ts = Float64[]; xc = Float64[]
    cb = SB.SimulationCallbacks(; on_snapshot=function(w, step, snap)
        push!(ts, w.state.t); push!(xc, com_x(w.state.psi, grid))
    end)
    SB.run_simulation!(ws; callbacks=cb)
    ts, xc
end

# fit x(t) = A sin(ω t + φ) + c by grid-search ω then linear LSQ for (A sinφ, A cosφ, c)
function fit_omega(ts, xs; ωgrid=range(0.6, 1.4; length=1601))
    best = (Inf, 1.0)
    for ω in ωgrid
        M = hcat(sin.(ω .* ts), cos.(ω .* ts), ones(length(ts)))
        coef = M \ xs
        resid = sum((M * coef .- xs) .^ 2)
        resid < best[1] && (best = (resid, ω))
    end
    best[2]
end

# Monte-Carlo σ(ω) for a measurement config: add per-shot COM noise, refit.
function omega_precision(ts, xc_clean, A; com_noise, n_mc, rng)
    ωs = Float64[]
    for _ in 1:n_mc
        noisy = xc_clean .+ com_noise .* randn(rng, length(xc_clean))
        push!(ωs, fit_omega(ts, noisy))
    end
    (mean=sum(ωs) / length(ωs), sigma=std(ωs))
end
mean(v) = sum(v) / length(v)
std(v) = (m = mean(v); sqrt(sum((v .- m) .^ 2) / max(length(v) - 1, 1)))

const OUT = length(ARGS) >= 1 ? ARGS[1] : "omega_out"; mkpath(OUT)
const SMOKE = length(ARGS) >= 2 && ARGS[2] == "smoke"

grid, pot, inter, psi_gs = ground_state()
dx = 1.0                                    # displacement amplitude (h.o. units); COM amp ≈ dx
psi0 = displaced(psi_gs, grid, dx)
# evolve over a few periods (period = 2π/ω = 2π); sample densely, then subsample to n_shots
Tspan = SMOKE ? 2π * 1.0 : 2π * 3.0         # 1 or 3 trap periods
dt = 0.01; n_steps = round(Int, Tspan / dt); save_every = 5
ts, xc = trajectory(grid, pot, inter, psi0; n_steps, save_every, dt)
A = (maximum(xc) - minimum(xc)) / 2
@printf("COM oscillation: amplitude=%.3f, %d dense samples over %.2f periods\n", A, length(ts), Tspan / (2π))
ω_clean = fit_omega(ts, xc)
@printf("clean fit ω=%.5f (true=1.0) ⇒ systematic %.2f%%\n", ω_clean, 100 * (ω_clean - 1))

rng = MersenneTwister(42)
open(joinpath(OUT, "omega_precision.csv"), "w") do io
    println(io, "n_shots,com_noise_frac,span_periods,sigma_omega_pct")
    shot_list = SMOKE ? [10] : [6, 10, 15, 20, 30]
    noise_list = SMOKE ? [0.05] : [0.02, 0.05, 0.10]
    for n_shots in shot_list, noise in noise_list
        idx = round.(Int, range(1, length(ts); length=n_shots))
        tss = ts[idx]; xcs = xc[idx]
        com_noise = noise * A                # per-shot COM error as a fraction of amplitude
        r = omega_precision(tss, xcs, A; com_noise, n_mc=(SMOKE ? 30 : 400), rng)
        @printf("n_shots=%2d noise=%.0f%% span=%.0fT: σ(ω)/ω = %.2f%%\n",
            n_shots, 100 * noise, Tspan / (2π), 100 * r.sigma)
        @printf(io, "%d,%.3f,%.1f,%.4f\n", n_shots, noise, Tspan / (2π), 100 * r.sigma)
        flush(stdout)
    end
end
println("done → ", joinpath(OUT, "omega_precision.csv"))
