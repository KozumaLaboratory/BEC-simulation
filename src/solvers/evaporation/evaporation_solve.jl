# --- Evaporation ramp + RK4 integrator ---
#
# `FortRamp` is the piecewise-linear FORT power schedule per beam (Watts). At each
# step the instantaneous powers rebuild a `CrossedDipoleTrap`, from which
# `crossed_trap_depth` / `mean_trap_frequency` give (U, ω̄) for `evap_rhs`. The
# (N, T) ODEs are advanced with a fixed-step RK4 (the system is 2-D and runs in
# milliseconds — a dependency on an external ODE package is unwarranted). The run
# stops at the BEC onset (PSD ≥ ζ(3)) or when η drops below the validity floor.

export FortRamp, fort_power_at, trap_at, run_evaporation, evaporation_summary
export evaporation_diagnostics

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
    (
        crossed_trap_depth(cdt, trap.mass; gravity_axis=trap.gravity_axis,
            gravity_factor=trap.gravity_factor),
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

    rhs(Nv, Tv, U, ω̄, dlnω) = evap_rhs(Nv, Tv, U, ω̄, p, m; dlnω_dt=dlnω)

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
    # returns (U, ω̄, dlnω̄/dt); the trap grid is piecewise-linear so dω̄/dt is the
    # local segment slope (zero outside the ramp where the trap is clamped).
    @inline function trap_interp(tq::Float64)
        tq <= t0 && return (Ug[1], ωg[1], 0.0)
        tq >= tend && return (Ug[ngrid], ωg[ngrid], 0.0)
        j = clamp(floor(Int, (tq - t0) / dtg) + 1, 1, ngrid - 1)
        f = (tq - (t0 + (j - 1) * dtg)) / dtg
        ω = ωg[j] * (1 - f) + ωg[j + 1] * f
        dlnω = ω > 0 ? ((ωg[j + 1] - ωg[j]) / dtg) / ω : 0.0
        (Ug[j] * (1 - f) + Ug[j + 1] * f, ω, dlnω)
    end

    function record!(U, ω̄)
        η = U / (Units.KB * T)
        n0 = thermal_peak_density(N, T, ω̄, m)
        γel = n0 * (8π * p.a_s^2) * sqrt(8 * Units.KB * T / (π * m))   # LRW n_pk σ v̄ (no /√2)
        push!(ts, t)
        push!(Ns, N)
        push!(Ts, T)
        push!(ηs, η)
        push!(ρs, phase_space_density(N, T, ω̄))
        push!(γs, γel)
        push!(ω̄s, ω̄)
        push!(Us, U)
    end

    U, ω̄, _ = trap_interp(t)
    record!(U, ω̄)

    for s in 1:nsteps
        h = min(dt, tend - t)
        h <= 0 && break
        # RK4 with trap (U, ω̄, dlnω̄/dt) sampled at t, t+h/2, t+h
        U1, ω1, dω1 = trap_interp(t)
        k1N, k1T = rhs(N, T, U1, ω1, dω1)
        Um, ωm, dωm = trap_interp(t + h / 2)
        k2N, k2T = rhs(N + h / 2 * k1N, T + h / 2 * k1T, Um, ωm, dωm)
        k3N, k3T = rhs(N + h / 2 * k2N, T + h / 2 * k2T, Um, ωm, dωm)
        U2, ω2, dω2 = trap_interp(t + h)
        k4N, k4T = rhs(N + h * k3N, T + h * k3T, U2, ω2, dω2)

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

Condensed human-readable metrics of an `EvapResult`: BEC reached?, atom number
(`NaN` when BEC is not reached — `r.N_BEC` is the final non-condensed `N` then),
temperature [µK], onset time [s], efficiency `γ_eff = -dlnρ/dlnN`, the surviving
fraction `N_BEC/N₀`, the peak phase-space density, the η at onset, the η at the
*loaded start* (`eta_start` — if ≲ `eta_min` evaporation can't even begin: a shallow
loaded trap, NOT a ramp problem), and whether the gas cooled at all (`cooled` — a deep
static trap with only background loss decays `N` but keeps `T`, so `cooled=false`).
"""
function evaporation_summary(r::EvapResult)
    reached = r.reached_bec
    (reached_bec=reached,
        N_BEC=reached ? r.N_BEC : NaN,
        T_BEC_uK=r.T_BEC * 1e6,
        t_BEC_s=r.t_BEC,
        gamma_eff=r.gamma_eff,
        survival=(reached && !isempty(r.N)) ? r.N_BEC / r.N[1] : NaN,
        peak_psd=isempty(r.psd) ? NaN : maximum(r.psd),
        eta_onset=isempty(r.eta) ? NaN : r.eta[end],
        eta_start=isempty(r.eta) ? NaN : r.eta[1],
        cooled=length(r.T) >= 2 && r.T[end] < r.T[1] * (1 - 1e-6))
end

# trapezoidal ∫ y dx over matching vectors
function _trapz(x::Vector{Float64}, y::Vector{Float64})
    s = 0.0
    @inbounds for i in 2:length(x)
        s += 0.5 * (y[i] + y[i - 1]) * (x[i] - x[i - 1])
    end
    s
end

"""
    evaporation_diagnostics(r, trap, p) -> NamedTuple

Standard evaporative-cooling figures of merit from an `EvapResult` — the questions an
experimentalist asks *before* trusting a ramp, independent of whether it happened to
reach BEC:

- `eta_start` / `eta_min` — the truncation at the loaded start and its minimum over the
  run. `eta_start ≲ eta_min(model) = 4` means the loaded trap is too shallow to evaporate
  at all (raise the depth or lower `T₀`), NOT a ramp the optimizer can fix.
- `collision_ratio_R = γ_el / (1/τ_bg + K₃⟨n²⟩)` at the start — the **good-to-bad
  collision ratio**. Runaway evaporation needs `R` large (≳ 10²–10³); `R ≲ 50` means
  background/3-body losses outrun elastic rethermalisation and evaporation stalls.
- `gamma_el_start` / `gamma_el_peak` [1/s] — the elastic collision rate (sets the timescale).
- `collisions_per_atom = ∫ γ_el dt` — total elastic collisions per atom over the ramp; a
  few hundred is healthy, ≲ 10 is collisionally limited (too fast for the density).
- `gamma_eff = −dlnρ/dlnN` — the realised efficiency; `runaway` — did ρ actually rise to BEC.

`R` and `collisions_per_atom` are the model's answer to "is this trap configuration
*capable* of runaway evaporation?", which `optimize_ramp_*` cannot change (they reshape
the ramp, not the trap depth / collision rate).
"""
function evaporation_diagnostics(r::EvapResult, trap::EvapTrap, p::EvapParams)
    isempty(r.t) && return (eta_start=NaN, eta_min=NaN, collision_ratio_R=NaN,
        gamma_el_start=NaN, gamma_el_peak=NaN, collisions_per_atom=NaN,
        gamma_eff=r.gamma_eff, runaway=false)
    m = trap.mass
    kB = Units.KB
    n0_start = r.N[1] * (m * r.omega_bar[1]^2 / (2π * kB * r.T[1]))^1.5
    loss_start = 1.0 / p.tau_bg + p.K3 * n0_start^2 / 3.0^1.5     # per-atom bad-event rate
    R_start = loss_start > 0 ? r.gamma_el[1] / loss_start : Inf
    (eta_start=r.eta[1],
        eta_min=minimum(r.eta),
        collision_ratio_R=R_start,
        gamma_el_start=r.gamma_el[1],
        gamma_el_peak=maximum(r.gamma_el),
        collisions_per_atom=_trapz(r.t, r.gamma_el),
        gamma_eff=r.gamma_eff,
        runaway=length(r.psd) >= 2 && r.psd[end] > r.psd[1] && r.reached_bec)
end
