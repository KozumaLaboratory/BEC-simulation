# --- Evaporation ramp + RK4 integrator ---
#
# `FortRamp` is the piecewise-linear FORT power schedule per beam (Watts). At each
# step the instantaneous powers rebuild a `CrossedDipoleTrap`, from which
# `crossed_trap_depth` / `mean_trap_frequency` give (U, ω̄) for `evap_rhs`. The
# (N, T) ODEs are advanced with a fixed-step RK4 (the system is 2-D and runs in
# milliseconds — a dependency on an external ODE package is unwarranted). The run
# stops at the BEC onset (PSD ≥ ζ(3)) or when η drops below the validity floor.

export FortRamp, fort_power_at, trap_at, run_evaporation, evaporation_summary

"""
    FortRamp(times, powers_W)

Piecewise-linear power schedule: `times` [s] are shared breakpoints (ascending),
`powers_W` is `n_beams × length(times)` in Watts. Linearly interpolated, clamped
to the endpoints outside the range.
"""
struct FortRamp
    times::Vector{Float64}
    powers_W::Matrix{Float64}
    function FortRamp(times::AbstractVector, powers_W::AbstractMatrix)
        length(times) == size(powers_W, 2) ||
            throw(ArgumentError("powers_W must be n_beams × length(times)"))
        issorted(times) || throw(ArgumentError("times must be ascending"))
        new(collect(Float64, times), Matrix{Float64}(powers_W))
    end
end

ramp_duration(r::FortRamp) = r.times[end] - r.times[1]

"""
    fort_power_at(ramp, t) -> Vector{Float64}

Per-beam powers [W] at time `t`, linearly interpolated (clamped at the ends).
"""
function fort_power_at(ramp::FortRamp, t::Float64)
    ts = ramp.times
    nb = size(ramp.powers_W, 1)
    t <= ts[1] && return ramp.powers_W[:, 1]
    t >= ts[end] && return ramp.powers_W[:, end]
    j = searchsortedlast(ts, t)
    f = (t - ts[j]) / (ts[j + 1] - ts[j])
    [ramp.powers_W[b, j] * (1 - f) + ramp.powers_W[b, j + 1] * f for b in 1:nb]
end

# Build the instantaneous CrossedDipoleTrap from geometry + powers.
function _trap_from_powers(trap::EvapTrap, powers::Vector{Float64})
    beams = [
        GaussianBeam(
            trap.wavelength, max(powers[b], 0.0), trap.waists[b],
            trap.positions[b], trap.directions[b])
        for b in 1:n_beams(trap)
    ]
    CrossedDipoleTrap(beams, trap.alpha)
end

"""
    trap_at(trap, powers) -> (U, ω̄)

Instantaneous trap depth `U` [J] and mean frequency `ω̄` [rad/s] at the given
per-beam powers [W].
"""
function trap_at(trap::EvapTrap, powers::Vector{Float64})
    cdt = _trap_from_powers(trap, powers)
    (crossed_trap_depth(cdt, trap.mass; gravity_axis=trap.gravity_axis),
        mean_trap_frequency(cdt, trap.mass))
end

# (U, ω̄) at a time along the ramp.
_trap_at_time(trap::EvapTrap, ramp::FortRamp, t::Float64) =
    trap_at(trap, fort_power_at(ramp, t))

"""
    run_evaporation(trap, ramp, p; N0, T0, dt=ramp_duration/3000, save_every=10) -> EvapResult

Integrate the (N, T) evaporation ODEs over the FORT ramp with fixed-step RK4.
Stops at BEC onset (PSD ≥ ζ(3), interpolated) or when η < `p.eta_min` everywhere
(evaporation stalled). `N0` initial atom number, `T0` initial temperature [K].
"""
function run_evaporation(
    trap::EvapTrap, ramp::FortRamp, p::EvapParams;
    N0::Float64, T0::Float64, dt::Float64=ramp_duration(ramp) / 3000, save_every::Int=10)
    m = trap.mass
    t0 = ramp.times[1]
    tend = ramp.times[end]
    nsteps = max(1, ceil(Int, (tend - t0) / dt))

    ts = Float64[]
    Ns = Float64[]
    Ts = Float64[]
    ηs = Float64[]
    ρs = Float64[]
    γs = Float64[]
    ω̄s = Float64[]
    Us = Float64[]

    N = N0
    T = T0
    t = t0
    reached = false
    N_BEC = N0
    T_BEC = T0
    t_BEC = tend

    rhs(Nv, Tv, U, ω̄) = evap_rhs(Nv, Tv, U, ω̄, p, m)

    # Precompute (U, ω̄) on a fine time grid and linearly interpolate during the RK4:
    # the trap-DEPTH scan is the per-substep cost, but the ramp is piecewise-linear so
    # (U(t), ω̄(t)) are smooth and a dense grid is exact — turns ~12k depth scans into ~ngrid.
    ngrid = clamp(8 * length(ramp.times) + nsteps ÷ 20, 120, 400)
    tg = collect(range(t0, tend; length=ngrid))
    Ug = Vector{Float64}(undef, ngrid)
    ωg = Vector{Float64}(undef, ngrid)
    for i in 1:ngrid
        Ug[i], ωg[i] = _trap_at_time(trap, ramp, tg[i])
    end
    dtg = ngrid > 1 ? (tend - t0) / (ngrid - 1) : 1.0
    @inline function trap_interp(tq::Float64)
        tq <= t0 && return (Ug[1], ωg[1])
        tq >= tend && return (Ug[ngrid], ωg[ngrid])
        j = clamp(floor(Int, (tq - t0) / dtg) + 1, 1, ngrid - 1)
        f = (tq - (t0 + (j - 1) * dtg)) / dtg
        (Ug[j] * (1 - f) + Ug[j + 1] * f, ωg[j] * (1 - f) + ωg[j + 1] * f)
    end

    function record!(U, ω̄)
        η = U / (Units.KB * T)
        n0 = N * (m * ω̄^2 / (2π * Units.KB * T))^1.5
        γel = n0 * (8π * p.a_s^2) * sqrt(8 * Units.KB * T / (π * m)) / sqrt(2)
        push!(ts, t)
        push!(Ns, N)
        push!(Ts, T)
        push!(ηs, η)
        push!(ρs, phase_space_density(N, T, ω̄))
        push!(γs, γel)
        push!(ω̄s, ω̄)
        push!(Us, U)
    end

    U, ω̄ = trap_interp(t)
    record!(U, ω̄)

    for s in 1:nsteps
        h = min(dt, tend - t)
        h <= 0 && break
        # RK4 with trap (U, ω̄) sampled at t, t+h/2, t+h
        U1, ω1 = trap_interp(t)
        k1N, k1T = rhs(N, T, U1, ω1)
        Um, ωm = trap_interp(t + h / 2)
        k2N, k2T = rhs(N + h / 2 * k1N, T + h / 2 * k1T, Um, ωm)
        k3N, k3T = rhs(N + h / 2 * k2N, T + h / 2 * k2T, Um, ωm)
        U2, ω2 = trap_interp(t + h)
        k4N, k4T = rhs(N + h * k3N, T + h * k3T, U2, ω2)

        N_new = N + h / 6 * (k1N + 2k2N + 2k3N + k4N)
        T_new = T + h / 6 * (k1T + 2k2T + 2k3T + k4T)
        N_new = max(N_new, 1.0)
        T_new = max(T_new, 1e-12)

        # BEC-onset crossing on the post-step trap
        ρ_old = phase_space_density(N, T, ω2)
        ρ_new = phase_space_density(N_new, T_new, ω2)
        if !reached && ρ_new >= _ZETA3 > ρ_old
            f = (_ZETA3 - ρ_old) / (ρ_new - ρ_old)
            N_BEC = N + f * (N_new - N)
            T_BEC = T + f * (T_new - T)
            t_BEC = t + f * h
            reached = true
        end

        N, T, t = N_new, T_new, t + h
        (s % save_every == 0 || s == nsteps || reached) && record!(U2, ω2)
        reached && break
    end

    if !reached
        N_BEC, T_BEC, t_BEC = N, T, t
    end

    # efficiency γ_eff = -d ln ρ / d ln N over the run (first → last sample)
    γ_eff = if length(ρs) >= 2 && ρs[1] > 0 && ρs[end] > 0 && Ns[1] != Ns[end]
        -(log(ρs[end]) - log(ρs[1])) / (log(Ns[end]) - log(Ns[1]))
    else
        NaN
    end

    EvapResult(ts, Ns, Ts, ηs, ρs, γs, ω̄s, Us, N_BEC, T_BEC, t_BEC, reached, γ_eff)
end

"""
    evaporation_summary(result) -> NamedTuple

Condensed human-readable metrics of an `EvapResult`: BEC reached?, atom number,
temperature [µK], onset time [s], efficiency `γ_eff = -dlnρ/dlnN`, the surviving
fraction `N_BEC/N₀`, the peak phase-space density, and the η at onset.
"""
function evaporation_summary(r::EvapResult)
    (reached_bec=r.reached_bec,
        N_BEC=r.N_BEC,
        T_BEC_uK=r.T_BEC * 1e6,
        t_BEC_s=r.t_BEC,
        gamma_eff=r.gamma_eff,
        survival=isempty(r.N) ? NaN : r.N_BEC / r.N[1],
        peak_psd=isempty(r.psd) ? NaN : maximum(r.psd),
        eta_onset=isempty(r.eta) ? NaN : r.eta[end])
end
