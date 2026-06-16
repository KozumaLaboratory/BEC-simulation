# --- Two-component (thermal + condensate) evaporation: the BEC transition ---
#
# The thermal-only `run_evaporation` stops at the BEC onset (PSD ≥ ζ(3)). To follow
# the transition we add the condensate: below T_c the gas splits into a saturated
# thermal cloud and a growing condensate. As evaporation keeps cooling, the thermal
# population N_th = ζ(3)(k_BT/ℏω̄)³ ∝ T³ collapses (the "thermal crash" seen in
# absorption imaging) while the condensate N₀ = N − N_th grows. The condensate is
# dense (Thomas–Fermi), so three-body loss preferentially depletes it — that balance
# sets the final BEC atom number. Reference: standard quasi-static two-component
# evaporation (e.g. Ketterle–van Druten review; Davis–Gardiner rate equations).

export bec_critical_temperature, condensate_split, run_evaporation_bec, EvapBecResult

"""
    bec_critical_temperature(N, ω̄) -> T_c [K]

Harmonic-trap BEC critical temperature `k_B T_c = ℏ ω̄ (N/ζ(3))^{1/3}` for `N` atoms
at geometric-mean frequency `ω̄` [rad/s].
"""
bec_critical_temperature(N::Real, ω̄::Real) =
    (Units.HBAR * ω̄ / Units.KB) * (N / _ZETA3)^(1 / 3)

"""
    condensate_split(N, T, ω̄) -> (N₀, N_th)

Split `N` atoms at temperature `T` in a trap of mean frequency `ω̄` into condensate
`N₀` and thermal `N_th`. Above `T_c` everything is thermal `(0, N)`; below `T_c` the
thermal cloud saturates at `N_th = ζ(3)(k_B T/ℏω̄)³ = N (T/T_c)³` and the rest
condenses, `N₀ = N − N_th`. Continuous at `T_c` (`N_th → N`) and `T → 0` (`N₀ → N`).
"""
function condensate_split(N::Real, T::Real, ω̄::Real)
    (N <= 0 || ω̄ <= 0 || T <= 0) && return (0.0, Float64(max(N, 0.0)))
    Tc = bec_critical_temperature(N, ω̄)
    T >= Tc && return (0.0, Float64(N))
    N_th = _ZETA3 * (Units.KB * T / (Units.HBAR * ω̄))^3
    N_th = min(N_th, Float64(N))
    (Float64(N) - N_th, N_th)
end

# Thomas–Fermi peak density of an N₀-atom condensate in a harmonic trap, and the
# per-atom three-body loss rate K₃⟨n²⟩ it produces (⟨n²⟩_TF = 4/7 n₀²).
function _condensate_three_body_rate(N0::Float64, ω̄::Float64, p::EvapParams, m::Float64)
    (N0 <= 0 || ω̄ <= 0 || p.K3 <= 0) && return 0.0
    aho = sqrt(Units.HBAR / (m * ω̄))
    μ = 0.5 * Units.HBAR * ω̄ * (15 * N0 * p.a_s / aho)^(2 / 5)   # TF chemical potential
    g = 4π * Units.HBAR^2 * p.a_s / m
    n0 = μ / g                                                   # TF peak density
    p.K3 * (4 / 7) * n0^2
end

"""Trajectory of a two-component evaporation run (thermal + condensate)."""
struct EvapBecResult
    t::Vector{Float64}
    N::Vector{Float64}       # total
    N0::Vector{Float64}      # condensate
    Nth::Vector{Float64}     # thermal
    T::Vector{Float64}
    eta::Vector{Float64}
    N0_final::Float64        # final condensate (the BEC atom number)
    T_final::Float64
    t_bec::Float64           # time the condensate first appears (NaN if none)
end

# Two-component RHS for (N_total, T): evaporation acts on the thermal cloud (saturated
# density below T_c), three-body loss on the dense condensate.
function _evap_rhs_bec(N::Float64, T::Float64, U::Float64, ω̄::Float64, p::EvapParams,
    m::Float64; dlnω_dt::Float64=0.0)
    (N <= 0 || T <= 0) && return (0.0, 0.0)   # RK4 may transiently overshoot to ≤ 0
    N0, Nth = condensate_split(N, T, ω̄)
    η = U / (Units.KB * T)
    # thermal-cloud density: saturated (ζ(3/2)/λ³) below T_c, peak-thermal above.
    n_th = if N0 > 0
        λ = Units.HBAR * sqrt(2π / (m * Units.KB * T))     # thermal de Broglie wavelength
        2.6123753486854883 / λ^3                           # ζ(3/2) = 2.612…
    else
        thermal_peak_density(N, T, ω̄, m)
    end
    # evaporation + heating: the SAME shared declaration the thermal-only evap_rhs uses, here
    # on the thermal fraction Nth at density n_th (above T_c, Nth=N ⇒ identical to evap_rhs).
    dN_th, dT = _thermal_evap_rates(Nth, T, η, n_th, p, m, dlnω_dt)
    dN_bg = -N / p.tau_bg                                   # 1-body acts on all atoms
    dN_3b = -_condensate_three_body_rate(N0, ω̄, p, m) * N0  # 3-body on the dense condensate
    (dN_th + dN_bg + dN_3b, dT)
end

"""
    run_evaporation_bec(trap, ramp, p; N0, T0, dt=ramp_duration/3000, save_every=10)
        -> EvapBecResult

Two-component evaporation: like [`run_evaporation`](@ref) but does NOT stop at the BEC
onset — it continues through the transition, tracking the condensate `N₀(t)` and the
thermal cloud `N_th(t)`. Below `T_c` evaporation acts on the (saturated) thermal cloud
while three-body loss depletes the dense condensate; the surviving `N₀_final` is the
BEC atom number. Above `T_c` it reduces to the thermal model (`N₀ = 0`).
"""
function run_evaporation_bec(
    trap::EvapTrap, ramp::FortRamp, p::EvapParams;
    N0::Float64, T0::Float64, dt::Float64=ramp_duration(ramp) / 3000, save_every::Int=10)
    m = trap.mass
    t0 = ramp.times[1]
    tend = ramp.times[end]
    nsteps = max(1, ceil(Int, (tend - t0) / dt))

    ts = Float64[]
    Ns = Float64[]
    N0s = Float64[]
    Nths = Float64[]
    Ts = Float64[]
    ηs = Float64[]

    N = N0
    T = T0
    t = t0
    t_bec = NaN

    # reuse the precomputed (U, ω̄) trap grid (piecewise-linear ramp ⇒ smooth, exact)
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
        c, th = condensate_split(N, T, ω̄)
        push!(ts, t)
        push!(Ns, N)
        push!(N0s, c)
        push!(Nths, th)
        push!(Ts, T)
        push!(ηs, U / (Units.KB * T))
    end

    # d(ln ω̄)/dt from the trap ramp (drives adiabatic compression/expansion heating)
    @inline function dlnω(tq::Float64)
        δ = dtg / 4
        _, ωp = trap_interp(min(tq + δ, tend))
        _, ωm = trap_interp(max(tq - δ, t0))
        (ωp > 0 && ωm > 0) ? (log(ωp) - log(ωm)) / (2δ) : 0.0
    end

    U, ω̄ = trap_interp(t)
    record!(U, ω̄)

    for s in 1:nsteps
        h = min(dt, tend - t)
        h <= 0 && break
        U1, ω1 = trap_interp(t)
        k1N, k1T = _evap_rhs_bec(N, T, U1, ω1, p, m; dlnω_dt=dlnω(t))
        Um, ωm = trap_interp(t + h / 2)
        dlm = dlnω(t + h / 2)
        k2N, k2T = _evap_rhs_bec(N + h / 2 * k1N, T + h / 2 * k1T, Um, ωm, p, m; dlnω_dt=dlm)
        k3N, k3T = _evap_rhs_bec(N + h / 2 * k2N, T + h / 2 * k2T, Um, ωm, p, m; dlnω_dt=dlm)
        U2, ω2 = trap_interp(t + h)
        k4N, k4T = _evap_rhs_bec(N + h * k3N, T + h * k3T, U2, ω2, p, m; dlnω_dt=dlnω(t + h))

        N = max(N + h / 6 * (k1N + 2k2N + 2k3N + k4N), 1.0)
        T = max(T + h / 6 * (k1T + 2k2T + 2k3T + k4T), 1e-12)
        t += h

        if isnan(t_bec)
            c, _ = condensate_split(N, T, ω2)
            c > 0 && (t_bec = t)
        end
        (s % save_every == 0 || s == nsteps) && record!(trap_interp(t)...)
    end

    EvapBecResult(ts, Ns, N0s, Nths, Ts, ηs,
        isempty(N0s) ? 0.0 : N0s[end], T, t_bec)
end
