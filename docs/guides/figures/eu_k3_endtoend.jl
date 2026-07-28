# SHOWS: end-to-end K3 recovery — synthetic BEC-decay data → fit → σ(K3) vs ω̄-calibration error.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Experimental campaign" — K3 end-to-end).
# REPLACES: nothing (new; turns the K3 sensitivity claim into an end-to-end recovery test).
# K3 end-to-end: generate a synthetic BEC 3-body decay N0(t) at a KNOWN ω̄, add realistic
# atom-number noise, fit the analytic pure-3-body law to recover K3, and report σ(K3)/K3 —
# including the propagated error from an imperfect ω̄ calibration. Validates the ±20% claim
# (sensitivity study only, so far) end-to-end.

using SpinorBEC, Printf, Random
const SB = SpinorBEC
const BOHR = 5.29177210903e-11
const OUT = length(ARGS) >= 1 ? ARGS[1] : "k3e2e_out"; mkpath(OUT)

# physical setup: a held Eu BEC, known trap, direct-measured K3.
m = SB.Eu151.mass; a_s = 135 * BOHR; K3_true = 1.2e-41
ωbar = 2π * 150.0                       # known trap (from the dipole-mode measurement)
N0_0 = 1.5e4                            # initial condensate

# per-atom condensate 3-body rate γ(N0) = K3·(8/21)·n0²  (repo's _condensate_three_body_rate),
# n0 the TF peak density ∝ ω̄^{6/5} N0^{2/5} a_s^{-3/5}. dN0/dt = -γ(N0)·N0.
p = SB.EvapParams(; a_s=a_s, tau_bg=Inf, K3=K3_true)
rate(N0, ω) = SB._condensate_three_body_rate(N0, ω, p, m)   # per-atom γ

# integrate the decay (RK4) at the TRUE ω̄
function decay(N0_0, ω; K3fac=1.0, tmax=3.0, dt=0.001)
    pp = SB.EvapParams(; a_s=a_s, tau_bg=Inf, K3=K3_true * K3fac)
    r(N0) = SB._condensate_three_body_rate(N0, ω, pp, m) * N0
    ts = Float64[]; Ns = Float64[]; t = 0.0; N = N0_0
    push!(ts, t); push!(Ns, N)
    for _ in 1:round(Int, tmax / dt)
        k1 = -r(N); k2 = -r(max(N + dt / 2 * k1, 1.0)); k3 = -r(max(N + dt / 2 * k2, 1.0))
        k4 = -r(max(N + dt * k3, 1.0)); N = max(N + dt / 6 * (k1 + 2k2 + 2k3 + k4), 1.0)
        t += dt; push!(ts, t); push!(Ns, N)
    end
    ts, Ns
end

# sample at n_shots times, add relative atom-number noise
function synth(ts, Ns; n_shots, noise, rng)
    idx = round.(Int, range(1, length(ts); length=n_shots))
    t = ts[idx]; N = Ns[idx] .* (1 .+ noise .* randn(rng, n_shots))
    t, max.(N, 1.0)
end

# fit: grid-search K3-multiplier that best matches the decay at the ASSUMED ω̄ (may be mis-calibrated)
function fit_K3(t_data, N_data, N0_0, ω_assumed; facs=10 .^ range(-0.7, 0.7; length=141))
    best = (Inf, 1.0)
    for f in facs
        ts, Ns = decay(N0_0, ω_assumed; K3fac=f, tmax=maximum(t_data) + 0.01, dt=0.002)
        # interpolate model at data times
        pred = [Ns[searchsortedlast(ts, tq)] for tq in t_data]
        resid = sum(((pred .- N_data) ./ N_data) .^ 2)
        resid < best[1] && (best = (resid, f))
    end
    best[2]
end

ts, Ns = decay(N0_0, ωbar)
@printf("true decay: N0 %.1e → %.1e over 3 s (K3=%.2e, ω̄=2π·%.0f)\n", Ns[1], Ns[end], K3_true, ωbar / 2π)

rng = MersenneTwister(7)
open(joinpath(OUT, "k3_endtoend.csv"), "w") do io
    println(io, "n_shots,noise,omega_err,sigma_K3_pct")
    for n_shots in [10, 20], noise in [0.03, 0.05], ω_err in [0.0, 0.01, 0.05]
        # MC over noise realizations AND ω̄-calibration error
        facs = Float64[]
        for _ in 1:200
            td, Nd = synth(ts, Ns; n_shots, noise, rng)
            ω_assumed = ωbar * (1 + ω_err * randn(rng))       # mis-calibrated ω̄
            f = fit_K3(td, Nd, N0_0, ω_assumed)
            push!(facs, f)
        end
        mean = sum(facs) / length(facs)
        sig = sqrt(sum((facs .- mean) .^ 2) / (length(facs) - 1))
        @printf("n=%2d noise=%.0f%% ω_err=%.0f%%: K3 recovered %.2f±%.2f (σ=%.1f%%)\n",
            n_shots, 100noise, 100ω_err, mean, sig, 100sig)
        @printf(io, "%d,%.3f,%.3f,%.4f\n", n_shots, noise, ω_err, 100sig)
        flush(stdout)
    end
end
println("done → ", OUT)
